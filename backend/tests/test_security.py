import uuid

from app.core.security import create_dev_access_token, decode_dev_access_token


def test_dev_token_round_trip() -> None:
    user_id = uuid.uuid4()

    token, expires_at = create_dev_access_token(user_id)

    assert decode_dev_access_token(token) == user_id
    assert expires_at.tzinfo is not None

