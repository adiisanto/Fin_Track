from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_, delete
from typing import List, Any, Optional
from datetime import datetime, timezone, timedelta
import calendar

from app.api.deps import get_current_user, get_current_superadmin, get_db
from app.models.user import User
from app.models.finance import MST_Account, Currency, CurrencyRate, PaymentMethod, Transaction
from app.schemas.finance import (
    CurrencyCreate,
    CurrencyResponse,
    PaymentMethodCreate,
    PaymentMethodUpdate,
    PaymentMethodResponse,
    AccountLookupResponse,
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
async def get_currencies(
    include_inactive: bool = False,
    db: AsyncSession = Depends(get_db)
):
    query = select(Currency)
    if not include_inactive:
        query = query.where(Currency.is_active == True)
        
    result = await db.execute(query)
    currencies = result.scalars().all()
    return {
        "success": True,
        "data": [CurrencyResponse.model_validate(c).model_dump() for c in currencies]
    }

@router.post("/admin/currencies", response_model=dict, status_code=201)
async def create_currency(
    currency_in: CurrencyCreate,
    current_admin: User = Depends(get_current_superadmin),
    db: AsyncSession = Depends(get_db)
):
    code_upper = currency_in.code.upper()
    
    # Cek duplikat
    result = await db.execute(select(Currency).where(Currency.code == code_upper))
    if result.scalars().first():
        raise HTTPException(status_code=409, detail=f"Kode mata uang {code_upper} sudah terdaftar.")
        
    new_currency = Currency(
        code=code_upper,
        name=currency_in.name,
        symbol=currency_in.symbol,
        is_active=currency_in.is_active,
        created_at=datetime.now(timezone.utc)
    )
    
    db.add(new_currency)
    await db.commit()
    await db.refresh(new_currency)
    
    return {
        "success": True,
        "message": f"Mata uang {code_upper} berhasil ditambahkan.",
        "data": CurrencyResponse.model_validate(new_currency).model_dump()
    }

@router.delete("/admin/currencies/{code}", response_model=dict)
async def delete_currency(
    code: str,
    current_admin: User = Depends(get_current_superadmin),
    db: AsyncSession = Depends(get_db)
):
    code_upper = code.upper()
    
    result = await db.execute(select(Currency).where(Currency.code == code_upper))
    currency = result.scalars().first()
    if not currency:
        raise HTTPException(status_code=404, detail="Mata uang tidak ditemukan.")
        
    # Validasi keterikatan transaksi
    trx_result = await db.execute(select(Transaction).where(Transaction.currency_code == code_upper).limit(1))
    if trx_result.scalars().first():
        raise HTTPException(
            status_code=400,
            detail=f"Mata uang {code_upper} tidak dapat dihapus karena sudah digunakan pada data transaksi."
        )
        
    # Pembersihan Data Kurs (currency_rates)
    from sqlalchemy import delete
    await db.execute(delete(CurrencyRate).where(CurrencyRate.from_currency == code_upper))
    
    # Hapus currency
    await db.delete(currency)
    await db.commit()
    
    return {
        "success": True,
        "message": f"Mata uang {code_upper} beserta data kurs terkait berhasil dihapus."
    }

@router.get("/payment-methods", response_model=dict)
async def get_payment_methods(
    include_inactive: bool = Query(False),
    is_template: bool = Query(False),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    query = select(PaymentMethod, MST_Account).outerjoin(
        MST_Account, and_(PaymentMethod.from_account == MST_Account.account, MST_Account.created_by == current_user.id)
    ).where(
        PaymentMethod.user_id == current_user.id,
        PaymentMethod.is_template == is_template
    )
    if not include_inactive:
        query = query.where(PaymentMethod.is_active == True)
    
    result = await db.execute(query)
    
    data = []
    for pm, acc in result.all():
        pm_resp = PaymentMethodResponse.model_validate(pm)
        if acc:
            pm_resp.account_description = acc.description
        data.append(pm_resp.model_dump())

    return {"success": True, "data": data}

@router.post("/payment-methods", response_model=dict, status_code=201)
async def create_payment_method(
    body: PaymentMethodCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    code_upper = body.code.strip().upper()
    
    # Check duplicate
    existing = await db.execute(select(PaymentMethod).where(
        PaymentMethod.user_id == current_user.id,
        PaymentMethod.code == code_upper,
        PaymentMethod.is_template == body.is_template
    ))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Kode metode pembayaran sudah digunakan.")

    # Check from_account validity
    if body.from_account:
        acc = await db.execute(select(MST_Account).where(MST_Account.account == body.from_account, MST_Account.created_by == current_user.id))
        if not acc.scalar_one_or_none():
            raise HTTPException(status_code=400, detail="Akun GL tidak valid.")

    new_pm = PaymentMethod(
        user_id=current_user.id,
        code=code_upper,
        name=body.name,
        from_account=body.from_account,
        is_active=body.is_active,
        is_template=body.is_template,
        is_public=body.is_public,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )
    db.add(new_pm)
    await db.commit()
    await db.refresh(new_pm)

    pm_resp = PaymentMethodResponse.model_validate(new_pm)
    if body.from_account:
        acc = await db.execute(select(MST_Account).where(MST_Account.account == body.from_account, MST_Account.created_by == current_user.id))
        acc_obj = acc.scalar_one()
        pm_resp.account_description = acc_obj.description

    return {"success": True, "data": pm_resp.model_dump()}

@router.put("/payment-methods/{id}", response_model=dict)
async def update_payment_method(
    id: str,
    body: PaymentMethodUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(PaymentMethod).where(
        PaymentMethod.id == id,
        PaymentMethod.user_id == current_user.id
    ))
    pm = result.scalar_one_or_none()
    if not pm:
        raise HTTPException(status_code=404, detail="Metode pembayaran tidak ditemukan atau Anda tidak memiliki hak akses.")
    
    if body.code is not None:
        code_upper = body.code.strip().upper()
        # check duplicate
        if code_upper != pm.code:
            existing = await db.execute(select(PaymentMethod).where(
                PaymentMethod.user_id == current_user.id,
                PaymentMethod.code == code_upper,
                PaymentMethod.is_template == (body.is_template if body.is_template is not None else pm.is_template)
            ))
            if existing.scalar_one_or_none():
                raise HTTPException(status_code=409, detail="Kode metode pembayaran sudah digunakan.")
        pm.code = code_upper

    if body.name is not None:
        pm.name = body.name

    if body.from_account is not None:
        # allow empty account
        if body.from_account == "":
            pm.from_account = None
        else:
            acc = await db.execute(select(MST_Account).where(MST_Account.account == body.from_account, MST_Account.created_by == current_user.id))
            if not acc.scalar_one_or_none():
                raise HTTPException(status_code=400, detail="Akun GL tidak valid.")
            pm.from_account = body.from_account

    if body.is_active is not None:
        pm.is_active = body.is_active
    if body.is_template is not None:
        pm.is_template = body.is_template
    if body.is_public is not None:
        pm.is_public = body.is_public

    pm.updated_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(pm)

    pm_resp = PaymentMethodResponse.model_validate(pm)
    if pm.from_account:
        acc = await db.execute(select(MST_Account).where(MST_Account.account == pm.from_account))
        acc_obj = acc.scalar_one()
        pm_resp.account_description = acc_obj.description

    return {"success": True, "data": pm_resp.model_dump()}

@router.delete("/payment-methods/{id}", response_model=dict)
async def delete_payment_method(
    id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(PaymentMethod).where(
        PaymentMethod.id == id,
        PaymentMethod.user_id == current_user.id
    ))
    pm = result.scalar_one_or_none()
    if not pm:
        raise HTTPException(status_code=404, detail="Metode pembayaran tidak ditemukan atau Anda tidak memiliki hak akses.")

    # Soft delete
    pm.is_active = False
    pm.updated_at = datetime.now(timezone.utc)
    await db.commit()

    return {"success": True, "message": "Metode pembayaran berhasil dinonaktifkan (soft deleted)."}

@router.get("/payment-methods/templates/public", response_model=dict)
async def get_public_templates(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    query = select(PaymentMethod, MST_Account).outerjoin(
        MST_Account, and_(PaymentMethod.from_account == MST_Account.account, MST_Account.created_by == current_user.id)
    ).where(
        PaymentMethod.is_template == True,
        PaymentMethod.is_public == True
    )
    result = await db.execute(query)
    
    data = []
    for pm, acc in result.all():
        pm_resp = PaymentMethodResponse.model_validate(pm)
        if acc:
            pm_resp.account_description = acc.description
        data.append(pm_resp.model_dump())

    return {"success": True, "data": data}

@router.get("/payment-methods/templates/{template_id}/preview", response_model=dict)
async def preview_template(
    template_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Cari template
    result = await db.execute(
        select(PaymentMethod, MST_Account).outerjoin(
            MST_Account, PaymentMethod.from_account == MST_Account.account
        ).where(
            PaymentMethod.id == template_id,
            PaymentMethod.is_template == True,
            or_(PaymentMethod.is_public == True, PaymentMethod.user_id == current_user.id)
        )
    )
    row = result.first()
    if not row:
        raise HTTPException(status_code=404, detail="Template tidak ditemukan atau bersifat privat.")
    
    pm, acc = row
    pm_resp = PaymentMethodResponse.model_validate(pm)
    if acc:
        pm_resp.account_description = acc.description

    # Cek konflik kode
    existing = await db.execute(select(PaymentMethod).where(
        PaymentMethod.user_id == current_user.id,
        PaymentMethod.code == pm.code,
        PaymentMethod.is_template == False
    ))
    is_conflict = existing.scalar_one_or_none() is not None

    data = pm_resp.model_dump()
    data["is_code_conflict"] = is_conflict
    if is_conflict:
        data["conflict_message"] = f"Kode '{pm.code}' sudah terdaftar pada metode pembayaran Anda. Menyalin template ini akan memberi akhiran _COPY pada kode."

    return {"success": True, "data": data}

@router.post("/payment-methods/templates/{template_id}/copy", response_model=dict, status_code=201)
async def copy_template(
    template_id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Validasi template
    result = await db.execute(select(PaymentMethod).where(
        PaymentMethod.id == template_id,
        PaymentMethod.is_template == True,
        or_(PaymentMethod.is_public == True, PaymentMethod.user_id == current_user.id)
    ))
    template = result.scalar_one_or_none()
    if not template:
        raise HTTPException(status_code=404, detail="Template tidak ditemukan atau bersifat privat.")

    # Cek konflik kode
    new_code = template.code
    existing = await db.execute(select(PaymentMethod).where(
        PaymentMethod.user_id == current_user.id,
        PaymentMethod.code == new_code,
        PaymentMethod.is_template == False
    ))
    if existing.scalar_one_or_none():
        new_code = f"{new_code}_COPY"
        # Optional: check if _COPY also exists and handle, but keeping it simple as per spec
    
    new_pm = PaymentMethod(
        user_id=current_user.id,
        code=new_code,
        name=template.name,
        from_account=template.from_account,
        is_active=True,
        is_template=False,
        is_public=False,
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc)
    )
    db.add(new_pm)
    await db.commit()
    await db.refresh(new_pm)

    pm_resp = PaymentMethodResponse.model_validate(new_pm)
    if template.from_account:
        acc = await db.execute(select(MST_Account).where(MST_Account.account == template.from_account))
        if acc_obj := acc.scalar_one_or_none():
            pm_resp.account_description = acc_obj.description

    return {"success": True, "data": pm_resp.model_dump()}

@router.get("/accounts/lookup", response_model=dict)
async def lookup_accounts(
    q: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    query = select(MST_Account).where(MST_Account.active == True)
    if q:
        query = query.where(or_(
            MST_Account.account.ilike(f"%{q}%"),
            MST_Account.description.ilike(f"%{q}%")
        ))
    
    result = await db.execute(query)
    data = []
    for acc in result.scalars().all():
        data.append(AccountLookupResponse.model_validate(acc).model_dump())

    return {"success": True, "data": data}

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
    pm_query = select(PaymentMethod, MST_Account).join(MST_Account, and_(PaymentMethod.from_account == MST_Account.account, MST_Account.created_by == current_user.id)).where(PaymentMethod.id == trans_in.payment_method_id)
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


from app.schemas.finance import AccountCreate, AccountUpdate, AccountResponse, AccountTypeEnum

@router.get("/coa", response_model=dict)
async def get_coa(
    include_inactive: bool = Query(False),
    search: Optional[str] = Query(None),
    type: Optional[str] = Query(None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    query = select(MST_Account).where(MST_Account.created_by == current_user.id)
    if not include_inactive:
        query = query.where(MST_Account.active == True)
    if type:
        query = query.where(MST_Account.type == type)
    if search:
        query = query.where(or_(
            MST_Account.account.ilike(f"%{search}%"),
            MST_Account.description.ilike(f"%{search}%")
        ))
    
    result = await db.execute(query.order_by(MST_Account.account))
    accounts = result.scalars().all()
    
    # check transactions
    pm_query = select(PaymentMethod.from_account).join(Transaction, PaymentMethod.id == Transaction.payment_method_id).where(PaymentMethod.user_id == current_user.id)
    pm_res = await db.execute(pm_query)
    used_accounts = set(pm_res.scalars().all())

    data = []
    for acc in accounts:
        acc_dict = AccountResponse.model_validate(acc).model_dump()
        acc_dict["has_transactions"] = acc.account in used_accounts
        data.append(acc_dict)

    return {"success": True, "data": data}

@router.post("/coa", response_model=dict, status_code=201)
async def create_coa(
    body: AccountCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Check duplicate
    existing = await db.execute(select(MST_Account).where(
        MST_Account.created_by == current_user.id,
        MST_Account.account == body.account
    ))
    if existing.scalar_one_or_none():
        raise HTTPException(status_code=409, detail="Kode akun sudah terdaftar.")

    new_acc = MST_Account(
        account=body.account,
        description=body.description,
        type=body.type.value,
        dimensi1=body.dimensi1,
        dimensi2=body.dimensi2,
        dimensi3=body.dimensi3,
        dimensi4=body.dimensi4,
        active=body.active,
        created_by=current_user.id,
        created_at=datetime.now(timezone.utc)
    )
    db.add(new_acc)
    await db.commit()
    await db.refresh(new_acc)

    return {"success": True, "data": AccountResponse.model_validate(new_acc).model_dump()}

@router.put("/coa/{id}", response_model=dict)
async def update_coa(
    id: str,
    body: AccountUpdate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(MST_Account).where(
        MST_Account.id == id,
        MST_Account.created_by == current_user.id
    ))
    acc = result.scalar_one_or_none()
    if not acc:
        raise HTTPException(status_code=404, detail="Akun tidak ditemukan.")

    pm_query = select(PaymentMethod.from_account).join(Transaction, PaymentMethod.id == Transaction.payment_method_id).where(PaymentMethod.user_id == current_user.id, PaymentMethod.from_account == acc.account).limit(1)
    has_transactions = (await db.execute(pm_query)).scalar_one_or_none() is not None

    if has_transactions:
        if (body.account is not None and body.account != acc.account) or (body.type is not None and body.type.value != acc.type):
            raise HTTPException(status_code=400, detail="Kode akun dan tipe akun tidak dapat diubah karena akun ini sudah memiliki riwayat transaksi.")
    elif body.account is not None and body.account != acc.account:
        existing = await db.execute(select(MST_Account).where(
            MST_Account.created_by == current_user.id,
            MST_Account.account == body.account
        ))
        if existing.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Kode akun sudah terdaftar.")

    if body.account is not None:
        acc.account = body.account
    if body.description is not None:
        acc.description = body.description
    if body.type is not None:
        acc.type = body.type.value
    if body.dimensi1 is not None:
        acc.dimensi1 = body.dimensi1 if body.dimensi1 != "" else None
    if body.dimensi2 is not None:
        acc.dimensi2 = body.dimensi2 if body.dimensi2 != "" else None
    if body.dimensi3 is not None:
        acc.dimensi3 = body.dimensi3 if body.dimensi3 != "" else None
    if body.dimensi4 is not None:
        acc.dimensi4 = body.dimensi4 if body.dimensi4 != "" else None
    if body.active is not None:
        acc.active = body.active

    await db.commit()
    await db.refresh(acc)
    
    acc_dict = AccountResponse.model_validate(acc).model_dump()
    acc_dict["has_transactions"] = has_transactions
    return {"success": True, "data": acc_dict}

@router.delete("/coa/{id}", response_model=dict)
async def delete_coa(
    id: str,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(MST_Account).where(
        MST_Account.id == id,
        MST_Account.created_by == current_user.id
    ))
    acc = result.scalar_one_or_none()
    if not acc:
        raise HTTPException(status_code=404, detail="Akun tidak ditemukan.")

    pm_query = select(PaymentMethod.from_account).join(Transaction, PaymentMethod.id == Transaction.payment_method_id).where(PaymentMethod.user_id == current_user.id, PaymentMethod.from_account == acc.account).limit(1)
    if (await db.execute(pm_query)).scalar_one_or_none() is not None:
        raise HTTPException(status_code=400, detail="Akun tidak dapat dinonaktifkan atau dihapus karena sudah terdapat transaksi yang menggunakan akun ini. Hapus data transaksi terkait terlebih dahulu.")

    acc.active = False
    await db.commit()
    return {"success": True, "message": "Akun berhasil dinonaktifkan (soft deleted)."}

@router.get("/coa/lookup", response_model=dict)
async def lookup_coa(
    q: Optional[str] = None,
    exclude_account: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    query = select(MST_Account).where(
        MST_Account.created_by == current_user.id,
        MST_Account.active == True
    )
    if exclude_account:
        query = query.where(MST_Account.account != exclude_account)
    
    if q:
        query = query.where(or_(
            MST_Account.account.ilike(f"%{q}%"),
            MST_Account.description.ilike(f"%{q}%")
        ))
    
    result = await db.execute(query.order_by(MST_Account.account))
    data = [AccountLookupResponse.model_validate(acc).model_dump() for acc in result.scalars().all()]

    return {"success": True, "data": data}
