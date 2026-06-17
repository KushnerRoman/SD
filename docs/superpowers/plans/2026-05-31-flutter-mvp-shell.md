# Flutter MVP Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first usable Flutter shell for the Security Depot FSM app, targeting Windows and Android with temporary local data.

**Architecture:** Scaffold a Flutter app in `app/security_depot_fsm`. The app uses domain models plus a repository interface so screens consume `FieldServiceRepository` instead of knowing whether data comes from local mock data or a future FastAPI backend.

**Tech Stack:** Flutter 3.22.2, Dart 3.4.3, Material 3, local in-memory mock repository.

---

## File Structure

- Create `app/security_depot_fsm/` using `flutter create`.
- Replace `lib/main.dart` with a production-like app shell.
- Create `lib/domain/models.dart` for `Site`, `Job`, `Visit`, `Technician`, and enum helpers.
- Create `lib/data/field_service_repository.dart` for the repository contract.
- Create `lib/data/mock_field_service_repository.dart` for temporary local data.
- Create `lib/features/dashboard/dashboard_screen.dart` for manager dashboard.
- Create `lib/features/jobs/jobs_screen.dart` for job list/detail shell.
- Create `lib/features/sites/sites_screen.dart` for site list/history shell.
- Create `lib/features/visits/visit_update_screen.dart` for technician update form.
- Create `test/domain_models_test.dart` and `test/repository_test.dart`.

## Task 1: Scaffold Flutter App

**Files:**
- Create: `app/security_depot_fsm/`

- [ ] Run `flutter create --platforms=windows,android --project-name security_depot_fsm app/security_depot_fsm`
- [ ] Run `flutter test` inside `app/security_depot_fsm` and verify the starter test passes.

## Task 2: Domain Models With Tests

**Files:**
- Create: `app/security_depot_fsm/test/domain_models_test.dart`
- Create: `app/security_depot_fsm/lib/domain/models.dart`

- [ ] Write tests proving job status labels and open/follow-up classification.
- [ ] Run `flutter test test/domain_models_test.dart` and verify failure because models do not exist.
- [ ] Implement `models.dart`.
- [ ] Run `flutter test test/domain_models_test.dart` and verify pass.

## Task 3: Repository With Mock Data

**Files:**
- Create: `app/security_depot_fsm/test/repository_test.dart`
- Create: `app/security_depot_fsm/lib/data/field_service_repository.dart`
- Create: `app/security_depot_fsm/lib/data/mock_field_service_repository.dart`

- [ ] Write tests proving the repository returns dashboard data, jobs, sites, visits, and can save a visit update.
- [ ] Run `flutter test test/repository_test.dart` and verify failure because repository files do not exist.
- [ ] Implement repository contract and mock repository.
- [ ] Run `flutter test test/repository_test.dart` and verify pass.

## Task 4: App Shell UI

**Files:**
- Modify: `app/security_depot_fsm/lib/main.dart`
- Create: dashboard/jobs/sites/visits feature screen files.

- [ ] Replace starter counter app with a responsive Material shell.
- [ ] Add left navigation on desktop and bottom navigation on narrow layouts.
- [ ] Add Dashboard, Jobs, Sites, and Visit Update screens.
- [ ] Wire screens to `MockFieldServiceRepository`.
- [ ] Run `flutter test`.
- [ ] Run `flutter analyze`.

## Task 5: Launch Verification

**Files:**
- Read generated app.

- [ ] Run `flutter run -d windows` or `flutter build windows` depending on local environment.
- [ ] If Windows runtime build is unavailable, use `flutter test` and `flutter analyze` as verification and report the blocker.
