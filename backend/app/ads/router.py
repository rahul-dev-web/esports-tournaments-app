"""AdMob server-side verification endpoints."""

from __future__ import annotations

import base64
import json
import logging
import time
from functools import lru_cache
from typing import Any
from urllib.parse import parse_qsl, unquote_plus

import httpx
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from fastapi import APIRouter, HTTPException, Request

from app.common.config import settings
from app.core.database import SessionLocal
from app.core.models import Registration, Team, Tournament
from app.registrations.router import _record_reward_event


logger = logging.getLogger(__name__)
router = APIRouter()

_PUBLIC_KEYS_CACHE: dict[str, Any] = {"fetched_at": 0.0, "keys": {}}


def _decode_base64url(value: str) -> bytes:
    padded = value + "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(padded.encode("utf-8"))


@lru_cache(maxsize=1)
def _public_keys_url() -> str:
    return settings.ADMOB_SSV_PUBLIC_KEYS_URL


async def _fetch_public_keys() -> dict[int, ec.EllipticCurvePublicKey]:
    now = time.time()
    if _PUBLIC_KEYS_CACHE["keys"] and now - _PUBLIC_KEYS_CACHE["fetched_at"] < 24 * 60 * 60:
        return _PUBLIC_KEYS_CACHE["keys"]

    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(_public_keys_url())
        response.raise_for_status()
        data = response.json()

    keys: dict[int, ec.EllipticCurvePublicKey] = {}
    for entry in data.get("keys", []):
        key_id = int(entry["keyId"])
        pem = entry.get("pem")
        if not pem:
            continue
        public_key = serialization.load_pem_public_key(pem.encode("utf-8"))
        if isinstance(public_key, ec.EllipticCurvePublicKey):
            keys[key_id] = public_key

    if not keys:
        raise HTTPException(status_code=503, detail="No AdMob public keys available")

    _PUBLIC_KEYS_CACHE["fetched_at"] = now
    _PUBLIC_KEYS_CACHE["keys"] = keys
    return keys


def _extract_content_and_signature(raw_query: str) -> tuple[bytes, bytes, int]:
    signature_index = raw_query.find("&signature=")
    if signature_index == -1:
        raise HTTPException(status_code=400, detail="Missing signature parameter")

    content = raw_query[:signature_index].encode("utf-8")
    trailing = raw_query[signature_index + 1 :]
    params = dict(parse_qsl(trailing, keep_blank_values=True))
    signature = params.get("signature")
    key_id = params.get("key_id")
    if not signature or not key_id:
        raise HTTPException(status_code=400, detail="Missing signature or key_id parameter")
    return content, _decode_base64url(unquote_plus(signature)), int(key_id)


def _parse_custom_data(value: str | None) -> dict[str, str]:
    if not value:
        return {}
    try:
        parsed = json.loads(value)
        if isinstance(parsed, dict):
            return {str(key): str(val) for key, val in parsed.items() if val is not None}
    except json.JSONDecodeError:
        pass

    pieces = [piece.strip() for piece in value.split("|") if piece.strip()]
    if not pieces:
        return {}
    result: dict[str, str] = {"registration_id": pieces[0]}
    if len(pieces) > 1:
        result["user_id"] = pieces[1]
    if len(pieces) > 2:
        result["provider_event_id"] = pieces[2]
    return result


@router.get("/admob/ssv")
async def admob_ssv(request: Request):
    raw_query = request.scope.get("query_string", b"").decode("utf-8")
    if not raw_query:
        raise HTTPException(status_code=400, detail="Missing callback query string")

    content, signature, key_id = _extract_content_and_signature(raw_query)
    public_keys = await _fetch_public_keys()
    public_key = public_keys.get(key_id)
    if not public_key:
        raise HTTPException(status_code=401, detail="Unknown AdMob verification key")

    try:
        public_key.verify(signature, content, ec.ECDSA(hashes.SHA256()))
    except InvalidSignature as exc:
        raise HTTPException(status_code=401, detail="Invalid AdMob SSV signature") from exc

    params = request.query_params
    custom_data = _parse_custom_data(params.get("custom_data"))
    registration_id = custom_data.get("registration_id")
    user_id = custom_data.get("user_id") or params.get("user_id")
    provider_event_id = params.get("transaction_id") or custom_data.get("provider_event_id")
    provider = params.get("ad_network", "admob")

    if not registration_id or not user_id:
        raise HTTPException(status_code=400, detail="custom_data must include registration_id and user_id")
    if not provider_event_id:
        raise HTTPException(status_code=400, detail="Missing transaction_id/provider_event_id")

    db = SessionLocal()
    try:
        registration = db.query(Registration).filter(Registration.id == registration_id).first()
        if not registration:
            raise HTTPException(status_code=404, detail="Registration not found")

        tournament = db.query(Tournament).filter(Tournament.id == registration.tournament_id).first()
        team = db.query(Team).filter(Team.id == registration.team_id).first()
        if not tournament or not team:
            raise HTTPException(status_code=404, detail="Tournament or team not found")

        _record_reward_event(
            db,
            registration=registration,
            tournament=tournament,
            team=team,
            user_id=user_id,
            provider=str(provider),
            provider_event_id=provider_event_id,
        )
    finally:
        db.close()

    return {"success": True, "registration_id": registration_id, "transaction_id": provider_event_id}
