from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from typing import List, Any
from datetime import datetime, timezone, timedelta
import calendar

from app.api.deps import get_current_user, get_db
from app.models.user import User
from app.models.finance import MST_Account, Currency, CurrencyRate, PaymentMethod, Transaction
from app.schemas.finance import (
    CurrencyResponse,
    PaymentMethodResponse,
    CurrencyRateResponse,
    TransactionCreate,
    TransactionResponse,
    DashboardSummaryResponse
)

router = APIRouter()

@router.get("/dashboard/summary", response_model=dict)
async def get_dashboard_summary(
    timeframe: str = Query("monthly", regex="^(lifetime|monthly|weekly|daily)$"),
    reference_date: datetime = Query(default_factory=lambda: datetime.now(timezone.utc)),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    start_date = None
    end_date = None

    if timeframe == "monthly":
        start_date = datetime(reference_date.year, reference_date.month, 1, tzinfo=timezone.utc)
        last_day = calendar.monthrange(reference_date.year, reference_date.month)[1]
        end_date = datetime(reference_date.year, reference_date.month, last_day, 23, 59, 59, tzinfo=timezone.utc)
    elif timeframe == "weekly":
        start_date = reference_date - timedelta(days=reference_date.weekday())
        start_date = datetime(start_date.year, start_date.month, start_date.day, tzinfo=timezone.utc)
        end_date = start_date + timedelta(days=6, hours=23, minutes=59, seconds=59)
    elif timeframe == "daily":
        start_date = datetime(reference_date.year, reference_date.month, reference_date.day, tzinfo=timezone.utc)
        end_date = start_date + timedelta(hours=23, minutes=59, seconds=59)
    # lifetime leaves start_date and end_date as None

    query = select(Transaction).where(Transaction.user_id == current_user.id)
    if timeframe != "lifetime":
        query = query.where(and_(Transaction.transaction_date >= start_date, Transaction.transaction_date <= end_date))

    result = await db.execute(query)
    transactions = result.scalars().all()

    total_income = sum(t.amount_in_base_currency for t in transactions if t.type == "INCOME")
    total_expense = sum(t.amount_in_base_currency for t in transactions if t.type == "EXPENSE")

    return {
        "success": True,
        "data": DashboardSummaryResponse(
            base_currency=current_user.base_currency,
            timeframe=timeframe,
            period_start=start_date or datetime.min.replace(tzinfo=timezone.utc),
            period_end=end_date or datetime.max.replace(tzinfo=timezone.utc),
            total_income=total_income,
            total_expense=total_expense,
            net_profit_loss=total_income - total_expense,
            total_transactions=len(transactions)
        ).model_dump()
    }

@router.get("/currencies", response_model=dict)
async def get_currencies(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Currency).where(Currency.is_active == True))
    currencies = result.scalars().all()
    return {
        "success": True,
        "data": [CurrencyResponse.model_validate(c).model_dump() for c in currencies]
    }

@router.get("/payment-methods", response_model=dict)
async def get_payment_methods(db: AsyncSession = Depends(get_db)):
    # Join with MST_Account to get account description
    query = select(PaymentMethod, MST_Account).join(MST_Account, PaymentMethod.from_account == MST_Account.account).where(PaymentMethod.is_active == True)
    result = await db.execute(query)
    
    data = []
    for pm, acc in result.all():
        pm_resp = PaymentMethodResponse.model_validate(pm)
        pm_resp.account_description = acc.description
        data.append(pm_resp.model_dump())

    return {
        "success": True,
        "data": data
    }

@router.get("/currency-rates/latest", response_model=dict)
async def get_latest_currency_rate(
    from_currency: str = Query(...),
    to_currency: str = Query(...),
    db: AsyncSession = Depends(get_db)
):
    if from_currency == to_currency:
        return {
            "success": True,
            "data": {
                "from_currency": from_currency,
                "to_currency": to_currency,
                "rate": 1.0,
                "updated_at": datetime.now(timezone.utc)
            }
        }
        
    query = select(CurrencyRate).where(
        and_(
            CurrencyRate.from_currency == from_currency,
            CurrencyRate.to_currency == to_currency,
            CurrencyRate.valid_to.is_(None)
        )
    ).order_by(CurrencyRate.valid_from.desc()).limit(1)
    
    result = await db.execute(query)
    rate = result.scalar_one_or_none()
    
    if not rate:
        raise HTTPException(status_code=404, detail="Currency rate not found")
        
    return {
        "success": True,
        "data": {
            "from_currency": rate.from_currency,
            "to_currency": rate.to_currency,
            "rate": rate.rate,
            "updated_at": rate.valid_from
        }
    }

@router.post("/transactions", response_model=dict, status_code=201)
async def create_transaction(
    trans_in: TransactionCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # 1. Validate Currency
    curr_result = await db.execute(select(Currency).where(Currency.code == trans_in.currency_code))
    if not curr_result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Invalid currency_code")

    # 2. Validate Payment Method and get it for response
    pm_query = select(PaymentMethod, MST_Account).join(MST_Account, PaymentMethod.from_account == MST_Account.account).where(PaymentMethod.id == trans_in.payment_method_id)
    pm_result = await db.execute(pm_query)
    pm_row = pm_result.first()
    if not pm_row:
        raise HTTPException(status_code=400, detail="Invalid payment_method_id")
    pm, acc = pm_row

    # 3. Get exchange rate
    exchange_rate = 1.0
    if trans_in.currency_code != current_user.base_currency:
        rate_query = select(CurrencyRate).where(
            and_(
                CurrencyRate.from_currency == trans_in.currency_code,
                CurrencyRate.to_currency == current_user.base_currency,
                CurrencyRate.valid_to.is_(None)
            )
        ).order_by(CurrencyRate.valid_from.desc()).limit(1)
        rate_result = await db.execute(rate_query)
        rate_obj = rate_result.scalar_one_or_none()
        if not rate_obj:
            raise HTTPException(status_code=400, detail=f"No active exchange rate found from {trans_in.currency_code} to {current_user.base_currency}")
        exchange_rate = rate_obj.rate

    amount_in_base = trans_in.amount * exchange_rate

    transaction = Transaction(
        user_id=current_user.id,
        type=trans_in.type,
        currency_code=trans_in.currency_code,
        amount=trans_in.amount,
        exchange_rate=exchange_rate,
        amount_in_base_currency=amount_in_base,
        payment_method_id=trans_in.payment_method_id,
        notes=trans_in.notes,
        transaction_date=trans_in.transaction_date or datetime.now(timezone.utc)
    )
    
    db.add(transaction)
    await db.commit()
    await db.refresh(transaction)

    # Build response manually to include nested payment method
    pm_resp = PaymentMethodResponse.model_validate(pm)
    pm_resp.account_description = acc.description

    return {
        "success": True,
        "message": "Transaksi pengeluaran berhasil disimpan.",
        "data": {
            "id": str(transaction.id),
            "type": transaction.type,
            "currency_code": transaction.currency_code,
            "amount": float(transaction.amount),
            "exchange_rate": float(transaction.exchange_rate),
            "amount_in_base_currency": float(transaction.amount_in_base_currency),
            "payment_method": pm_resp.model_dump(),
            "notes": transaction.notes,
            "transaction_date": transaction.transaction_date.isoformat()
        }
    }
