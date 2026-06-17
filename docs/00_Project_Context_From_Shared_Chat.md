# Project Context From Shared Chat

## Source

Imported from the shared ChatGPT conversation:

https://chatgpt.com/share/6a1cd8eb-6578-83ea-820f-a807114dbf4d

## Language Rule

All project artifacts beyond casual conversation should be written in English:

- System design
- UI mockups
- Workflow definitions
- Database schemas
- Field names
- Status names
- API structures
- User stories
- Technical documentation
- Screen layouts
- Generated project content

## Company Context

The company is a low-voltage / security integration company in the Calgary area. The work includes:

- CCTV and IP camera systems
- NVRs and video recording
- Access control
- Card readers and credentials
- Electric strikes and maglocks
- REX sensors
- Intercoms
- Alarm systems
- CAT5/CAT6 cabling and network infrastructure
- Field troubleshooting
- Installations and service work in residential, commercial, and industrial buildings

## Team Structure

- 4 technicians
- 3 service / office staff
- 2 managers

## Current Operating Model

Managers and service staff receive customer emails and messages about service issues, installations, project work, and follow-up tasks.

Managers manually review the work, prioritize it, and assign it to technicians based on:

- Urgency
- Technician availability
- Technician location
- Calendar load
- Type of work

The current workflow uses:

- Outlook / email for managers and office staff
- Google Calendar or phone calendar for technicians
- Slack for ongoing communication
- Excel spreadsheets for management tracking
- Technician notes inside calendar events

Technicians mostly do not use Outlook directly. They use the phone calendar connected to their email account, Slack, and navigation apps such as Waze or Google Maps.

## Core Problem

The company does not need a simple calendar replacement or a generic dispatch board.

The real problem is operational memory and follow-through:

- Jobs can span multiple days or weeks.
- A technician may visit a site, discover that parts are needed, and the task can be forgotten.
- Updates are spread across calendar notes, Slack, email, and manager memory.
- Work can include service calls, installations, projects, parts orders, return visits, and urgent same-day calls.
- The current calendar event often acts as a ticket, dispatch record, work log, and knowledge base at the same time.

The main goal is to reduce lost information and help managers track work status without forcing technicians into a complex new system on day one.

## Product Direction

Build a field service management system tailored to a security / access control company.

The system should initially sit above the existing tools rather than replace them immediately.

It should help managers and service staff:

- Capture work from email or manually entered requests
- Create structured jobs
- Assign work to technicians
- View technician schedules and locations
- Track job status
- Track return visits
- Track parts needs
- Keep site history
- See what was completed, not completed, or waiting

Technicians can keep using calendar events during the early MVP, but the system should gradually introduce a simple technician update screen.

## Important Product Decision

The central object should not be a calendar event.

The system should model:

- Site
- Job
- Visit
- Technician
- Customer
- Part
- Vendor
- Attachment
- Activity Log

Calendar events are only one representation of scheduled technician visits.

## First MVP Flow

Focus on one workflow first:

1. Customer email or request comes in.
2. A job is created.
3. A manager assigns the job to a technician.
4. A calendar event is created or updated.
5. The technician performs the visit.
6. The technician provides a structured update.
7. The job status and activity log are updated.
8. The manager dashboard shows current status and follow-up needs.

Out of scope for the first MVP:

- Full inventory management
- Invoicing
- Customer portal
- Heavy AI automation
- Replacing Outlook completely
- Replacing Slack completely

## Technician Update Form Direction

Instead of only free-text notes, technicians should eventually have a simple structured update screen.

Suggested fields:

- Status
  - Completed
  - Not completed
  - Need return visit
  - Waiting for parts
  - Could not access site
  - Need manager review
- Time
  - Start time
  - End time
  - Total time
- Work done
- Parts
  - No parts needed
  - Parts used
  - Parts needed
  - Parts picked up
- Parts source
  - Office
  - ADI
  - Anixter
  - Aartech
  - Another technician
  - Customer supplied
  - Need to order
- Photos or Slack link

## Architecture Direction

The agreed technical direction from the shared conversation:

```text
App: Flutter
Backend: Python FastAPI
Database: PostgreSQL
Maps: Google Maps API
Calendar: Google Calendar API
Auth: Google OAuth
Storage: Local or S3-compatible
```

Reasoning:

- The app should run on desktop and Android.
- Flutter is a strong fit for one codebase across desktop and Android.
- FastAPI and PostgreSQL are a practical backend foundation.
- Google Calendar matters because technicians currently rely on phone calendar workflows.

## Recommended Document Set

The previous conversation recommended preparing concise English documents before writing code:

1. Product Vision Document
2. MVP Scope Document
3. Core Workflow Document
4. Data Model / Entities
5. Screen List / Wireframe Notes
6. Technical Architecture
7. MVP Roadmap
8. AI Features / Future Integrations

Suggested folder structure:

```text
SD/
├── docs/
│   ├── 00_Project_Context_From_Shared_Chat.md
│   ├── 01_Product_Vision.md
│   ├── 02_System_Architecture.md
│   ├── 03_Database_Design.md
│   ├── 04_User_Flows.md
│   ├── 05_API_Spec.md
│   ├── 06_MVP_Roadmap.md
│   └── 07_AI_Features.md
├── app/
├── backend/
├── database/
├── infrastructure/
└── assets/
```

## Next Best Step

Create `01_Product_Vision.md` in English, then create `02_System_Architecture.md`.

The product vision should define:

- What the product is
- Who it is for
- What operational pain it solves
- What the MVP includes
- What the MVP intentionally excludes
- The first core workflow
- The initial entities and screens
