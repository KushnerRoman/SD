# SD Jobber-Style Operations Core Design

Date: 2026-06-17
Status: Approved design

## Context

SD is the Security Depot field service management platform. It should be a functional clone inspired by Jobber's field-service workflows, adapted for security systems, access control, CCTV, intercoms, automatic doors, and building security infrastructure.

The existing project already uses Flutter for the app, FastAPI for the backend, and PostgreSQL as the intended database. Existing domain concepts include Site, Job, Visit, Technician, CalendarDetail, job status, visit status, and parts status.

Jobber research summary:
- Jobber is organized around field service lifecycle management: requests, quotes, scheduling, work orders/jobs, client management, invoicing, payments, notifications, team management, client portal, and reporting.
- For SD's first version, the relevant Jobber-inspired areas are work orders/jobs, scheduling, client/site management, team management, visit tracking, notifications, and operational dashboarding.
- Revenue features such as quotes, invoices, payments, customer portal, marketing, reviews, and consumer financing are intentionally deferred.

Sources:
- Jobber feature overview: https://www.getjobber.com/features/
- Jobber CRM/client management: https://www.getjobber.com/features/field-service-crm/
- Jobber scheduling: https://www.getjobber.com/features/scheduling/
- Jobber job management: https://www.getjobber.com/features/jobs/
- Microsoft Graph delta query: https://learn.microsoft.com/en-us/graph/delta-query-overview
- Microsoft Graph webhook/change notification guidance: https://learn.microsoft.com/en-us/graph/change-notifications-delivery-webhooks
- Microsoft Graph best practices: https://learn.microsoft.com/en-us/graph/best-practices-concept

## Product Direction

The MVP will be an Operations Core product. It will not try to implement all of Jobber at once.

Included:
- Dashboard
- SD Inbox for Outlook email intake
- Schedule
- Jobs
- Sites
- Technicians
- Technician visit update workflow
- Parts and return-visit tracking
- Activity history

Deferred:
- Quotes and estimates
- Invoices and payments
- Online booking
- Customer/client portal
- AI receptionist
- Marketing, reviews, referrals
- Advanced profitability reporting
- GPS route optimization

## Primary Users

Service Manager:
- Reviews incoming work.
- Creates and updates jobs.
- Assigns technicians.
- Tracks schedule, workload, unresolved work, parts, and return visits.

Office / Service Coordinator:
- Triage Outlook emails.
- Links messages to sites, jobs, visits, and technicians.
- Updates job information.
- Communicates context to technicians.

Field Technician:
- Views assigned visits.
- Reviews site/job details.
- Submits visit updates.
- Records work completed.
- Flags parts needed, return visits, access issues, or manager review.

## Navigation Shape

The app shell will use an operations-hub layout with left navigation:

- Dashboard
- SD Inbox
- Schedule
- Jobs
- Sites
- Technicians

The office experience is the main surface. The technician experience is a simple focused workflow, available from the same app but optimized for mobile/field usage.

## Core Workflows

### Structured Job Workflow

1. Manager or coordinator creates a Job.
2. Job is linked to a Site.
3. One or more Visits are scheduled under the Job.
4. Technician is assigned to each Visit.
5. Technician submits Visit Update.
6. Job status updates based on visit outcome.
7. Parts, return visit, or manager review are tracked when needed.

### Calendar-First Workflow

1. Office user creates a Visit directly from the Schedule.
2. SD creates a new Job automatically or links the Visit to an existing Job.
3. If the Site is unclear, the record is marked Needs Site Match.
4. Technician and time are assigned from the Schedule.
5. Later, office staff can enrich the Job record.

### Outlook Email Intake Workflow

1. SD syncs Outlook/Microsoft 365 mail through Microsoft Graph.
2. New messages appear in SD Inbox.
3. SD stores message metadata and body preview.
4. SD suggests likely Site, Contact, Job, Visit, priority, and technician where possible.
5. Office user confirms one of these actions:
   - Link email to existing Site.
   - Link email to existing Job.
   - Create Job from email.
   - Create Visit from email.
   - Assign or mention Technician.
   - Ignore/archive email as not operational.
6. SD records the action in Activity Log.

The email intake must be part of MVP, not a future feature.

## Outlook Integration Design

Backend service: Outlook Intake

Responsibilities:
- Authenticate with Microsoft Graph.
- Subscribe to mailbox change notifications where available.
- Run delta sync to detect created/updated messages.
- Store sync state, including delta links.
- Deduplicate messages by provider message id and conversation/thread id.
- Extract operational metadata.
- Create SD Inbox records.
- Trigger site/job matching suggestions.

Recommended sync strategy:
- Use Microsoft Graph change notifications as the prompt that new mail exists.
- Use Microsoft Graph delta query to fetch actual changes and recover missed notifications.
- Run a periodic fallback sync so SD does not depend only on webhooks.

Mail data to store:
- Provider: outlook
- Message id
- Conversation id
- Internet message id when available
- Sender name and email
- Recipients
- Subject
- Received timestamp
- Body preview
- Normalized body text when available
- Attachment metadata
- Sync status
- Triage status

Triage statuses:
- Untriaged
- Needs Review
- Matched to Site
- Job Candidate
- Linked to Existing Job
- Linked to Visit
- Ignored

Matching inputs:
- Sender email
- Sender domain
- Contact names
- Site name
- Address or building name
- Phone numbers
- Slack channel names when available
- Existing job titles
- Recent conversation history
- Keywords such as emergency, access, camera, intercom, gate, door, panel, alarm, service, install, repair

AI may suggest matches later, but MVP matching must remain explainable and user-confirmed.

## Core Entities

Existing entities remain central:
- Site
- Job
- Visit
- Technician

New or expanded entities:

EmailMessage:
- Stores Outlook message metadata and triage status.
- Links to Site, Job, Visit, Contact, or Technician when applicable.

Request:
- Represents an operational request before it becomes a confirmed Job.
- May be created from EmailMessage or manually.

Contact:
- Belongs to Site.
- Stores name, role, email, phone, and notes.

PartNeed:
- Belongs to Job or Visit.
- Stores requested part, status, notes, and source.

Attachment:
- Stores metadata for email attachments and technician-uploaded files/photos.

ActivityLog:
- Records important events across Site, Job, Visit, EmailMessage, and Technician.

## Screens

### Dashboard

Shows:
- Today's visits
- Open jobs
- Untriaged emails
- Jobs waiting for parts
- Jobs needing return visit
- Jobs needing manager review
- Technician workload

### SD Inbox

Shows Outlook messages that require operational triage.

Actions:
- Link to Site.
- Link to Job.
- Create Job.
- Create Visit.
- Assign Technician.
- Mark ignored.

### Schedule

Views:
- Day
- Week
- List

Capabilities:
- Create Visit directly.
- Assign Technician.
- Link or auto-create Job.
- Filter by technician, status, priority, and site.

### Jobs

Shows:
- Job list with status, priority, site, assigned technician, and next visit.
- Job detail with description, visits, linked emails, parts, notes, and activity.
- Follow-up flags.

### Sites

Shows:
- Site profile.
- Address and contact details.
- Access notes.
- Installed system notes.
- Job history.
- Visit history.
- Linked emails.

### Technicians

Shows:
- Technician roster.
- Contact information.
- Assigned visits.
- Workload.
- Current open jobs.

### Technician Visit Update

Shows:
- Today's assigned visits.
- Site and job details.
- Access notes.
- Work instructions.

Technician can submit:
- Visit status
- Work summary
- Parts used
- Parts needed
- Return visit needed
- Could not access site
- Manager review needed
- Photos/attachments in a later implementation phase

## Status Model

Job statuses:
- New
- Scheduled
- In Progress
- Waiting Parts
- Need Return Visit
- Completed
- Manager Review

Visit statuses:
- Scheduled
- In Progress
- Completed
- Not Completed
- Need Return Visit
- Waiting for Parts
- Could Not Access Site
- Need Manager Review

Email triage statuses:
- Untriaged
- Needs Review
- Matched to Site
- Job Candidate
- Linked to Existing Job
- Linked to Visit
- Ignored

## Error Handling

Outlook sync:
- Show last successful sync timestamp.
- Show sync error state in admin/diagnostics area.
- Do not block manual work when sync fails.
- Use delta sync to recover from missed webhooks.
- Deduplicate messages before creating SD Inbox records.

Matching:
- Low-confidence matches stay in Needs Review.
- Users can override suggested Site, Job, Visit, or Technician.
- All confirmed and changed links are recorded in Activity Log.

Scheduling:
- Visits can exist temporarily without a confirmed Site or Job, but must be flagged Needs Site Match or Needs Job Match.
- Such records are visible on Dashboard until resolved.

Technician updates:
- MVP can require online submission.
- Offline local save and retry is a later enhancement unless implementation cost is low.

## Testing Strategy

Backend:
- Unit tests for Outlook message normalization.
- Unit tests for site/contact/job matching rules.
- API tests for EmailMessage creation and deduplication.
- API tests for linking email to Site, Job, Visit, and Technician.
- API tests for creating Job from email.
- API tests for creating Visit from schedule with auto-created Job.
- API tests for Job and Visit status transitions.

Frontend:
- Widget tests for Dashboard summary cards.
- Widget tests for SD Inbox triage actions.
- Widget tests for Schedule visit creation.
- Widget tests for Jobs list/detail.
- Widget tests for Technician Visit Update.

Seed data:
- Outlook-like email messages.
- Known and unknown sites.
- Existing jobs and visits.
- Technicians with different workloads.
- Jobs waiting for parts and return visits.

## Acceptance Criteria

- Office user can see incoming Outlook messages in SD Inbox.
- Office user can link an email to a Site.
- Office user can create a Job from an email.
- Office user can create a Visit from Schedule and have SD create/link the Job.
- Manager can view open jobs, today's visits, parts-needed work, return visits, and untriaged emails from Dashboard.
- Technician can open an assigned Visit and submit a structured update.
- Site history shows jobs, visits, and linked emails.
- Duplicate Outlook messages do not create duplicate SD Inbox records.
- Records needing human review remain visible until resolved.

## Open Decisions For Implementation Planning

- Which Microsoft 365 mailbox or shared mailbox SD should sync first.
- Whether authentication will use delegated user auth or application permissions.
- Whether the first Outlook sync should be read-only or also mark/categorize emails in Outlook.
- Whether technician mobile offline support is required in the first implementation increment.
