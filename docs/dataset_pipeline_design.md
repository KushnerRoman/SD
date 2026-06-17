# Historical Dataset Pipeline Design

## Purpose

Build a local historical dataset for the Security Depot field service management system without connecting to email, Google Calendar, Microsoft 365, or Slack APIs yet.

The first dataset will be generated from:

- The exported technician calendar `.ics` file
- The existing place/address workbook created from Slack channel metadata
- Manual review fields for incomplete or uncertain records

This dataset will let us design and test the system using realistic historical work patterns before building live integrations.

## Source Files

### Calendar Source

`docs/Roman Kushner_ray.secdep@gmail.com.ics`

Known characteristics:

- Format: iCalendar / `.ics`
- Contains approximately 180 events
- Many events include free-text descriptions
- Some events include location fields
- Event summaries often contain site names and sometimes job numbers

### Place / Address Source

`outputs/slack-active-channels-2026-05-31/slack_channel_addresses.xlsx`

Known columns:

- `Place Name`
- `Channel Name`
- `Extracted Address`
- `Source`

This file is the best available source for normalized site names and addresses.

## Recommended Workflow

The pipeline should run in two phases.

### Phase 1: Human Review Workbook

Generate an Excel workbook that shows what the system extracted and inferred.

This is the first deliverable because the calendar data is real but messy. The review workbook lets a human correct names, addresses, statuses, and job grouping before any generated data becomes backend seed data.

### Phase 2: Backend Seed Data

After manual review, export clean seed data files:

- `sites.csv`
- `jobs.csv`
- `visits.csv`
- `parts.csv` if enough reliable information exists
- `seed_data.json` for backend import

## Review Workbook Structure

### Sheet: Sites

One row per known or inferred site.

Recommended columns:

- `site_id`
- `site_name`
- `normalized_site_name`
- `address`
- `slack_channel`
- `address_source`
- `matched_from_calendar_count`
- `needs_manual_review`
- `manual_notes`

### Sheet: Calendar Events

One row per raw calendar event.

Recommended columns:

- `calendar_event_id`
- `uid`
- `start_datetime`
- `end_datetime`
- `summary`
- `location`
- `description`
- `detected_site_name`
- `detected_job_number`
- `matched_site_id`
- `match_confidence`
- `needs_manual_review`

### Sheet: Generated Jobs

One row per inferred job.

Recommended columns:

- `job_id`
- `site_id`
- `site_name`
- `job_number`
- `job_title`
- `job_type`
- `priority`
- `status`
- `first_seen_date`
- `last_seen_date`
- `source_calendar_event_ids`
- `needs_parts`
- `needs_return_visit`
- `needs_manager_review`
- `confidence`
- `manual_notes`

### Sheet: Generated Visits

One row per technician visit.

Recommended columns:

- `visit_id`
- `job_id`
- `site_id`
- `technician_name`
- `start_datetime`
- `end_datetime`
- `duration_minutes`
- `visit_status`
- `work_summary`
- `parts_status`
- `parts_source`
- `source_calendar_event_id`
- `needs_manual_review`

### Sheet: Manual Review

One row per issue that needs human cleanup.

Recommended columns:

- `review_id`
- `record_type`
- `record_id`
- `issue_type`
- `issue_description`
- `suggested_fix`
- `manual_resolution`
- `resolved`

## Matching Strategy

Match calendar events to sites using a conservative sequence:

1. Exact match between calendar summary and known place name
2. Case-insensitive normalized match
3. Partial match between calendar summary and place name
4. Address match from calendar `LOCATION`
5. Fuzzy text match only when the score is high enough
6. Otherwise mark as `needs_manual_review`

The pipeline should not silently create confident data from weak matches.

## Job Grouping Strategy

Calendar events should become jobs using these rules:

1. If a job number like `J23724` exists, group events by job number.
2. If no job number exists, group by site and similar work text within a reasonable time window.
3. If the text is ambiguous, create a separate job and mark it for manual review.

The first version should prefer creating too many reviewable jobs over incorrectly merging unrelated work.

## Status Inference

Infer status from free text where possible.

Initial statuses:

- `New`
- `Scheduled`
- `In Progress`
- `Completed`
- `Need Return Visit`
- `Waiting for Parts`
- `Could Not Access Site`
- `Need Manager Review`
- `Unknown`

If no reliable status can be inferred, use `Unknown` and set `needs_manual_review = true`.

## Parts Inference

Detect parts-related language from event descriptions.

Initial parts states:

- `No Parts Mentioned`
- `Parts Used`
- `Parts Needed`
- `Waiting for Parts`
- `Parts Picked Up`
- `Need to Order`
- `Unknown`

Parts extraction should be conservative. Unknown or ambiguous text should go to manual review.

## Output Folder

Generated files should be written under:

`outputs/historical-dataset-v0.1/`

Expected files:

- `historical_dataset_review.xlsx`
- `sites.csv`
- `jobs.csv`
- `visits.csv`
- `manual_review.csv`
- `seed_data.json`

The CSV and JSON files should be generated only after the review workbook exists.

## Design Principles

- Preserve raw source text.
- Keep every generated record traceable to source calendar event IDs.
- Prefer manual review over false certainty.
- Use stable IDs for generated records.
- Do not require live external integrations for the first dataset.
- Keep generated statuses and field names in English.

## First Implementation Step

Build a parser that reads:

- The `.ics` calendar file
- The place/address workbook

Then generate the first `historical_dataset_review.xlsx` with raw events, normalized sites, inferred jobs, inferred visits, and manual review rows.
