# Security Depot FSM - MVP v0.1 QA Test Plan

## Document Control

| Field | Value |
|---|---|
| Product | Security Depot Field Service Management |
| Version Under Test | MVP v0.1 |
| Document Type | QA Test Plan |
| Prepared For | Manual QA Validation |
| Prepared Date | June 1, 2026 |
| Test Environment | Web application via Tailscale, Windows desktop build, mock MySQL-backed API |

## 1. Purpose

This document defines the manual QA test plan for the Security Depot FSM MVP v0.1 system. The purpose of this QA cycle is to verify that the application can support a basic end-to-end field service workflow using the currently available imported calendar and site data.

The test should confirm that a manager can review historical jobs, edit operational data, assign work to technicians, create or update visits, update visit outcomes, and verify that the technician and dashboard views reflect those changes.

## 2. Scope

### In Scope

- Web application access through Tailscale.
- Windows desktop application smoke test.
- Dashboard summary validation.
- Job list review, filtering, selection, and editing.
- Editing existing jobs, including jobs marked as Completed.
- Manual job creation.
- Site list review, creation, and editing.
- Technician list review, creation, editing, and assigned work visibility.
- Visit list review, visit selection, technician reassignment, schedule editing, status editing, work notes, and parts status.
- End-to-end flow from Job assignment to Visit update.
- API-backed persistence during the active test environment session.

### Out of Scope

- Real email integration.
- Real Google Calendar integration.
- Real production database API integration.
- Android build validation.
- Authentication, permissions, and user roles.
- Push notifications.
- File/photo upload workflows.
- Offline synchronization.
- Production security testing.

## 3. Test Environment

### Primary Web URL

Use the following URL while connected to the same Tailscale network:

`http://administrator.tail3f593b.ts.net/web/`

### Health Check URL

`http://administrator.tail3f593b.ts.net/health`

Expected response:

```json
{"status":"ok"}
```

### Expected Seed Data Baseline

The exact counts may change after manual test edits, but the environment should initially contain approximately:

| Entity | Expected Count |
|---|---:|
| Jobs | 115+ |
| Sites | 130+ |
| Visits | 180 |
| Technicians | 4+ |

At least half of the jobs should remain open for assignment and scheduling tests.

## 4. QA Tester Prerequisites

Before beginning testing, confirm:

- The tester can access the web application URL.
- The application loads without a blank screen.
- The Dashboard appears as the initial screen.
- The navigation includes Dashboard, Jobs, Sites, Technicians, Visits, and related operational sections.
- The health endpoint returns `status: ok`.

If the application does not load, record the browser, device, URL, and exact error message.

## 5. Testing Guidelines

- Use realistic field service data when creating or editing records.
- Do not delete or overwrite large groups of records.
- When creating test records, use a clear prefix such as `QA Test`.
- Record every defect with steps to reproduce, expected result, actual result, screenshot if possible, and severity.
- After each save action, navigate away and back to confirm the saved data is still visible.
- Test both open jobs and completed historical jobs.

## 6. Severity Definitions

| Severity | Definition |
|---|---|
| Critical | Blocks the main workflow or prevents the app from loading. |
| High | Prevents creating, editing, assigning, or updating operational records. |
| Medium | Workflow works, but data is incorrect, confusing, or partially missing. |
| Low | Visual issue, typo, alignment issue, or usability improvement. |

## 7. Test Cases

### TC-001: Application Loads Successfully

**Objective:** Verify that the web application loads through Tailscale.

**Steps:**

1. Open `http://administrator.tail3f593b.ts.net/web/`.
2. Wait for the application to finish loading.
3. Confirm that the Dashboard is visible.
4. Navigate to Jobs, Sites, Technicians, and Visits.

**Expected Result:**

- The application loads without an error page.
- No blank screen appears.
- All main navigation items are accessible.

### TC-002: Health Endpoint Validation

**Objective:** Verify that the backend API is running.

**Steps:**

1. Open `http://administrator.tail3f593b.ts.net/health`.

**Expected Result:**

- The response shows `{"status":"ok"}`.

### TC-003: Dashboard Summary Review

**Objective:** Confirm that dashboard counters display operational job data.

**Steps:**

1. Open the Dashboard.
2. Review job status counters.
3. Review today schedule and status sections if visible.

**Expected Result:**

- Dashboard counters are visible.
- Counts are not all zero.
- The dashboard does not display loading or seed data errors.

### TC-004: Jobs List Loads Historical Data

**Objective:** Confirm that imported jobs are available for review.

**Steps:**

1. Open Jobs.
2. Review the job list.
3. Use search to find a known site or keyword.
4. Use the status filter.

**Expected Result:**

- Jobs are listed.
- Search narrows the list correctly.
- Status filtering works.
- Job cards show title, site, address, and status.

### TC-005: Edit Existing Open Job

**Objective:** Verify editing an existing open job.

**Steps:**

1. Open Jobs.
2. Select any open job.
3. Change the job title to include `QA Edit`.
4. Change the job notes.
5. Change priority.
6. Change assigned technician.
7. Change date, start time, and end time.
8. Click Save Changes.
9. Navigate away and return to the same job.

**Expected Result:**

- The job saves successfully.
- Updated title, notes, priority, technician, date, and time remain visible.
- No error is shown.

### TC-006: Edit Existing Completed Job

**Objective:** Verify that completed historical jobs can still be edited.

**Steps:**

1. Open Jobs.
2. Filter or locate a job with status `Completed`.
3. Select the completed job.
4. Change title, notes, priority, assigned technician, and status.
5. Click Save Changes.
6. Navigate away and return to the job.

**Expected Result:**

- The completed job can be selected.
- The editor is available.
- The completed job can be saved.
- Updated values remain visible after navigation.

### TC-007: Create Manual Job

**Objective:** Verify manual job creation.

**Steps:**

1. Open Jobs.
2. Click New Job.
3. Select the new job.
4. Change title to `QA Test Manual Job`.
5. Select a site.
6. Select a technician.
7. Set date and time.
8. Click Save Changes.

**Expected Result:**

- A new job is created.
- The job appears in the job list.
- The job can be edited after creation.

### TC-008: Assign and Send Job

**Objective:** Verify that assigning a job creates or updates a linked visit.

**Steps:**

1. Open Jobs.
2. Select an open job.
3. Set technician, date, start time, and end time.
4. Click Assign & Send.
5. Open Visits.
6. Locate the visit related to the selected job.

**Expected Result:**

- The job status changes to Scheduled or an active status.
- A visit is visible in the Visits screen.
- The visit shows the selected technician and schedule.

### TC-009: Sites List and Site Editing

**Objective:** Verify site management.

**Steps:**

1. Open Sites.
2. Select an existing site.
3. Edit site name, address, Slack channel, and notes if available.
4. Save.
5. Navigate away and return.

**Expected Result:**

- Site details can be edited.
- Updated values persist.
- Jobs linked to the site remain accessible.

### TC-010: Create Manual Site

**Objective:** Verify manual site creation.

**Steps:**

1. Open Sites.
2. Click New Site.
3. Enter a name such as `QA Test Site`.
4. Enter an address.
5. Enter a Slack channel value if needed.
6. Save.

**Expected Result:**

- The new site appears in the Sites list.
- The site can be selected and edited.
- The new site is available when editing or creating jobs.

### TC-011: Technicians List and Editing

**Objective:** Verify technician management.

**Steps:**

1. Open Technicians.
2. Select an existing technician.
3. Edit name, email, or initials.
4. Save.
5. Navigate away and return.

**Expected Result:**

- Technician details save correctly.
- Assigned jobs and recent visits remain visible.

### TC-012: Create Technician

**Objective:** Verify technician creation.

**Steps:**

1. Open Technicians.
2. Click Add Technician.
3. Enter name `QA Test Technician`.
4. Enter email and initials.
5. Save.
6. Open Jobs and assign a job to this technician.

**Expected Result:**

- New technician is created.
- New technician appears in assignment dropdowns.
- Assigned work appears under the technician.

### TC-013: Technician Schedule Visibility

**Objective:** Verify that technician work is visible from the technician screen.

**Steps:**

1. Open Technicians.
2. Select a technician with assigned jobs or visits.
3. Review assigned work.
4. Review recent visits or schedule-style visit entries.

**Expected Result:**

- The screen shows assigned jobs.
- The screen shows visits with time, job, site, and status details where available.

### TC-014: Visit List and Selection

**Objective:** Verify that visits can be browsed and selected.

**Steps:**

1. Open Visits.
2. Review the visit list.
3. Select multiple visits one by one.

**Expected Result:**

- Visits are listed.
- Selecting a visit loads its details in the editor.
- The editor updates when a different visit is selected.

### TC-015: Edit Visit Work Outcome

**Objective:** Verify technician visit update workflow.

**Steps:**

1. Open Visits.
2. Select a visit.
3. Change status.
4. Enter work notes.
5. Change parts status.
6. Save.
7. Navigate to Jobs and locate the related job.

**Expected Result:**

- Visit changes save successfully.
- Work notes remain visible.
- Related job status updates according to the visit outcome.

### TC-016: Reassign Visit Technician and Schedule

**Objective:** Verify visit reassignment and schedule editing.

**Steps:**

1. Open Visits.
2. Select a visit.
3. Change technician.
4. Change date, start time, and end time.
5. Save.
6. Open Technicians.
7. Select the new technician.

**Expected Result:**

- Visit technician and schedule are updated.
- Visit appears under the new technician.
- Related job reflects the new technician and schedule.

### TC-017: End-to-End Manager Workflow

**Objective:** Verify the main MVP workflow from job review to technician update.

**Steps:**

1. Open Jobs.
2. Create or select a job.
3. Edit title, site, notes, priority, technician, date, and time.
4. Click Assign & Send.
5. Open Visits.
6. Select the linked visit.
7. Update status, work notes, parts status, technician, and schedule.
8. Open Technicians.
9. Confirm the technician shows the work.
10. Open Dashboard.
11. Review updated counters.

**Expected Result:**

- The workflow can be completed without backend or UI errors.
- Data remains visible after navigating between screens.
- Job, Visit, Technician, and Dashboard views stay consistent.

### TC-018: Responsive Layout Smoke Test

**Objective:** Verify that the app remains usable at different browser widths.

**Steps:**

1. Open the web app on a desktop browser.
2. Test at full width.
3. Reduce browser width to a narrow layout.
4. Open Jobs and select a job.
5. Confirm the editor is still accessible.

**Expected Result:**

- Layout does not hide critical controls.
- Jobs can be selected and edited in narrow layout.
- Buttons and text do not overlap.

### TC-019: Save Persistence Check

**Objective:** Verify that saved data remains after navigation.

**Steps:**

1. Edit a job, site, technician, or visit.
2. Navigate to another screen.
3. Return to the edited record.
4. Refresh the browser.
5. Check the edited record again.

**Expected Result:**

- Saved changes remain visible after navigation.
- Saved changes remain visible after browser refresh while the API/database session is active.

### TC-020: Error Handling Observation

**Objective:** Identify any user-facing errors during normal usage.

**Steps:**

1. Use the system normally for at least 15 minutes.
2. Edit several jobs, visits, sites, and technicians.
3. Record any loading errors, save failures, blank screens, or unexpected resets.

**Expected Result:**

- No critical errors occur.
- If errors occur, they provide enough information to report and reproduce the issue.

## 8. Bug Report Template

Use the following format for each defect:

```text
Title:
Severity:
Area: Dashboard / Jobs / Sites / Technicians / Visits / API / Layout
Environment: Web / Windows
URL or Screen:

Steps to Reproduce:
1.
2.
3.

Expected Result:

Actual Result:

Screenshot or Video:

Additional Notes:
```

## 9. QA Exit Criteria

The MVP v0.1 build is acceptable for the next development iteration when:

- The app loads reliably through Tailscale.
- Jobs, Sites, Technicians, and Visits can be opened and reviewed.
- Existing jobs, including Completed jobs, can be edited.
- Manual jobs and sites can be created.
- Jobs can be assigned to technicians.
- Assign & Send creates or updates a visit.
- Visits can be updated with technician, schedule, status, work notes, and parts status.
- Technician screens show assigned work and visit activity.
- No Critical or High severity defects remain unresolved.

## 10. Known Limitations

- Data is currently based on imported historical calendar/site records and mock operational workflows.
- Email ingestion is not connected yet.
- Google Calendar event creation is not connected yet.
- Production authentication is not implemented.
- Android packaging is not validated yet.
- Some imported historical records may require manual cleanup due to source data quality.

## 11. Recommended QA Focus

The highest priority for this QA cycle is to validate whether the system is usable as a manager workflow tool:

1. Can a manager find and understand historical jobs?
2. Can a manager correct imported job/site data?
3. Can a manager assign real work to a technician?
4. Can a visit be updated after the technician completes work?
5. Do job status, visit status, and technician workload remain consistent?

Any issue that breaks this flow should be treated as High severity or Critical severity depending on whether a workaround exists.
