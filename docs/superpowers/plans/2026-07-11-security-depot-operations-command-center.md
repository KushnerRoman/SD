# Security Depot Operations Command Center Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a persistent interactive demo that converts simulated Gmail messages into dispatched service calls, synchronizes them to a simulated technician Google Calendar, and records structured completion reports for managers.

**Architecture:** Extend the existing Flutter repository-driven UI and FastAPI/SQLAlchemy backend. SQLite remains authoritative; simulated mail and calendar provider records are first-class backend resources so production Google adapters can later replace them without changing field-service screens.

**Tech Stack:** Flutter 3 / Dart, Material 3, FastAPI, Pydantic, SQLAlchemy 2, SQLite, pytest, flutter_test.

## Global Constraints

- Demo data must persist across application restarts.
- Live Google OAuth and Google APIs are out of scope.
- Manager and simulated technician experiences must remain visually and behaviorally distinct.
- Service categories are Intercom, Access Control, Cameras/CCTV, Cable Management, and Other.
- Service-call statuses are Unassigned, Scheduled, In Progress, Completed, Incomplete, and Return Required.
- Do not add finance, quoting, invoicing, payroll, inventory, purchasing, or stock features.
- Use Security Depot navy/red branding with accessible text labels in addition to color.

## File Structure

- `backend/app/models.py`: persistent mail, service, visit, activity, notification, site, and technician entities.
- `backend/app/schemas.py`: request/response contracts and dashboard aggregates.
- `backend/app/workflows.py`: transactional email-conversion and technician-report use cases.
- `backend/app/main.py`: thin HTTP endpoints delegating to workflows.
- `backend/app/seed_loader.py`: deterministic mixed-inbox and operational demo dataset.
- `backend/tests/test_workflows.py`: domain workflow and validation tests.
- `backend/tests/test_api.py`: HTTP contract and reset/persistence tests.
- `app/security_depot_fsm/lib/domain/models.dart`: Flutter domain types matching API contracts.
- `app/security_depot_fsm/lib/data/field_service_repository.dart`: manager workflow interface.
- `app/security_depot_fsm/lib/data/api_field_service_repository.dart`: HTTP adapter.
- `app/security_depot_fsm/lib/data/seed_field_service_repository.dart`: offline demo fallback.
- `app/security_depot_fsm/lib/theme/app_theme.dart`: shared Operations Command Center visual tokens.
- `app/security_depot_fsm/lib/widgets/app_shell.dart`: responsive sidebar, top bar, notifications, demo mode switch.
- `app/security_depot_fsm/lib/features/inbox/inbox_screen.dart`: mixed mailbox and message detail.
- `app/security_depot_fsm/lib/features/jobs/jobs_screen.dart`: service-call list/board and detail.
- `app/security_depot_fsm/lib/features/schedule/schedule_screen.dart`: day/week/team dispatch schedule.
- `app/security_depot_fsm/lib/features/history/history_screen.dart`: completed-work archive.
- `app/security_depot_fsm/lib/features/calendar_demo/calendar_demo_screen.dart`: technician calendar and report form.
- `app/security_depot_fsm/lib/features/settings/settings_screen.dart`: simulated connection state and reset.
- `app/security_depot_fsm/lib/features/dashboard/dashboard_screen.dart`: manager summary and actionable attention queues.
- `app/security_depot_fsm/test/manager_workflow_test.dart`: end-to-end widget flow over fake repository.

---

### Task 1: Persistent Operations Domain

**Files:**
- Modify: `backend/app/models.py`
- Modify: `backend/app/schemas.py`
- Modify: `backend/app/database.py`
- Test: `backend/tests/test_workflows.py`

**Interfaces:**
- Produces: `EmailMessage`, `ActivityEntry`, `Notification`; expanded `Site`, `Technician`, `Job`, and `Visit` entities.
- Produces: `EmailMessageOut`, `DispatchCreate`, `TechnicianReportCreate`, `NotificationOut`, and expanded aggregate schemas.

- [ ] **Step 1: Write failing persistence and relationship tests**

Create tests that insert a mixed email, link it to a job, create a visit report, activity entry, and notification, close the session, reopen it, and assert every relationship and value remains present.

```python
def test_operations_records_persist(session_factory):
    with session_factory() as session:
        email = EmailMessage(id="mail-1", sender="client@example.com", subject="Camera offline", body="Lobby camera is down")
        session.add(email)
        session.commit()
    with session_factory() as session:
        assert session.get(EmailMessage, "mail-1").subject == "Camera offline"
```

- [ ] **Step 2: Run the focused test and confirm the missing-model failure**

Run: `backend\.venv\Scripts\pytest.exe backend\tests\test_workflows.py -q`

Expected: collection fails because `EmailMessage` and related schemas do not exist.

- [ ] **Step 3: Add focused SQLAlchemy entities and enums-as-validated strings**

Add fields required by the design, including `Job.category`, `Job.source_email_id`, `Visit.materials_used`, `Visit.follow_up_notes`, technician active/skills/hours/color fields, and site contact/access/system fields. Add unique linkage from an email to its first job and append-only activity rows.

- [ ] **Step 4: Add exact Pydantic contracts**

`DispatchCreate` accepts `email_id`, `site_id`, `title`, `category`, `priority`, `technician_id`, `scheduled_start`, `scheduled_end`, and `instructions`. `TechnicianReportCreate` accepts `status`, `duration_minutes`, `work_performed`, `materials_used`, and `follow_up_notes`.

- [ ] **Step 5: Run tests and commit**

Run: `backend\.venv\Scripts\pytest.exe backend\tests\test_workflows.py -q`

Expected: PASS.

Commit: `git commit -am "feat: add persistent operations domain"`

### Task 2: Transactional Dispatch and Technician Workflows

**Files:**
- Create: `backend/app/workflows.py`
- Modify: `backend/app/main.py`
- Test: `backend/tests/test_workflows.py`
- Test: `backend/tests/test_api.py`

**Interfaces:**
- Consumes: Task 1 entities and schemas.
- Produces: `convert_email_to_service_call(session, payload) -> Job`, `submit_technician_report(session, visit_id, payload) -> Visit`, `find_schedule_conflicts(...) -> list[Visit]`.
- Produces endpoints: `GET /emails`, `GET /emails/{id}`, `POST /dispatch/from-email`, `GET /notifications`, `PATCH /notifications/{id}/read`, `POST /visits/{id}/report`.

- [ ] **Step 1: Write failing workflow tests**

Cover successful conversion, duplicate conversion returning conflict, invalid end-before-start, inactive technician rejection, overlap conflict response, completed report validation, required follow-up for Incomplete/Return Required, atomic activity creation, and manager notification creation.

```python
def test_duplicate_email_conversion_is_rejected(session, dispatch_payload):
    convert_email_to_service_call(session, dispatch_payload)
    with pytest.raises(WorkflowConflict, match="already linked"):
        convert_email_to_service_call(session, dispatch_payload)
```

- [ ] **Step 2: Verify failures**

Run: `backend\.venv\Scripts\pytest.exe backend\tests\test_workflows.py backend\tests\test_api.py -q`

Expected: FAIL for missing workflow functions and routes.

- [ ] **Step 3: Implement validation and transactional use cases**

Use one commit per use case transaction. Create a scheduled visit and simulated calendar ID during dispatch. Report submission updates visit, job status, activity, and notification in the same transaction.

- [ ] **Step 4: Add thin FastAPI endpoints with 404, 409, and 422 mappings**

Return explicit conflict details including overlapping visit identifiers. Keep endpoint functions free of duplicated business validation.

- [ ] **Step 5: Run tests and commit**

Run: `backend\.venv\Scripts\pytest.exe backend\tests -q`

Expected: all backend tests PASS.

Commit: `git commit -am "feat: add dispatch and technician report workflows"`

### Task 3: Deterministic Demo Data and Reset

**Files:**
- Modify: `backend/app/seed_loader.py`
- Modify: `backend/app/main.py`
- Modify: `app/security_depot_fsm/assets/data/seed_data.json`
- Test: `backend/tests/test_seed_loader.py`

**Interfaces:**
- Produces: a stable dataset of six technicians, mixed email, service calls across every category/status, sites, visits, activity, and notifications.
- Produces: `POST /admin/reset-demo` returning entity counts.

- [ ] **Step 1: Write failing reset test**

Create a custom email, call reset, assert it is gone, and assert the known seed email, six technicians, return-required visit, and overdue call exist.

- [ ] **Step 2: Verify failure**

Run: `backend\.venv\Scripts\pytest.exe backend\tests\test_seed_loader.py -q`

Expected: FAIL because new seed collections and reset route are absent.

- [ ] **Step 3: Expand seed loader and JSON fixture**

Use fixed IDs and dates relative to a single seed anchor so the dashboard always contains today/upcoming/overdue examples when loaded.

- [ ] **Step 4: Run tests and commit**

Run: `backend\.venv\Scripts\pytest.exe backend\tests -q`

Expected: PASS.

Commit: `git commit -am "feat: add resettable operations demo data"`

### Task 4: Flutter Domain and Repository Contract

**Files:**
- Modify: `app/security_depot_fsm/lib/domain/models.dart`
- Modify: `app/security_depot_fsm/lib/data/field_service_repository.dart`
- Modify: `app/security_depot_fsm/lib/data/api_field_service_repository.dart`
- Modify: `app/security_depot_fsm/lib/data/seed_field_service_repository.dart`
- Modify: `app/security_depot_fsm/lib/data/mock_field_service_repository.dart`
- Test: `app/security_depot_fsm/test/domain_models_test.dart`
- Test: `app/security_depot_fsm/test/api_repository_test.dart`
- Test: `app/security_depot_fsm/test/repository_test.dart`

**Interfaces:**
- Produces Flutter `EmailMessage`, `ServiceCategory`, `ActivityEntry`, `ManagerNotification`, expanded `Job`, `Visit`, `Site`, and `Technician`.
- Produces repository methods `getEmails`, `getEmail`, `dispatchFromEmail`, `getNotifications`, `markNotificationRead`, `submitTechnicianReport`, `getHistory`, and `resetDemoData`.

- [ ] **Step 1: Write failing JSON and repository tests**

Assert every API field maps to a typed Dart model, status/category labels are exact, and dispatch/report requests use the backend contract.

- [ ] **Step 2: Verify failure**

Run: `flutter test test/domain_models_test.dart test/api_repository_test.dart test/repository_test.dart`

Expected: compile failure for missing models and methods.

- [ ] **Step 3: Implement immutable models and repository methods**

Keep parsing helpers private to the API repository. Preserve the offline seed adapter for startup fallback while matching persistent workflow behavior in memory.

- [ ] **Step 4: Run tests and commit**

Run: `flutter test test/domain_models_test.dart test/api_repository_test.dart test/repository_test.dart`

Expected: PASS.

Commit: `git commit -am "feat: expose operations workflows to Flutter"`

### Task 5: Operations Command Center Shell and Dashboard

**Files:**
- Create: `app/security_depot_fsm/lib/theme/app_theme.dart`
- Create: `app/security_depot_fsm/lib/widgets/app_shell.dart`
- Modify: `app/security_depot_fsm/lib/main.dart`
- Rewrite: `app/security_depot_fsm/lib/features/dashboard/dashboard_screen.dart`
- Test: `app/security_depot_fsm/test/widget_test.dart`

**Interfaces:**
- Consumes: Task 4 repository and aggregates.
- Produces: responsive named destinations for Dashboard, Inbox, Service Calls, Schedule, Sites, Technicians, History, Calendar Demo, and Settings.

- [ ] **Step 1: Write failing navigation and dashboard widget tests**

Verify navy sidebar, Security Depot branding, red primary action, notification badge, actionable status cards, narrow-width navigation, and filtered destination callbacks.

- [ ] **Step 2: Verify failure**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because the new destinations and dashboard content are missing.

- [ ] **Step 3: Implement visual tokens, shell, and dashboard**

Use `Color(0xFF101B2D)` navy, `Color(0xFFE31B23)` red, cool-gray scaffold, 8–12px radii, labeled status chips, and responsive rail/drawer behavior.

- [ ] **Step 4: Run tests and commit**

Run: `flutter test test/widget_test.dart`

Expected: PASS.

Commit: `git commit -am "feat: redesign operations command center shell"`

### Task 6: Manager Inbox, Dispatch, Service Calls, and History

**Files:**
- Create: `app/security_depot_fsm/lib/features/inbox/inbox_screen.dart`
- Create: `app/security_depot_fsm/lib/features/inbox/dispatch_dialog.dart`
- Rewrite: `app/security_depot_fsm/lib/features/jobs/jobs_screen.dart`
- Create: `app/security_depot_fsm/lib/features/history/history_screen.dart`
- Modify: `app/security_depot_fsm/lib/features/sites/sites_screen.dart`
- Modify: `app/security_depot_fsm/lib/features/technicians/technicians_screen.dart`
- Test: `app/security_depot_fsm/test/manager_workflow_test.dart`

**Interfaces:**
- Consumes: Task 4 repository and Task 5 shell navigation.
- Produces: mixed inbox conversion UI, list/board service-call views, record timeline, searchable history, site service history, technician workload summary.

- [ ] **Step 1: Write failing manager flow widget test**

Open a service-request email among normal email, convert it with required fields, assert linked state, open the created call, switch list/board, and find it through History after fake completion.

- [ ] **Step 2: Verify failure**

Run: `flutter test test/manager_workflow_test.dart`

Expected: FAIL because inbox, dispatch, and history screens are absent.

- [ ] **Step 3: Implement inbox master/detail and dispatch form**

Keep entered form values after repository errors. Display duplicate linkage and conflict warnings inline with explicit confirmation controls.

- [ ] **Step 4: Implement service-call list/board, detail timeline, and history filters**

Keep filters composable and status labels accessible. Extend site and technician detail panels with upcoming work and historical summaries.

- [ ] **Step 5: Run tests and commit**

Run: `flutter test test/manager_workflow_test.dart`

Expected: PASS.

Commit: `git commit -am "feat: add manager dispatch and history workflow"`

### Task 7: Schedule and Simulated Google Calendar Technician View

**Files:**
- Rewrite: `app/security_depot_fsm/lib/features/schedule/schedule_screen.dart`
- Create: `app/security_depot_fsm/lib/features/calendar_demo/calendar_demo_screen.dart`
- Create: `app/security_depot_fsm/lib/features/calendar_demo/technician_report_dialog.dart`
- Test: `app/security_depot_fsm/test/calendar_demo_test.dart`

**Interfaces:**
- Consumes: repository dispatch/report methods.
- Produces: day/week/team schedule, conflict warnings, technician switcher, calendar events, structured report submission.

- [ ] **Step 1: Write failing schedule and report widget tests**

Verify team grouping, event visibility for only the selected technician, required time/work notes, required follow-up for incomplete statuses, successful report, and manager notification refresh.

- [ ] **Step 2: Verify failure**

Run: `flutter test test/calendar_demo_test.dart`

Expected: FAIL because calendar demo widgets do not exist.

- [ ] **Step 3: Implement dispatch schedule and technician calendar**

Use familiar calendar grid behavior without reproducing Google's branding. Event details are read-only except for the structured report action.

- [ ] **Step 4: Implement report dialog and refresh propagation**

On success show a confirmation, refresh dashboard/history/notifications through the shared shell refresh signal, and keep failures editable.

- [ ] **Step 5: Run tests and commit**

Run: `flutter test test/calendar_demo_test.dart`

Expected: PASS.

Commit: `git commit -am "feat: add simulated technician calendar workflow"`

### Task 8: Settings, Reset, Error States, and End-to-End Verification

**Files:**
- Create: `app/security_depot_fsm/lib/features/settings/settings_screen.dart`
- Modify: all data-driven screens touched above for loading/empty/error/retry states.
- Modify: `app/security_depot_fsm/README.md`
- Test: `app/security_depot_fsm/test/manager_workflow_test.dart`
- Test: `backend/tests/test_api.py`

**Interfaces:**
- Consumes: reset and health endpoints.
- Produces: confirmed reset, simulated provider status, complete run instructions.

- [ ] **Step 1: Write failing reset and retry tests**

Verify reset requires confirmation, restores seed counts, and reloads screens. Verify a failed repository request displays retained content plus retry rather than a blank screen.

- [ ] **Step 2: Implement Settings and consistent state views**

Display Gmail Demo and Calendar Demo as connected simulations. Put Reset Demo Data behind a destructive confirmation dialog with a clear description.

- [ ] **Step 3: Document exact startup and walkthrough commands**

Document backend virtual-environment startup, seed/reset, Flutter web build, combined server URL, and the five-step demo walkthrough.

- [ ] **Step 4: Run complete verification**

Run: `backend\.venv\Scripts\pytest.exe backend\tests -q`

Run: `flutter analyze`

Run: `flutter test`

Run: `flutter build web`

Expected: all tests PASS, analysis reports no issues, and the web build succeeds.

- [ ] **Step 5: Verify in browser and across restart**

Start FastAPI, load the combined web app, complete email → dispatch → calendar → technician report → manager history, restart FastAPI, and confirm the completed record remains. Repeat at desktop and narrow responsive widths.

- [ ] **Step 6: Commit**

Commit: `git commit -am "test: verify operations command center demo"`
