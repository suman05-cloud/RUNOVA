import pytest
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine

from app.core.config import get_settings
from app.db.session import get_db_session
from app.main import app


@pytest.fixture(autouse=True)
def disable_rate_limits(monkeypatch):
    monkeypatch.setattr(get_settings(), "rate_limit_enabled", False)


@pytest.fixture
async def database():
    # Each integration test rolls back every write, including API commits.
    engine = create_async_engine(get_settings().database_url, connect_args={"timeout": 3})
    async with engine.connect() as connection:
        transaction = await connection.begin()

        async def session_override():
            async with AsyncSession(
                bind=connection,
                expire_on_commit=False,
                join_transaction_mode="create_savepoint",
            ) as session:
                yield session

        app.dependency_overrides[get_db_session] = session_override
        try:
            yield connection
        finally:
            app.dependency_overrides.pop(get_db_session, None)
            await transaction.rollback()
    await engine.dispose()
