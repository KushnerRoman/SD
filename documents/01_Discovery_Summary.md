# Security Depot FSM - Discovery Summary

## Current Situation

Security Depot currently manages operations using:
- Outlook Email
- Google Calendar
- Slack
- Excel spreadsheets
- Technician notes

## Company Structure

- 4 Technicians
- 3 Service Staff
- 2 Managers

## Current Workflow

1. Customer sends email/request.
2. Manager reviews request.
3. Manager creates a calendar event manually.
4. Event is assigned to a technician.
5. Technician receives the event on Google Calendar.
6. Technician performs work.
7. Technician writes free-text notes in the calendar event.
8. Managers review notes, Slack messages and emails.

## Problems

### Information is fragmented
Information is spread across:
- Email
- Calendar
- Slack
- Excel
- Personal knowledge

### No structured status tracking
Technicians use free-text updates.

### Return visits are difficult to track
Jobs may take multiple visits over days or weeks.

### Parts tracking is informal
No structured tracking of:
- Required parts
- Used parts
- Part source

### Site history is difficult to search
Historical information is buried inside calendar events.

## Key Findings

The business is centered around:
- Sites
- Jobs
- Visits

Job != Visit

A single Job may contain multiple Visits.

## Proposed Solution

A centralized Field Service Management System that:
- Creates Jobs
- Assigns Technicians
- Tracks Visits
- Tracks Parts
- Tracks Status
- Maintains Site History
- Integrates with Google Calendar
