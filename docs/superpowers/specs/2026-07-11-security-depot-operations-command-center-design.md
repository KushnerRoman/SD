# Security Depot Operations Command Center — Demo Design

## Purpose

Build a persistent, interactive manager application for Security Depot's field-service workflow. The demo replaces email-and-calendar-only coordination with one focused operations system while retaining the familiar Gmail-to-Google-Calendar flow technicians already use.

This phase uses realistic simulated Gmail and Google Calendar integrations. It must demonstrate the complete workflow without Google OAuth or live Google API access, while keeping integration boundaries clean enough to replace the simulations with production adapters later.

## Business Context

Security Depot dispatches five to six technicians for intercom, access-control, cameras/CCTV, and cable-management work. A manager currently receives work requests by email, creates or edits Google Calendar events to allocate technicians, and later reads technicians' manually entered completion notes.

The demo must make dispatch, follow-up, and history visible without adding unrelated finance, inventory, payroll, estimating, or stock-management features.

## Validated Product Decisions

- Manager-first Operations Command Center visual direction.
- Existing Flutter web application, FastAPI backend, and SQLite persistence are retained and extended.
- The inbox is a normal mixed mailbox. The manager manually chooses which messages become service calls.
- A simulated Google Calendar technician view demonstrates the field workflow.
- All changes persist after the application closes and reopens.
- A deliberate Settings action can reset the demo to its original sample data.

## Users and Permissions

### Manager

The main application user. The manager can review email, create and edit service calls, assign technicians, schedule work, manage sites and technicians, inspect history, and review completion notifications.

### Technician Simulation

The demo calendar presents the limited information and actions available to a selected technician. It is not a second full administrative application. A technician can open assigned events and submit status, time spent, work performed, materials used, and follow-up notes.

Authentication and production role enforcement are outside this demo phase. The UI must nevertheless keep manager and technician capabilities clearly separated.

## Navigation and Screens

### Dashboard

The manager's home screen provides an immediate operational summary:

- unassigned service calls;
- today's scheduled work;
- work in progress;
- completed work;
- overdue service calls;
- incomplete and return-required work;
- new service-request candidates in the inbox;
- today's dispatch grouped by technician;
- recent technician updates and manager notifications.

Dashboard items are actionable and navigate to filtered source records.

### Inbox

The inbox resembles a restrained Gmail-style mailbox but remains part of the Security Depot application. It includes normal business messages alongside service requests, with search, read state, sender, subject, received time, message preview, labels, and attachments metadata.

Opening a message reveals its full content and a **Create service call** action. Messages already converted show a link to the service call and cannot be accidentally converted twice. The manager may intentionally create an additional related service call only through an explicit confirmation action.

### Service Calls

Service calls support list and Monday-style board views. Managers can filter by status, priority, category, technician, site, and date. Each record opens a detail drawer or page containing core fields, source email, calendar link state, completion report, and an immutable activity timeline.

Statuses are:

- Unassigned
- Scheduled
- In Progress
- Completed
- Incomplete
- Return Required

Categories are:

- Intercom
- Access Control
- Cameras/CCTV
- Cable Management
- Other

### Schedule

The schedule supports day, week, and team views. Technician colors and clear status styling make workload distribution visible. Managers can create, reschedule, and reassign visits. The UI warns about overlapping assignments and invalid time ranges without silently discarding changes.

### Sites

Each site stores name, customer or organization, address, primary contact, phone, email, access instructions, installed-system notes, upcoming service calls, and complete visit history. Search covers customer, site name, address, and contact.

### Technicians

Technician records include name, email, phone, active status, skills, normal working hours, calendar color, current workload, and completion summary. Deactivation preserves historical assignments and prevents new assignments.

### History

History is a searchable operational archive rather than a separate copy of records. It exposes completed, incomplete, and return-required visits by customer, site, technician, service category, status, and date. Results show work performed, elapsed time, materials, and follow-up notes.

### Google Calendar Demo

This screen switches to a selected technician and displays a familiar calendar-style day or week view. Opening an assigned event shows the site, contact, service category, instructions, access notes, and relevant site history.

The technician update form captures:

- status: Completed, Incomplete, or Return Required;
- time spent in minutes;
- work performed;
- materials used, optional;
- follow-up notes, required for Incomplete or Return Required.

Saving updates the simulated calendar event, linked service call, activity timeline, dashboard totals, history, and manager notification in one transaction.

### Settings

Settings displays the simulated Gmail and Calendar connection state and includes a confirmed **Reset demo data** action. No live credentials are collected during this phase.

## Primary Workflow

1. A realistic mixed email arrives in the simulated inbox.
2. The manager opens it and chooses **Create service call**.
3. A dispatch form is prefilled from the message where possible. The manager confirms the site, contact, category, priority, date/time, technician, and instructions.
4. Saving creates the service call, visit, activity entry, and simulated technician calendar event. The source email becomes linked.
5. The assigned technician sees the event in the Google Calendar Demo.
6. The technician opens the event and submits the structured visit update.
7. The application updates the work record and produces a manager notification.
8. The result becomes visible on the dashboard, service-call timeline, site history, technician summary, and History screen.

## Data Model

### EmailMessage

Stores provider identifier, thread identifier, sender, recipients, subject, plain-text body, received time, labels, read state, attachment metadata, and optional linked service-call identifier.

### ServiceCall

Stores identifier, source email, site, category, priority, status, problem summary, instructions, created/updated timestamps, and the manager who created it. A service call owns one or more visits so return trips remain connected to the original request.

### Visit

Stores service call, assigned technician, scheduled start/end, actual duration, status, work performed, materials used, follow-up notes, and simulated calendar event identifier.

### Site

Stores customer and location details, contacts, address, access notes, installed-system notes, and active state.

### Technician

Stores contact details, skills, working hours, calendar color, and active state.

### ActivityEntry

Append-only timeline data recording creation, assignment, schedule changes, status changes, calendar synchronization, and completion reports with actor and timestamp.

### Notification

Stores manager-facing completion, failure, return-visit, overdue, and synchronization notices with read state and linked record.

## Architecture

The Flutter web client communicates with the FastAPI application through repository interfaces. FastAPI owns validation, workflow transitions, and SQLite transactions. SQLite is the authoritative source for all demo state.

Integration ports isolate external-provider behavior:

- `MailProvider` supplies mailbox listing, message details, and linkage state.
- `CalendarProvider` creates and updates technician events and accepts technician reports.
- Demo implementations persist simulated provider records in SQLite.
- Future Google implementations may replace the demo adapters without changing the field-service domain or core screens.

The frontend may use optimistic feedback for ordinary edits, but it must confirm backend success before displaying provider synchronization as complete.

## Validation and Error Handling

- A visit cannot be scheduled without an active technician, site, start time, and end time.
- End time must be later than start time.
- Overlapping technician assignments produce a visible conflict warning and require explicit manager confirmation.
- Duplicate email conversion is blocked by default and linked records are surfaced.
- Completion requires positive time spent and non-empty work-performed notes.
- Incomplete and Return Required updates require follow-up notes.
- Failed saves keep entered values visible and provide a retry action.
- Simulated synchronization failures create a visible warning and notification; they do not erase the underlying service call.
- Empty, loading, offline, and error states are designed for every data-driven screen.

## Visual System

The application follows the approved Operations Command Center direction:

- deep navy navigation and headers;
- Security Depot red for primary actions and urgent attention;
- white working surfaces on a light cool-gray background;
- green for completed work, amber for scheduling attention, blue for active work, and red for overdue or failed work;
- compact but readable desktop information density;
- responsive layouts for narrower browser widths;
- restrained borders, subtle shadows, and clear typographic hierarchy;
- accessible status labels that do not rely on color alone.

The interface uses Security Depot's business identity and service terminology without copying the marketing website's page structure.

## Seed Demo Scenario

Sample data includes five to six technicians with varied skills, multiple condominium and commercial sites, a mixed mailbox, upcoming calls, one overdue call, completed history, one incomplete visit, and one return-required job. Records cover intercom, access-control, CCTV, and cable-management work.

The default dataset must support a compelling walkthrough immediately after reset:

1. open a new service-request email;
2. convert and assign it;
3. confirm it appears on the manager schedule and technician calendar;
4. submit a technician report;
5. observe the notification and updated history.

## Testing and Verification

Backend tests cover database persistence, seed/reset behavior, email conversion, duplicate protection, scheduling validation, conflict warnings, visit updates, activity history, notifications, and dashboard aggregation.

Flutter unit and widget tests cover repository mapping, navigation, inbox conversion, dispatch form validation, service-call filtering, technician update validation, and manager notification presentation.

The final verification includes:

- backend automated tests;
- Flutter analysis and automated tests;
- web production build;
- browser walkthrough at desktop and narrow responsive widths;
- restart test proving SQLite persistence;
- complete seeded workflow demonstration.

## Research Basis

The design reflects Security Depot's publicly described residential, commercial, and condominium security work and the user's stated service categories. Field-service workflow research reinforces keeping email intake, scheduling, technician updates, operational status, and service history connected. Google Calendar's event metadata and provider APIs can support the later production adapter, but live OAuth, consent, webhooks, and Google Workspace administration are intentionally deferred.

Research references:

- https://www.securitydepot.ca/
- https://developers.google.com/workspace/calendar/api/guides/extended-properties
- https://developers.google.com/workspace/gmail/api/guides

## Out of Scope for This Demo

- real Google OAuth, Gmail API, Calendar API, or push notifications;
- customer or technician authentication;
- finance, quoting, invoicing, payroll, inventory, purchasing, or stock;
- route optimization or live GPS tracking;
- SMS, customer portals, or automated email replies;
- production hosting and deployment.

## Acceptance Criteria

The demo is accepted when a manager can complete the full seeded workflow from mixed email to technician report, all linked screens update consistently, data survives application restarts, history remains searchable, the reset action restores the initial scenario, and automated plus browser verification pass.
