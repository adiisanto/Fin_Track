import asyncio
from app.core.database import engine, Base
# Import all models here so they are registered with Base
from app.models.user import User

async def init_db():
    async with engine.begin() as conn:
        print("Creating all tables...")
        await conn.run_sync(Base.metadata.create_all)
        print("Tables created successfully!")

if __name__ == "__main__":
    asyncio.run(init_db())
