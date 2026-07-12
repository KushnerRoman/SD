from __future__ import annotations

import base64
import hashlib
import hmac
import secrets
from dataclasses import dataclass
from datetime import datetime, timedelta
from urllib.parse import urlencode

import httpx
from cryptography.fernet import Fernet, InvalidToken
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.google.config import GoogleSettings
from app.models import GoogleCredential


class OAuthStateError(ValueError):
    """Raised for missing, expired, or mismatched OAuth state."""


class CredentialDecryptionError(ValueError):
    """Raised when encrypted credential data cannot be authenticated."""


@dataclass(frozen=True)
class PendingAuthorization:
    code_verifier: str
    expires_at: datetime


class CredentialCipher:
    def __init__(self, key: str) -> None:
        self._fernet = Fernet(key.encode())

    def encrypt(self, value: str) -> bytes:
        return self._fernet.encrypt(value.encode())

    def decrypt(self, value: bytes) -> str:
        try:
            return self._fernet.decrypt(value).decode()
        except InvalidToken as error:
            raise CredentialDecryptionError("Credential data could not be authenticated") from error


class GoogleOAuthService:
    def __init__(
        self,
        settings: GoogleSettings,
        cipher: CredentialCipher,
        *,
        http_client: httpx.Client | None = None,
    ) -> None:
        self.settings = settings
        self.cipher = cipher
        self.http_client = http_client or httpx.Client(timeout=15.0)
        self.pending_authorizations: dict[str, PendingAuthorization] = {}

    def authorization_url(self, *, has_refresh_token: bool) -> str:
        self._discard_expired_states()
        state = secrets.token_urlsafe(32)
        verifier = secrets.token_urlsafe(64)
        challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
        self.pending_authorizations[state] = PendingAuthorization(
            code_verifier=verifier,
            expires_at=datetime.utcnow() + timedelta(minutes=10),
        )
        params = {
            "client_id": self.settings.client_id,
            "redirect_uri": self.settings.redirect_uri,
            "response_type": "code",
            "scope": " ".join(self.settings.scopes),
            "access_type": "offline",
            "include_granted_scopes": "true",
            "state": state,
            "code_challenge": challenge,
            "code_challenge_method": "S256",
        }
        if not has_refresh_token:
            params["prompt"] = "consent"
        return f"{self.settings.authorization_endpoint}?{urlencode(params)}"

    def exchange_code(self, *, code: str, state: str) -> dict:
        pending = self._consume_state(state)
        response = self.http_client.post(
            self.settings.token_endpoint,
            data={
                "code": code,
                "client_id": self.settings.client_id,
                "client_secret": self.settings.client_secret,
                "redirect_uri": self.settings.redirect_uri,
                "grant_type": "authorization_code",
                "code_verifier": pending.code_verifier,
            },
        )
        response.raise_for_status()
        return response.json()

    def refresh_access_token(self, refresh_token: str) -> dict:
        response = self.http_client.post(
            self.settings.token_endpoint,
            data={
                "client_id": self.settings.client_id,
                "client_secret": self.settings.client_secret,
                "refresh_token": refresh_token,
                "grant_type": "refresh_token",
            },
        )
        response.raise_for_status()
        return response.json()

    def revoke(self, token: str) -> None:
        response = self.http_client.post(self.settings.revoke_endpoint, params={"token": token})
        response.raise_for_status()

    def account_email(self, access_token: str) -> str:
        response = self.http_client.get(
            self.settings.userinfo_endpoint,
            headers={"Authorization": f"Bearer {access_token}"},
        )
        response.raise_for_status()
        email = response.json().get("email")
        if not isinstance(email, str) or not email:
            raise ValueError("Google userinfo response did not include an email")
        return email

    def store_tokens(
        self,
        session: Session,
        *,
        account_email: str,
        refresh_token: str,
        expires_at: datetime | None = None,
    ) -> GoogleCredential:
        record = session.scalar(select(GoogleCredential).limit(1))
        if record is None:
            record = GoogleCredential(account_email=account_email, encrypted_refresh_token=b"")
            session.add(record)
        record.account_email = account_email
        record.encrypted_refresh_token = self.cipher.encrypt(refresh_token)
        record.expires_at = expires_at
        record.updated_at = datetime.utcnow()
        session.commit()
        session.refresh(record)
        return record

    def load_refresh_token(self, record: GoogleCredential) -> str:
        return self.cipher.decrypt(record.encrypted_refresh_token)

    def _consume_state(self, supplied_state: str) -> PendingAuthorization:
        self._discard_expired_states()
        matched = next(
            (candidate for candidate in self.pending_authorizations if hmac.compare_digest(candidate, supplied_state)),
            None,
        )
        if matched is None:
            raise OAuthStateError("Invalid or expired OAuth state")
        return self.pending_authorizations.pop(matched)

    def _discard_expired_states(self) -> None:
        now = datetime.utcnow()
        for state in [key for key, value in self.pending_authorizations.items() if value.expires_at <= now]:
            self.pending_authorizations.pop(state, None)
