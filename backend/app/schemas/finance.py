from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from uuid import UUID
from decimal import Decimal

# Currency Schemas
class CurrencyCreate(BaseModel):
    code: str = Field(..., min_length=3, max_length=3)
    name: str = Field(..., min_length=2, max_length=50)
    symbol: str = Field(..., min_length=1, max_length=5)
    is_active: bool = True

class CurrencyResponse(BaseModel):
    code: str
    name: str
    symbol: str
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True

# Account Lookup Schema
class AccountLookupResponse(BaseModel):
    account: str
    description: str
    type: str
    active: bool

    class Config:
        from_attributes = True

# Payment Method Schemas
class PaymentMethodCreate(BaseModel):
    code: str = Field(..., min_length=2, max_length=30)
    name: str = Field(..., min_length=2, max_length=100)
    from_account: Optional[str] = Field(None, max_length=10)
    is_active: bool = True
    is_template: bool = False
    is_public: bool = False

class PaymentMethodUpdate(BaseModel):
    code: Optional[str] = Field(None, min_length=2, max_length=30)
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    from_account: Optional[str] = Field(None, max_length=10)
    is_active: Optional[bool] = None
    is_template: Optional[bool] = None
    is_public: Optional[bool] = None

class PaymentMethodResponse(BaseModel):
    id: UUID
    user_id: Optional[UUID] = None
    code: str
    name: str
    from_account: Optional[str] = None
    account_description: Optional[str] = None
    is_active: bool
    is_template: bool
    is_public: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

# Currency Rate Schemas
class CurrencyRateResponse(BaseModel):
    from_currency: str
    to_currency: str
    rate: Decimal
    updated_at: datetime

# Transaction Schemas
class TransactionCreate(BaseModel):
    type: str = Field(..., pattern="^(EXPENSE|INCOME)$")
    currency_code: str
    amount: Decimal = Field(..., gt=0)
    payment_method_id: UUID
    notes: Optional[str] = None
    transaction_date: Optional[datetime] = None

class TransactionResponse(BaseModel):
    id: UUID
    type: str
    currency_code: str
    amount: Decimal
    exchange_rate: Decimal
    amount_in_base_currency: Decimal
    payment_method: PaymentMethodResponse
    notes: Optional[str]
    transaction_date: datetime

    class Config:
        from_attributes = True

# Dashboard Summary Schemas
class DashboardSummaryResponse(BaseModel):
    base_currency: str
    timeframe: str
    period_start: datetime
    period_end: datetime
    total_income: Decimal
    total_expense: Decimal
    net_profit_loss: Decimal
    total_transactions: int
