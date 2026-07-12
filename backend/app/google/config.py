from __future__ import annotations

import os
from dataclasses import dataclass


class GoogleConfigurationError(RuntimeError):
    """Raised when required Google integration configuration is absent."""


@dataclass(frozen=True)
class GoogleSettings:
    client_id: str
    client_secret: str
    redirect_uri: str
    token_encryption_key: str
    scopes: tuple[str, ...] = (
        "openid",
        "email",
        "https://www.googleapis.com/auth/gmail.readonly",
        "https://www.googleapis.com/auth/calendar.app.created",
        "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
    )
    authorization_endpoint: str = "https://accounts.google.com/o/oauth2/v2/auth"
    token_endpoint: str = "https://oauth2.googleapis.com/token"
    revoke_endpoint: str = "https://oauth2.googleapis.com/revoke"
    userinfo_endpoint: str = "https://openidconnect.googleapis.com/v1/userinfo"

    @classmethod
    def from_env(cls) -> "GoogleSettings":
        names = {
            "client_id": "GOOGLE_CLIENT_ID",
            "client_secret": "GOOGLE_CLIENT_SECRET",
            "redirect_uri": "GOOGLE_REDIRECT_URI",
            "token_encryption_key": "TOKEN_ENCRYPTION_KEY",
        }
        values = {field: os.getenv(name, "").strip() for field, name in names.items()}
        missing = [names[field] for field, value in values.items() if not value]
        if missing:
            raise GoogleConfigurationError("Missing required environment variables: " + ", ".join(missing))
        if values["redirect_uri"] != "http://127.0.0.1:8765/auth/google/callback":
            raise GoogleConfigurationError("GOOGLE_REDIRECT_URI must use the documented 127.0.0.1 callback")
        return cls(**values)
