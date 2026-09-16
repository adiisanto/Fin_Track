import asyncio
from app.core.database import engine, Base
import app.models.finance
import app.models.user

async def reset_db():
    async with engine.begin() as conn:
        print("Dropping all tables...")
        await conn.run_sync(Base.metadata.drop_all)
        print("All tables dropped.")

if __name__ == "__main__":
    asyncio.run(reset_db())
