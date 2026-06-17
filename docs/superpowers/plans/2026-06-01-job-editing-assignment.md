# Job Editing and Assignment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Flutter MVP usable for manual workflow testing by keeping many jobs open, adding technician assignment, and enabling job text/status editing.

**Architecture:** Extend the repository contract with `updateJob`, keep changes in memory for now, and update the Jobs screen to edit selected job fields. The app still uses local seed data, preserving the future swap to FastAPI/PostgreSQL.

**Tech Stack:** Flutter, Dart, Material 3, local repository state.

---

## File Structure

- Modify `lib/domain/models.dart`: expand `Job.copyWith`.
- Modify `lib/data/field_service_repository.dart`: add `updateJob`.
- Modify `lib/data/mock_field_service_repository.dart`: implement `updateJob`.
- Modify `lib/data/seed_field_service_repository.dart`: implement `updateJob` and ensure at least half jobs are open.
- Modify `lib/features/jobs/jobs_screen.dart`: add search, status filter, assignment dropdown, editable title/description/status/priority.
- Modify tests: prove `updateJob` persists in mock and seed repositories.

## Tasks

1. Write failing repository tests for updating a job assignment/text/status.
2. Extend model and repositories until tests pass.
3. Update Jobs UI to support search/filter/edit/save.
4. Run `flutter test`, `flutter analyze`, `flutter build windows`.
5. Launch the Windows app for manual testing.
