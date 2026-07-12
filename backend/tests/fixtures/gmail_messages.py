import base64


def encoded(value: str) -> str:
    return base64.urlsafe_b64encode(value.encode()).decode().rstrip("=")


PLAIN = {
    "id": "msg-1", "threadId": "thread-1", "historyId": "12", "internalDate": "1700000000000",
    "labelIds": ["INBOX", "UNREAD"],
    "payload": {"mimeType": "text/plain", "headers": [
        {"name": "From", "value": "Alice <alice@example.com>"},
        {"name": "To", "value": "Ops <ops@example.com>"},
        {"name": "Subject", "value": "=?utf-8?b?U2VydmljZSDinJM=?="},
    ], "body": {"data": encoded("Hello ops"), "size": 9}},
}
