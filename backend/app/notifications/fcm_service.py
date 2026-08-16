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


def send_push(
    tokens: Iterable[str],
    title: str,
    body: str,
    data: dict[str, str] | None = None,
) -> set[str]:
    """Send push notifications and return tokens known to be invalid."""
    messaging = _get_messaging()
    if messaging is None:
        return set()

    invalid_tokens: set[str] = set()
    for token in tokens:
        try:
            messaging.send(
                messaging.Message(
                    token=token,
                    notification=messaging.Notification(title=title, body=body),
                    data=data or {},
                )
            )
        except messaging.UnregisteredError:
            # FCM explicitly says this registration is no longer valid and it
            # should be removed/deactivated on the application server.
            invalid_tokens.add(token)
            logger.info("Deactivating unregistered FCM token")
        except messaging.SenderIdMismatchError:
            # The token belongs to a different sender/project and cannot be
            # used by this Firebase configuration.
            invalid_tokens.add(token)
            logger.warning("Deactivating FCM token with sender-id mismatch")
        except Exception as exc:
            # Transient/configuration failures must never make the database
            # notification fail and are intentionally retained for retry.
            logger.warning("FCM delivery failed for token: %s", exc)

    return invalid_tokens
