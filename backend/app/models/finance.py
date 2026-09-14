import uuid
from sqlalchemy import Column, String, Boolean, Numeric, ForeignKey, DateTime, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from app.core.database import Base

class MST_Account(Base):
    __tablename__ = "mst_account"

    account = Column(String(10), primary_key=True, index=True)
    description = Column(String(255), nullable=False)
    type = Column(String(10), nullable=False) # 'Debit' or 'Credit'
    
    dimensi1 = Column(String(10), ForeignKey("mst_account.account"), nullable=True)
    dimensi2 = Column(String(10), ForeignKey("mst_account.account"), nullable=True)
    dimensi3 = Column(String(10), ForeignKey("mst_account.account"), nullable=True)
    dimensi4 = Column(String(10), ForeignKey("mst_account.account"), nullable=True)
    
    active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)


class Currency(Base):
    __tablename__ = "currencies"

    code = Column(String(3), primary_key=True, index=True)
    name = Column(String(50), nullable=False)
    symbol = Column(String(5), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)


class CurrencyRate(Base):
    __tablename__ = "currency_rates"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    from_currency = Column(String(3), ForeignKey("currencies.code"), nullable=False)
    to_currency = Column(String(3), ForeignKey("currencies.code"), nullable=False)
    rate = Column(Numeric(18, 6), nullable=False)
    valid_from = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    valid_to = Column(DateTime(timezone=True), nullable=True)


class PaymentMethod(Base):
    __tablename__ = "payment_methods"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code = Column(String(30), unique=True, index=True, nullable=False)
    name = Column(String(50), nullable=False)
    from_account = Column(String(10), ForeignKey("mst_account.account"), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True, nullable=False)
    type = Column(String(10), nullable=False) # 'EXPENSE' or 'INCOME'
    
    currency_code = Column(String(3), ForeignKey("currencies.code"), nullable=False)
    amount = Column(Numeric(15, 2), nullable=False)
    exchange_rate = Column(Numeric(18, 6), nullable=False)
    amount_in_base_currency = Column(Numeric(15, 2), nullable=False)
    
    payment_method_id = Column(UUID(as_uuid=True), ForeignKey("payment_methods.id"), nullable=False)
    notes = Column(Text, nullable=True)
    
    transaction_date = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False)
