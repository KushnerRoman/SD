from __future__ import annotations

from html import escape


def unavailable_page() -> str:
    return _shell("Report unavailable", "<h1>Report unavailable</h1><p>This report link is unavailable.</p>")


def report_form(visit, csrf_token: str, error: str = "") -> str:
    site = escape(visit.site.name if visit.site else "Service visit")
    technician = escape(visit.technician_name or "Technician")
    message = f'<p class="error">{escape(error)}</p>' if error else ""
    body = f'''<h1>Technician report</h1><p>{site}</p><p>{technician}</p>{message}
<form method="post"><input type="hidden" name="csrf_token" value="{escape(csrf_token)}">
<label>Status<select name="status" required><option>Completed</option><option>Incomplete</option><option>Return Required</option></select></label>
<label>Duration (minutes)<input name="duration_minutes" type="number" min="1" required></label>
<label>Work performed<textarea name="work_performed" required></textarea></label>
<label>Materials used<textarea name="materials_used"></textarea></label>
<label>Follow-up notes (required for Incomplete or Return Required)<textarea name="follow_up_notes"></textarea></label>
<button type="submit">Submit report</button></form>'''
    return _shell("Technician report", body)


def success_page() -> str:
    return _shell("Report submitted", "<h1>Report submitted</h1><p>Thank you. Your report has been recorded.</p>")


def _shell(title: str, body: str) -> str:
    return f'''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{escape(title)}</title><style>body{{font:16px system-ui;margin:auto;max-width:42rem;padding:1rem}}label,input,select,textarea,button{{display:block;width:100%;box-sizing:border-box;margin:.6rem 0}}textarea{{min-height:7rem}}button{{padding:.8rem}}.error{{color:#a00}}</style></head><body>{body}</body></html>'''
