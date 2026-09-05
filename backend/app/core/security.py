import uuid
from datetime import UTC, datetime, timedelta
from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.core.config import get_settings

DEV_ISSUER = "runova-dev"
MOBILE_AUDIENCE = "runova-mobile"
bearer_scheme = HTTPBearer(auto_error=True)
BearerCredentials = Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)]


def create_dev_access_token(user_id: uuid.UUID) -> tuple[str, datetime]:
    settings = get_settings()
    now = datetime.now(UTC)
    expires_at = now + timedelta(minutes=settings.dev_token_minutes)
    payload = {
        "sub": str(user_id),
        "iat": now,
        "exp": expires_at,
        "iss": DEV_ISSUER,
        "aud": MOBILE_AUDIENCE,
    }
    token = jwt.encode(payload, settings.dev_jwt_secret, algorithm="HS256")
    return token, expires_at


def decode_dev_access_token(token: str) -> uuid.UUID:
    settings = get_settings()
    try:
        payload = jwt.decode(
            token,
            settings.dev_jwt_secret,
            algorithms=["HS256"],
            issuer=DEV_ISSUER,
            audience=MOBILE_AUDIENCE,
        )
        return uuid.UUID(payload["sub"])
    except (jwt.PyJWTError, KeyError, TypeError, ValueError) as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired access token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from exc


def get_current_user_id(credentials: BearerCredentials) -> uuid.UUID:
    return decode_dev_access_token(credentials.credentials)


CurrentUserId = Annotated[uuid.UUID, Depends(get_current_user_id)]

