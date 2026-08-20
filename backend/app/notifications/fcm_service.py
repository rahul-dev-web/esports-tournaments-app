"""Firebase Cloud Messaging delivery helpers."""

from __future__ import annotations

import logging
from typing import Iterable

from app.common.config import settings

logger = logging.getLogger(__name__)

_initialized = False
_messaging = None


def _get_messaging():
    """Initialize Firebase Admin once and return the messaging module.

    Firebase is optional for local development, but when credentials are
    configured we fail loudly in the server logs instead of silently treating
    a configuration problem as a successful push delivery.
    """
    global _initialized, _messaging

    if _initialized:
        return _messaging

    try:
        import firebase_admin
        from firebase_admin import credentials, messaging
    except ImportError:
        logger.error("FCM unavailable: firebase-admin is not installed")
        _initialized = True
        return None

    missing = [
        name
        for name, value in (
            ("FIREBASE_PROJECT_ID", settings.FIREBASE_PROJECT_ID),
            ("FIREBASE_CLIENT_EMAIL", settings.FIREBASE_CLIENT_EMAIL),
            ("FIREBASE_PRIVATE_KEY", settings.FIREBASE_PRIVATE_KEY),
        )
        if not value or not str(value).strip()
    ]
    if missing:
        logger.warning(
            "FCM disabled: missing Render environment variables: %s",
            ", ".join(missing),
        )
        _initialized = True
        return None

    try:
        private_key = settings.FIREBASE_PRIVATE_KEY.replace("\\n", "\n").strip()
        credential = credentials.Certificate(
            {
                "type": "service_account",
                "project_id": settings.FIREBASE_PROJECT_ID.strip(),
                "client_email": settings.FIREBASE_CLIENT_EMAIL.strip(),
                "private_key": private_key,
                "token_uri": "https://oauth2.googleapis.com/token",
            }
        )

        try:
            app = firebase_admin.get_app()
        except ValueError:
            app = firebase_admin.initialize_app(credential)

        # Keep the app/project identity visible in Render logs without ever
        # printing the private key or other credentials.
        logger.info(
            "FCM initialized successfully: project_id=%s app=%s",
            settings.FIREBASE_PROJECT_ID.strip(),
            app.name,
        )
        _messaging = messaging
        _initialized = True
        return _messaging
    except Exception:
        logger.exception("FCM initialization failed; push delivery is disabled")
        _initialized = True
        return None


def send_push(
    tokens: Iterable[str],
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> set[str]:
    """Deliver push notifications and return permanently invalid tokens.

    Firebase Admin SDK 7.x uses ``send_each`` for batch delivery. We batch at
    500 messages, isolate individual token failures, and never raise a push
    delivery exception into the API/domain transaction.
    """
    messaging = _get_messaging()
    if messaging is None:
        return set()

    normalized_tokens = list(dict.fromkeys(token.strip() for token in tokens if token and token.strip()))
    if not normalized_tokens:
        return set()

    normalized_data = {str(key): str(value) for key, value in (data or {}).items()}
    invalid_tokens: set[str] = set()
    success_count = 0
    failure_count = 0

    for start in range(0, len(normalized_tokens), 500):
        batch_tokens = normalized_tokens[start : start + 500]
        messages = [
            messaging.Message(
                token=token,
                notification=messaging.Notification(title=title, body=body),
                data=normalized_data,
            )
            for token in batch_tokens
        ]

        try:
            response = messaging.send_each(messages)
        except Exception as exc:
            # A transport/auth/project-level failure affects the whole batch.
            # Do not deactivate tokens because they may be perfectly valid.
            failure_count += len(batch_tokens)
            logger.exception(
                "FCM batch delivery failed: project_id=%s batch_size=%d error=%s",
                settings.FIREBASE_PROJECT_ID,
                len(batch_tokens),
                exc,
            )
            continue

        success_count += response.success_count
        failure_count += response.failure_count

        for token, send_response in zip(batch_tokens, response.responses):
            if send_response.success:
                continue

            error = send_response.exception
            error_name = type(error).__name__ if error else "UnknownError"
            error_message = str(error) if error else "Unknown FCM error"

            if isinstance(error, messaging.UnregisteredError):
                invalid_tokens.add(token)
                logger.info("FCM token is unregistered and will be deactivated")
            elif isinstance(error, messaging.SenderIdMismatchError):
                invalid_tokens.add(token)
                logger.warning("FCM token belongs to a different Firebase sender/project")
            else:
                # Keep the token active for transient/configuration errors.
                logger.warning(
                    "FCM token delivery failed: error_type=%s error=%s",
                    error_name,
                    error_message,
                )

    logger.info(
        "FCM delivery finished: attempted=%d succeeded=%d failed=%d invalid=%d",
        len(normalized_tokens),
        success_count,
        failure_count,
        len(invalid_tokens),
    )
    return invalid_tokens
