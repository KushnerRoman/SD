from __future__ import annotations

from dataclasses import dataclass

import httpx


class GmailSyncError(RuntimeError): pass
class GmailRevokedError(GmailSyncError): pass
class GmailQuotaError(GmailSyncError): pass
class GmailNetworkError(GmailSyncError): pass


@dataclass(frozen=True)
class HistoryResult:
    message_ids: list[str]
    deleted_ids: list[str]
    history_id: str


class GmailProvider:
    base_url = "https://gmail.googleapis.com/gmail/v1/users/me"

    def __init__(self, access_token: str, *, http_client: httpx.Client | None = None) -> None:
        self._token = access_token
        self._client = http_client or httpx.Client(timeout=20.0)

    def _get(self, path: str, params: dict | None = None) -> dict:
        try:
            response = self._client.get(self.base_url + path, params=params, headers={"Authorization": f"Bearer {self._token}"})
        except httpx.HTTPError as error:
            raise GmailNetworkError("Gmail could not be reached") from error
        if response.status_code in (401, 403):
            raise GmailRevokedError("Google authorization is no longer valid")
        if response.status_code == 429:
            raise GmailQuotaError("Gmail quota is temporarily exhausted")
        if response.status_code >= 500:
            raise GmailNetworkError("Gmail is temporarily unavailable")
        try:
            response.raise_for_status()
        except httpx.HTTPStatusError as error:
            raise GmailSyncError("Gmail rejected the synchronization request") from error
        return response.json()

    def list_recent(self) -> list[str]:
        return self._list_message_ids("/messages", {"q": "newer_than:90d"})

    def _list_message_ids(self, path: str, params: dict) -> list[str]:
        ids: list[str] = []
        token = None
        while True:
            page_params = dict(params)
            if token: page_params["pageToken"] = token
            page = self._get(path, page_params)
            ids.extend(str(item["id"]) for item in page.get("messages", []) if item.get("id"))
            token = page.get("nextPageToken")
            if not token: return ids

    def get_message(self, message_id: str) -> dict:
        return self._get(f"/messages/{message_id}", {"format": "full"})

    def list_history(self, history_id: str) -> HistoryResult:
        added: list[str] = []
        deleted: list[str] = []
        token = None
        latest = history_id
        while True:
            params = {"startHistoryId": history_id, "historyTypes": ["messageAdded", "messageDeleted"]}
            if token: params["pageToken"] = token
            page = self._get("/history", params)
            latest = str(page.get("historyId") or latest)
            for event in page.get("history", []):
                added.extend(str(x["message"]["id"]) for x in event.get("messagesAdded", []) if x.get("message", {}).get("id"))
                deleted.extend(str(x["message"]["id"]) for x in event.get("messagesDeleted", []) if x.get("message", {}).get("id"))
            token = page.get("nextPageToken")
            if not token: return HistoryResult(list(dict.fromkeys(added)), list(dict.fromkeys(deleted)), latest)
