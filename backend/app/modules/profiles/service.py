import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.profiles.models import Account, Profile
from app.modules.profiles.schemas import DevLoginRequest
from app.modules.progression.models import PlayerProgress


class UsernameUnavailableError(Exception):
    pass


async def direct_login(session: AsyncSession, request: DevLoginRequest) -> Profile:
    normalized_email = request.email.lower()
    existing_account = await session.scalar(
        select(Account).where(Account.email == normalized_email)
    )
    if existing_account is not None:
        profile = await session.get(Profile, existing_account.id)
        if profile is None:
            raise RuntimeError("Account exists without a profile")
        return profile

    account_id = uuid.uuid4()
    account = Account(id=account_id, email=normalized_email)
    profile = Profile(
        id=account_id,
        username=request.username.lower(),
        display_name=request.display_name,
    )
    session.add_all([account, profile, PlayerProgress(user_id=account_id)])
    try:
        await session.commit()
    except IntegrityError as exc:
        await session.rollback()
        raise UsernameUnavailableError from exc
    await session.refresh(profile)
    return profile
