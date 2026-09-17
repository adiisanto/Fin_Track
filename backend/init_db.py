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
        
        # 0. Seed Superadmin User
        from app.core.security import get_password_hash
        admin_user = User(
            email="admin@fintrack.com",
            password_hash=get_password_hash("admin123"),
            full_name="Super Admin",
            base_currency="IDR",
            is_superuser=True
        )
        session.add(admin_user)
        
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

        # 3. Seed MST_Account (Default COA Templates for all users)
        accounts = [
            MST_Account(account="1000", description="ASET LANCAR", type="Debit"),
            MST_Account(account="1100", description="Kas & Bank", type="Debit", dimensi1="1000"),
            MST_Account(account="1001", description="Kas Utama", type="Debit", dimensi1="1000", dimensi2="1100"),
            MST_Account(account="1002", description="Bank Operasional", type="Debit", dimensi1="1000", dimensi2="1100"),
            MST_Account(account="1003", description="Saldo E-Wallet", type="Debit", dimensi1="1000", dimensi2="1100"),
            MST_Account(account="2000", description="KEWAJIBAN", type="Credit"),
            MST_Account(account="2100", description="Hutang Jangka Pendek", type="Credit", dimensi1="2000"),
            MST_Account(account="2001", description="Hutang Kartu Kredit", type="Credit", dimensi1="2000", dimensi2="2100"),
            MST_Account(account="3000", description="EKUITAS / MODAL", type="Credit"),
            MST_Account(account="4000", description="PENDAPATAN", type="Credit"),
            MST_Account(account="4101", description="Pendapatan Gaji", type="Credit", dimensi1="4000"),
            MST_Account(account="5000", description="BEBAN OPERASIONAL", type="Debit"),
            MST_Account(account="5101", description="Beban Makan & Minum", type="Debit", dimensi1="5000"),
        ]
        session.add_all(accounts)
        
        # Flush to get primary keys for next steps (accounts)
        await session.flush()

        # 4. Seed Payment Methods (Sebagai Template Sistem Default)
        methods = [
            PaymentMethod(code="CASH", name="Tunai", from_account="1001", user_id=None, is_template=True, is_public=True),
            PaymentMethod(code="BANK_TRANSFER", name="Transfer Bank", from_account="1002", user_id=None, is_template=True, is_public=True),
            PaymentMethod(code="E_WALLET", name="E-Wallet", from_account="1003", user_id=None, is_template=True, is_public=True),
            PaymentMethod(code="CREDIT_CARD", name="Kartu Kredit", from_account="2001", user_id=None, is_template=True, is_public=True),
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
