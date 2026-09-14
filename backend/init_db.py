import asyncio
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import engine, Base
from app.models.user import User
from app.models.finance import MST_Account, Currency, CurrencyRate, PaymentMethod, Transaction

async def seed_data():
    # Import inside to use the connection
    from sqlalchemy.orm import sessionmaker
    
    async_session = sessionmaker(
        engine, class_=AsyncSession, expire_on_commit=False
    )
    
    async with async_session() as session:
        # Check if currencies exist
        result = await session.execute(select(Currency).limit(1))
        if result.scalar_one_or_none() is not None:
            print("Seed data already exists. Skipping.")
            return

        print("Inserting seed data...")
        
        # 1. Seed Currencies
        currencies = [
            Currency(code="IDR", name="Indonesian Rupiah", symbol="Rp"),
            Currency(code="USD", name="US Dollar", symbol="$"),
            Currency(code="EUR", name="Euro", symbol="€"),
            Currency(code="SGD", name="Singapore Dollar", symbol="S$"),
        ]
        session.add_all(currencies)
        
        # 2. Seed Currency Rates (vs IDR for this example)
        rates = [
            CurrencyRate(from_currency="USD", to_currency="IDR", rate=15800.00),
            CurrencyRate(from_currency="EUR", to_currency="IDR", rate=17000.00),
            CurrencyRate(from_currency="SGD", to_currency="IDR", rate=11800.00),
            CurrencyRate(from_currency="IDR", to_currency="IDR", rate=1.00),
        ]
        session.add_all(rates)

        # 3. Seed MST_Account
        accounts = [
            MST_Account(account="1001", description="Kas Utama", type="Debit"),
            MST_Account(account="1002", description="Bank Operasional", type="Debit"),
            MST_Account(account="1003", description="Saldo E-Wallet", type="Debit"),
            MST_Account(account="2001", description="Hutang Kartu Kredit", type="Credit"),
        ]
        session.add_all(accounts)
        
        # Flush to get primary keys for next steps (accounts)
        await session.flush()

        # 4. Seed Payment Methods
        methods = [
            PaymentMethod(code="CASH", name="Tunai", from_account="1001"),
            PaymentMethod(code="BANK_TRANSFER", name="Transfer Bank", from_account="1002"),
            PaymentMethod(code="E_WALLET", name="E-Wallet", from_account="1003"),
            PaymentMethod(code="CREDIT_CARD", name="Kartu Kredit", from_account="2001"),
        ]
        session.add_all(methods)

        await session.commit()
        print("Seed data inserted successfully!")

async def init_db():
    async with engine.begin() as conn:
        print("Creating all tables...")
        await conn.run_sync(Base.metadata.create_all)
        print("Tables created successfully!")
        
    # Seed data uses its own session and connection
    await seed_data()

if __name__ == "__main__":
    asyncio.run(init_db())
