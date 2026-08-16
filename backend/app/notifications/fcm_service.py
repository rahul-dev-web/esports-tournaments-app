"""Firebase Cloud Messaging delivery helpers.

The service is deliberately optional: the API keeps working when Firebase
credentials are not configured (useful for local development and tests).
"""

from __future__ import annotations

import logging
from typing import Iterable

from app.common.config import settings

logger = logging.getLogger(__name__)

_initialized = False


def _get_messaging():
    """Lazily initialize Firebase Admin SDK and return messaging module."""
    global _initialized
    try:
        import firebase_admin
        from firebase_admin import credentials, messaging
    except ImportError:
        logger.warning("firebase-admin is not installed; FCM delivery is disabled")
        return None

    if not settings.FIREBASE_PROJECT_ID or not settings.FIREBASE_CLIENT_EMAIL or not settings.FIREBASE_PRIVATE_KEY:
        return None

    if not _initialized:
        try:
            private_key = settings.FIREBASE_PRIVATE_KEY.replace("\\n", "\n")
            credential = credentials.Certificate(
                {
                    "type": "service_account",
                    "project_id": settings.FIREBASE_PROJECT_ID,
                    "client_email": settings.FIREBASE_CLIENT_EMAIL,
                    "private_key": private_key,
                    "token_uri": "https://oauth2.googleapis.com/token",
                }
            )
            try:
                firebase_admin.get_app()
            except ValueError:
                firebase_admin.initialize_app(credential)
            _initialized = True
        except Exception:
            logger.exception("Failed to initialize Firebase Admin SDK")
            return None

    return messaging


def send_push(tokens: Iterable[str], title: str, body: str, data: dict[str, str] | None = None) -> int:
    """Send a notification to active FCM tokens and return successful sends."""
    messaging = _get_messaging()
    if messaging is None:
        return 0

    success_count = 0
    for token in tokens:
        try:
            messaging.send(
                messaging.Message(
                    token=token,
                    notification=messaging.Notification(title=title, body=body),
                    data=data or {},
                )
            )
            success_count += 1
        except Exception as exc:
            # A failed token must never make the database notification fail.
            logger.warning("FCM delivery failed for token: %s", exc)

    return success_count
