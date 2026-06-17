# Historical Dataset Review Workbook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate a human-reviewable historical dataset workbook from the exported calendar and the place/address workbook.

**Architecture:** Build small focused JavaScript modules: one parser for `.ics`, one importer for the place/address workbook, one transformer for matching and inference, and one workbook builder. The first output is an Excel review workbook under `outputs/historical-dataset-v0.1/`; CSV/JSON export can follow after the review workbook is validated.

**Tech Stack:** Node.js ESM, `node:test`, `@oai/artifact-tool`, local filesystem files.

---

## File Structure

- Create `scripts/historical_dataset/ics_parser.mjs`: parse iCalendar events, unfold lines, decode escaped text, return normalized event objects.
- Create `scripts/historical_dataset/site_matching.mjs`: normalize names, detect job numbers, match calendar events to known sites, infer status and parts state.
- Create `scripts/historical_dataset/workbook_sources.mjs`: read the existing place/address workbook and convert it to site source rows.
- Create `scripts/historical_dataset/build_historical_dataset_review.mjs`: orchestrate parsing, matching, workbook creation, render preview, and export.
- Create `tests/historical_dataset/ics_parser.test.mjs`: tests for line unfolding, text decoding, event extraction, and date parsing.
- Create `tests/historical_dataset/site_matching.test.mjs`: tests for normalization, job number detection, site matching, and conservative manual-review behavior.

## Task 1: ICS Parser

**Files:**
- Create: `tests/historical_dataset/ics_parser.test.mjs`
- Create: `scripts/historical_dataset/ics_parser.mjs`

- [ ] **Step 1: Write failing tests**

```js
import test from "node:test";
import assert from "node:assert/strict";
import {
  decodeIcsText,
  parseIcsDate,
  parseIcsEvents,
  unfoldIcsLines,
} from "../../scripts/historical_dataset/ics_parser.mjs";

test("unfoldIcsLines joins continuation lines", () => {
  const input = "SUMMARY:Gateway\\r\\n description continued\\r\\nLOCATION:Calgary";
  assert.deepEqual(unfoldIcsLines(input), [
    "SUMMARY:Gatewaydescription continued",
    "LOCATION:Calgary",
  ]);
});

test("decodeIcsText handles escaped commas, newlines, and backslashes", () => {
  assert.equal(decodeIcsText("Door\\\\, reader\\\\nNeeds part\\\\\\\\tool"), "Door, reader\nNeeds part\\tool");
});

test("parseIcsDate parses UTC calendar timestamps", () => {
  assert.equal(parseIcsDate("20260520T143000Z").toISOString(), "2026-05-20T14:30:00.000Z");
});

test("parseIcsEvents extracts normalized events", () => {
  const ics = [
    "BEGIN:VCALENDAR",
    "BEGIN:VEVENT",
    "UID:event-1",
    "DTSTART:20260520T143000Z",
    "DTEND:20260520T153000Z",
    "SUMMARY:Rocky ridge Landing",
    "LOCATION:500 Rocky Vista Gardens NW\\\\, Calgary",
    "DESCRIPTION:Need return visit\\\\nWaiting for parts",
    "END:VEVENT",
    "END:VCALENDAR",
  ].join("\\r\\n");

  assert.deepEqual(parseIcsEvents(ics), [
    {
      calendarEventId: "cal_0001",
      uid: "event-1",
      startDateTime: "2026-05-20T14:30:00.000Z",
      endDateTime: "2026-05-20T15:30:00.000Z",
      summary: "Rocky ridge Landing",
      location: "500 Rocky Vista Gardens NW, Calgary",
      description: "Need return visit\nWaiting for parts",
      rawEvent: ics.split("BEGIN:VEVENT")[1].split("END:VEVENT")[0].trim(),
    },
  ]);
});
```

- [ ] **Step 2: Run tests and verify expected failure**

Run: `node --test tests/historical_dataset/ics_parser.test.mjs`

Expected: FAIL because `scripts/historical_dataset/ics_parser.mjs` does not exist.

- [ ] **Step 3: Implement minimal parser**

Create `scripts/historical_dataset/ics_parser.mjs` with exported functions:

- `unfoldIcsLines(text)`
- `decodeIcsText(value)`
- `parseIcsDate(value)`
- `parseIcsEvents(text)`

- [ ] **Step 4: Run tests and verify pass**

Run: `node --test tests/historical_dataset/ics_parser.test.mjs`

Expected: PASS.

## Task 2: Site Matching and Inference

**Files:**
- Create: `tests/historical_dataset/site_matching.test.mjs`
- Create: `scripts/historical_dataset/site_matching.mjs`

- [ ] **Step 1: Write failing tests**

```js
import test from "node:test";
import assert from "node:assert/strict";
import {
  detectJobNumber,
  inferPartsStatus,
  inferVisitStatus,
  matchSite,
  normalizeName,
} from "../../scripts/historical_dataset/site_matching.mjs";

const sites = [
  { siteId: "site_0001", siteName: "Rocky Ridge Landing", address: "500 Rocky Vista Gardens NW" },
  { siteId: "site_0002", siteName: "Copperfield Park 2", address: "755 Copperpond Blvd SE" },
];

test("normalizeName removes punctuation and normalizes case", () => {
  assert.equal(normalizeName(" Rocky-ridge Landing!! "), "rocky ridge landing");
});

test("detectJobNumber finds J numbers", () => {
  assert.equal(detectJobNumber("Copperfield Park 2 J23724"), "J23724");
});

test("matchSite exact-normalized matches known site", () => {
  assert.deepEqual(matchSite({ summary: "rocky ridge landing", location: "", description: "" }, sites), {
    siteId: "site_0001",
    detectedSiteName: "Rocky Ridge Landing",
    matchConfidence: "high",
    needsManualReview: false,
  });
});

test("matchSite marks unknown event for manual review", () => {
  assert.deepEqual(matchSite({ summary: "Unknown Building", location: "", description: "" }, sites), {
    siteId: "",
    detectedSiteName: "Unknown Building",
    matchConfidence: "none",
    needsManualReview: true,
  });
});

test("inferVisitStatus is conservative", () => {
  assert.equal(inferVisitStatus("finished and tested"), "Completed");
  assert.equal(inferVisitStatus("need to come back with reader"), "Need Return Visit");
  assert.equal(inferVisitStatus("unclear note"), "Unknown");
});

test("inferPartsStatus detects parts language", () => {
  assert.equal(inferPartsStatus("waiting for parts from ADI"), "Waiting for Parts");
  assert.equal(inferPartsStatus("need to order new reader"), "Need to Order");
  assert.equal(inferPartsStatus("general service call"), "No Parts Mentioned");
});
```

- [ ] **Step 2: Run tests and verify expected failure**

Run: `node --test tests/historical_dataset/site_matching.test.mjs`

Expected: FAIL because `scripts/historical_dataset/site_matching.mjs` does not exist.

- [ ] **Step 3: Implement minimal matcher and inference helpers**

Create `scripts/historical_dataset/site_matching.mjs` with exported functions matching the tests.

- [ ] **Step 4: Run tests and verify pass**

Run: `node --test tests/historical_dataset/site_matching.test.mjs`

Expected: PASS.

## Task 3: Workbook Builder

**Files:**
- Create: `scripts/historical_dataset/workbook_sources.mjs`
- Create: `scripts/historical_dataset/build_historical_dataset_review.mjs`

- [ ] **Step 1: Implement source workbook reader**

Read `outputs/slack-active-channels-2026-05-31/slack_channel_addresses.xlsx` using `@oai/artifact-tool` import APIs and return site rows.

- [ ] **Step 2: Implement generated records**

Use parsed events and matched sites to create:

- `Sites`
- `Calendar Events`
- `Generated Jobs`
- `Generated Visits`
- `Manual Review`

- [ ] **Step 3: Implement workbook export**

Create `outputs/historical-dataset-v0.1/historical_dataset_review.xlsx` and `outputs/historical-dataset-v0.1/review_preview.png`.

- [ ] **Step 4: Run builder**

Run: `node scripts/historical_dataset/build_historical_dataset_review.mjs`

Expected: workbook and preview files are created.

## Task 4: Verification

**Files:**
- Read generated workbook and preview artifacts.

- [ ] **Step 1: Run all tests**

Run: `node --test tests/historical_dataset/*.test.mjs`

Expected: PASS.

- [ ] **Step 2: Verify output files exist**

Run: `Get-ChildItem outputs/historical-dataset-v0.1`

Expected: includes `historical_dataset_review.xlsx` and `review_preview.png`.

- [ ] **Step 3: Inspect workbook shape**

Use `@oai/artifact-tool` or compact XML inspection to confirm expected sheet names and non-empty tables.

Expected sheets:

- `Sites`
- `Calendar Events`
- `Generated Jobs`
- `Generated Visits`
- `Manual Review`

