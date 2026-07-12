from __future__ import annotations

import httpx


class CalendarError(RuntimeError): pass
class CalendarAuthorizationError(CalendarError): pass
class CalendarConflictError(CalendarError): pass
class CalendarNetworkError(CalendarError): pass


class CalendarProvider:
    base_url = "https://www.googleapis.com/calendar/v3"

    def __init__(self, access_token: str, *, http_client: httpx.Client | None = None):
        self._token = access_token
        self._client = http_client or httpx.Client(timeout=20.0)

    def _request(self, method, path, *, params=None, json=None, headers=None):
        merged = {"Authorization": f"Bearer {self._token}", **(headers or {})}
        try:
            response = self._client.request(method, self.base_url + path, params=params, json=json, headers=merged)
        except httpx.HTTPError as error:
            raise CalendarNetworkError("Calendar could not be reached") from error
        if response.status_code in (401, 403): raise CalendarAuthorizationError("Google authorization is no longer valid")
        if response.status_code == 412: raise CalendarConflictError("Calendar event changed remotely")
        if response.status_code >= 500: raise CalendarNetworkError("Calendar is temporarily unavailable")
        return response

    def list_calendars(self):
        return self._request("GET", "/users/me/calendarList").json().get("items", [])

    def create_service_calendar(self, summary="Security Depot Service"):
        return self._request("POST", "/calendars", json={"summary": summary, "timeZone": "America/Denver"}).json()

    def insert_event(self, calendar_id, event):
        response = self._request("POST", f"/calendars/{calendar_id}/events", params={"sendUpdates": "all"}, json=event)
        if response.status_code == 409:
            return self.get_event(calendar_id, event["id"])
        response.raise_for_status(); return response.json()

    def get_event(self, calendar_id, event_id):
        response = self._request("GET", f"/calendars/{calendar_id}/events/{event_id}")
        response.raise_for_status(); return response.json()

    def update_event(self, calendar_id, event_id, event, etag):
        response = self._request("PATCH", f"/calendars/{calendar_id}/events/{event_id}", params={"sendUpdates": "all"}, json=event, headers={"If-Match": etag})
        response.raise_for_status(); return response.json()

    def get_changed_events(self, calendar_id, sync_token=None):
        params = {"syncToken": sync_token} if sync_token else {"singleEvents": "true"}
        response = self._request("GET", f"/calendars/{calendar_id}/events", params=params)
        response.raise_for_status(); return response.json()
