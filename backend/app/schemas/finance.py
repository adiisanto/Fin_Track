from pydantic import BaseModel, Field, field_validator
from typing import List, Optional
from datetime import datetime, timezone, timedelta
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

from enum import Enum

class AccountTypeEnum(str, Enum):
    DEBIT = "Debit"
    CREDIT = "Credit"

class AccountCreate(BaseModel):
    account: str = Field(..., min_length=1, max_length=20, description="Kode Akun")
    description: str = Field(..., min_length=1, max_length=255, description="Deskripsi Akun")
    type: AccountTypeEnum
    dimensi1: Optional[str] = Field(None, max_length=20)
    dimensi2: Optional[str] = Field(None, max_length=20)
    dimensi3: Optional[str] = Field(None, max_length=20)
    dimensi4: Optional[str] = Field(None, max_length=20)
    active: bool = True

class AccountUpdate(BaseModel):
    account: Optional[str] = Field(None, min_length=1, max_length=20)
    description: Optional[str] = Field(None, min_length=1, max_length=255)
    type: Optional[AccountTypeEnum] = None
    dimensi1: Optional[str] = Field(None, max_length=20)
    dimensi2: Optional[str] = Field(None, max_length=20)
    dimensi3: Optional[str] = Field(None, max_length=20)
    dimensi4: Optional[str] = Field(None, max_length=20)
    active: Optional[bool] = None

class AccountResponse(BaseModel):
    id: UUID
    account: str
    description: str
    type: str
    dimensi1: Optional[str] = None
    dimensi2: Optional[str] = None
    dimensi3: Optional[str] = None
    dimensi4: Optional[str] = None
    active: bool
    created_at: datetime
    created_by: Optional[UUID] = None
    has_transactions: bool = False

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
    from_account: Optional[str] = Field(None, max_length=20)
    is_active: bool = True
    is_template: bool = False
    is_public: bool = False

class PaymentMethodUpdate(BaseModel):
    code: Optional[str] = Field(None, min_length=2, max_length=30)
    name: Optional[str] = Field(None, min_length=2, max_length=100)
    from_account: Optional[str] = Field(None, max_length=20)
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
    type: Optional[str] = Field(None, max_length=50)
    currency_code: str
    amount: Decimal = Field(..., gt=0)
    payment_method_id: UUID
    notes: Optional[str] = None
    transaction_date: Optional[datetime] = None

    @field_validator("transaction_date")
    @classmethod
    def validate_backdate_only(cls, v: Optional[datetime]) -> Optional[datetime]:
        if v is not None:
            now_utc = datetime.now(timezone.utc)
            target_dt = v if v.tzinfo is not None else v.replace(tzinfo=timezone.utc)
            if target_dt > (now_utc + timedelta(minutes=5)): # Small buffer
                raise ValueError("Tanggal transaksi tidak boleh di masa depan.")
        return v

class TransactionUpdate(BaseModel):
    type: Optional[str] = Field(None, max_length=50)
    currency_code: Optional[str] = Field(None, min_length=3, max_length=3)
    amount: Optional[Decimal] = Field(None, gt=0)
    payment_method_id: Optional[UUID] = None
    notes: Optional[str] = None
    transaction_date: Optional[datetime] = None

    @field_validator("transaction_date")
    @classmethod
    def validate_backdate_only(cls, v: Optional[datetime]) -> Optional[datetime]:
        if v is not None:
            now_utc = datetime.now(timezone.utc)
            target_dt = v if v.tzinfo is not None else v.replace(tzinfo=timezone.utc)
            if target_dt > (now_utc + timedelta(minutes=5)):
                raise ValueError("Tanggal transaksi tidak boleh di masa depan (hanya backdate yang diizinkan).")
        return v

class TransactionResponse(BaseModel):
    id: UUID
    type: Optional[str] = None
    currency_code: str
    amount: Decimal
    exchange_rate: Decimal
    amount_in_base_currency: Decimal
    payment_method: PaymentMethodResponse
    notes: Optional[str]
    processed: bool = False
    transaction_date: datetime
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True

class DeletedTransactionResponse(BaseModel):
    id: UUID
    original_transaction_id: UUID
    user_id: UUID
    type: Optional[str]
    currency_code: str
    amount: Decimal
    exchange_rate: Decimal
    amount_in_base_currency: Decimal
    payment_method_id: Optional[UUID]
    payment_method_name: Optional[str]
    notes: Optional[str]
    processed: bool = False
    transaction_date: datetime
    original_created_at: datetime
    original_updated_at: datetime
    deleted_at: datetime

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
