import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";
import { parseIcsEvents } from "./ics_parser.mjs";
import {
  detectJobNumber,
  inferPartsStatus,
  inferVisitStatus,
  matchSite,
  normalizeName,
} from "./site_matching.mjs";
import { readSiteSourceRows } from "./workbook_sources.mjs";

const docsDir = path.join(process.cwd(), "docs");
const outputDir = path.join(process.cwd(), "outputs", "historical-dataset-v0.1");
const calendarPath = path.join(docsDir, "Roman Kushner_ray.secdep@gmail.com.ics");
const siteWorkbookPath = path.join(
  process.cwd(),
  "outputs",
  "slack-active-channels-2026-05-31",
  "slack_channel_addresses.xlsx",
);

const outputWorkbookPath = path.join(outputDir, "historical_dataset_review.xlsx");
const previewPath = path.join(outputDir, "review_preview.png");

function minutesBetween(startIso, endIso) {
  if (!startIso || !endIso) {
    return "";
  }
  const minutes = Math.round((new Date(endIso).getTime() - new Date(startIso).getTime()) / 60000);
  return Number.isFinite(minutes) && minutes >= 0 ? minutes : "";
}

function toDateOnly(iso) {
  return iso ? iso.slice(0, 10) : "";
}

function buildSites(sourceSites, eventMatches) {
  const sites = sourceSites.map((site) => ({
    ...site,
    matchedFromCalendarCount: eventMatches.filter((match) => match.siteId === site.siteId).length,
    needsManualReview: site.address ? false : true,
    manualNotes: site.address ? "" : "Missing address in source workbook",
  }));

  const unmatchedNames = new Map();
  for (const match of eventMatches) {
    if (match.siteId || !match.detectedSiteName) {
      continue;
    }
    const normalized = normalizeName(match.detectedSiteName);
    if (!normalized || unmatchedNames.has(normalized)) {
      continue;
    }
    unmatchedNames.set(normalized, match.detectedSiteName);
  }

  for (const [normalized, siteName] of unmatchedNames) {
    sites.push({
      siteId: `site_${String(sites.length + 1).padStart(4, "0")}`,
      siteName,
      normalizedSiteName: normalized,
      address: "",
      slackChannel: "",
      addressSource: "Inferred from calendar summary",
      source: "calendar_inferred",
      matchedFromCalendarCount: eventMatches.filter((match) => normalizeName(match.detectedSiteName) === normalized).length,
      needsManualReview: true,
      manualNotes: "Inferred site. Confirm name and address.",
    });
  }

  return sites;
}

function buildEventRows(events, sourceSites) {
  return events.map((event) => {
    const matched = matchSite(event, sourceSites);
    const text = `${event.summary}\n${event.location}\n${event.description}`;
    return {
      ...event,
      detectedSiteName: matched.detectedSiteName,
      detectedJobNumber: detectJobNumber(`${event.summary} ${event.description}`),
      matchedSiteId: matched.siteId,
      matchConfidence: matched.matchConfidence,
      needsManualReview: matched.needsManualReview,
      inferredVisitStatus: inferVisitStatus(text),
      inferredPartsStatus: inferPartsStatus(text),
    };
  });
}

function buildJobs(eventRows) {
  const jobsByKey = new Map();

  for (const event of eventRows) {
    const jobKey = event.detectedJobNumber || `${event.matchedSiteId || "unknown"}:${normalizeName(event.summary)}`;
    if (!jobsByKey.has(jobKey)) {
      jobsByKey.set(jobKey, {
        jobId: `job_${String(jobsByKey.size + 1).padStart(4, "0")}`,
        siteId: event.matchedSiteId,
        siteName: event.detectedSiteName,
        jobNumber: event.detectedJobNumber,
        jobTitle: event.summary,
        jobType: "Unknown",
        priority: "Normal",
        status: event.inferredVisitStatus === "Unknown" ? "Scheduled" : event.inferredVisitStatus,
        firstSeenDate: toDateOnly(event.startDateTime),
        lastSeenDate: toDateOnly(event.startDateTime),
        sourceCalendarEventIds: [event.calendarEventId],
        needsParts: ["Parts Needed", "Waiting for Parts", "Need to Order"].includes(event.inferredPartsStatus),
        needsReturnVisit: event.inferredVisitStatus === "Need Return Visit",
        needsManagerReview: event.needsManualReview || event.inferredVisitStatus === "Unknown",
        confidence: event.matchConfidence === "high" ? "medium" : "low",
        manualNotes: "",
      });
      continue;
    }

    const job = jobsByKey.get(jobKey);
    job.sourceCalendarEventIds.push(event.calendarEventId);
    if (event.startDateTime && (!job.firstSeenDate || toDateOnly(event.startDateTime) < job.firstSeenDate)) {
      job.firstSeenDate = toDateOnly(event.startDateTime);
    }
    if (event.startDateTime && toDateOnly(event.startDateTime) > job.lastSeenDate) {
      job.lastSeenDate = toDateOnly(event.startDateTime);
    }
    job.needsParts ||= ["Parts Needed", "Waiting for Parts", "Need to Order"].includes(event.inferredPartsStatus);
    job.needsReturnVisit ||= event.inferredVisitStatus === "Need Return Visit";
    job.needsManagerReview ||= event.needsManualReview || event.inferredVisitStatus === "Unknown";
  }

  return [...jobsByKey.values()].map((job) => ({
    ...job,
    sourceCalendarEventIds: job.sourceCalendarEventIds.join(", "),
  }));
}

function buildVisits(eventRows, jobs) {
  const jobsByEventId = new Map();
  for (const job of jobs) {
    for (const eventId of job.sourceCalendarEventIds.split(",").map((value) => value.trim()).filter(Boolean)) {
      jobsByEventId.set(eventId, job);
    }
  }

  return eventRows.map((event, index) => {
    const job = jobsByEventId.get(event.calendarEventId);
    return {
      visitId: `visit_${String(index + 1).padStart(4, "0")}`,
      jobId: job?.jobId ?? "",
      siteId: event.matchedSiteId,
      technicianName: "Roman Kushner",
      startDateTime: event.startDateTime,
      endDateTime: event.endDateTime,
      durationMinutes: minutesBetween(event.startDateTime, event.endDateTime),
      visitStatus: event.inferredVisitStatus,
      workSummary: event.description,
      partsStatus: event.inferredPartsStatus,
      partsSource: "",
      sourceCalendarEventId: event.calendarEventId,
      needsManualReview: event.needsManualReview || event.inferredVisitStatus === "Unknown",
    };
  });
}

function buildManualReviewRows(sites, eventRows, jobs, visits) {
  const rows = [];
  const addReview = (recordType, recordId, issueType, issueDescription, suggestedFix) => {
    rows.push({
      reviewId: `review_${String(rows.length + 1).padStart(4, "0")}`,
      recordType,
      recordId,
      issueType,
      issueDescription,
      suggestedFix,
      manualResolution: "",
      resolved: false,
    });
  };

  for (const site of sites) {
    if (site.needsManualReview) {
      addReview("Site", site.siteId, "Site Cleanup", site.manualNotes || "Site needs confirmation", "Confirm site name, address, and Slack channel.");
    }
  }

  for (const event of eventRows) {
    if (event.needsManualReview) {
      addReview("Calendar Event", event.calendarEventId, "Site Match", `Could not confidently match "${event.summary}" to a known site.`, "Choose an existing site or create a new site.");
    }
    if (event.inferredVisitStatus === "Unknown") {
      addReview("Calendar Event", event.calendarEventId, "Visit Status", `Could not infer status from "${event.summary}".`, "Set visit status manually.");
    }
  }

  for (const job of jobs) {
    if (job.needsManagerReview) {
      addReview("Job", job.jobId, "Job Review", `Job "${job.jobTitle}" needs manager review.`, "Confirm job status and whether follow-up is needed.");
    }
  }

  for (const visit of visits) {
    if (visit.needsManualReview && !visit.workSummary) {
      addReview("Visit", visit.visitId, "Missing Visit Summary", "Visit has no description text.", "Add technician work summary if known.");
    }
  }

  return rows;
}

function writeSheet(sheet, title, note, headers, rows, widths = []) {
  sheet.getRangeByIndexes(0, 0, 1, headers.length).merge();
  sheet.getRange("A1").values = [[title]];
  sheet.getRangeByIndexes(1, 0, 1, headers.length).merge();
  sheet.getRange("A2").values = [[note]];
  sheet.getRangeByIndexes(3, 0, 1, headers.length).values = [headers.map((header) => header.label)];
  sheet.getRangeByIndexes(4, 0, rows.length, headers.length).values = rows.map((row) =>
    headers.map((header) => {
      const value = row[header.key];
      if (typeof value === "boolean") {
        return value ? "TRUE" : "FALSE";
      }
      return value ?? "";
    }),
  );

  const lastRow = Math.max(rows.length + 4, 4);
  sheet.tables.add(`A4:${columnName(headers.length)}${lastRow}`, true, `${title.replace(/[^A-Za-z0-9]/g, "")}Table`);
  sheet.freezePanes.freezeRows(4);
  sheet.showGridLines = false;
  sheet.getRange("A1").format = { font: { bold: true, size: 16, color: "#0F172A" } };
  sheet.getRange("A2").format = { font: { italic: true, color: "#475569" }, wrapText: true };
  sheet.getRangeByIndexes(3, 0, 1, headers.length).format = {
    fill: "#1F6F78",
    font: { bold: true, color: "#FFFFFF" },
  };
  sheet.getRangeByIndexes(3, 0, lastRow - 3, headers.length).format = {
    wrapText: true,
    verticalAlignment: "top",
  };

  widths.forEach((width, index) => {
    sheet.getRangeByIndexes(0, index, 1, 1).format.columnWidthPx = width;
  });
}

function columnName(count) {
  let name = "";
  let n = count;
  while (n > 0) {
    const rem = (n - 1) % 26;
    name = String.fromCharCode(65 + rem) + name;
    n = Math.floor((n - 1) / 26);
  }
  return name;
}

async function main() {
  const [calendarText, sourceSites] = await Promise.all([
    fs.readFile(calendarPath, "utf8"),
    readSiteSourceRows(siteWorkbookPath),
  ]);

  const events = parseIcsEvents(calendarText).sort((a, b) => String(a.startDateTime).localeCompare(String(b.startDateTime)));
  const eventRows = buildEventRows(events, sourceSites);
  const sites = buildSites(sourceSites, eventRows);
  const jobs = buildJobs(eventRows);
  const visits = buildVisits(eventRows, jobs);
  const manualReviewRows = buildManualReviewRows(sites, eventRows, jobs, visits);

  const workbook = Workbook.create();

  writeSheet(
    workbook.worksheets.add("Sites"),
    "Sites",
    "Known sites from Slack channel metadata plus inferred calendar-only sites.",
    [
      { key: "siteId", label: "site_id" },
      { key: "siteName", label: "site_name" },
      { key: "normalizedSiteName", label: "normalized_site_name" },
      { key: "address", label: "address" },
      { key: "slackChannel", label: "slack_channel" },
      { key: "addressSource", label: "address_source" },
      { key: "matchedFromCalendarCount", label: "matched_from_calendar_count" },
      { key: "needsManualReview", label: "needs_manual_review" },
      { key: "manualNotes", label: "manual_notes" },
    ],
    sites,
    [130, 240, 240, 340, 250, 180, 160, 160, 320],
  );

  writeSheet(
    workbook.worksheets.add("Calendar Events"),
    "Calendar Events",
    "Raw calendar events with detected site, job number, status, and matching confidence.",
    [
      { key: "calendarEventId", label: "calendar_event_id" },
      { key: "uid", label: "uid" },
      { key: "startDateTime", label: "start_datetime" },
      { key: "endDateTime", label: "end_datetime" },
      { key: "summary", label: "summary" },
      { key: "location", label: "location" },
      { key: "description", label: "description" },
      { key: "detectedSiteName", label: "detected_site_name" },
      { key: "detectedJobNumber", label: "detected_job_number" },
      { key: "matchedSiteId", label: "matched_site_id" },
      { key: "matchConfidence", label: "match_confidence" },
      { key: "inferredVisitStatus", label: "inferred_visit_status" },
      { key: "inferredPartsStatus", label: "inferred_parts_status" },
      { key: "needsManualReview", label: "needs_manual_review" },
    ],
    eventRows,
    [130, 260, 170, 170, 260, 320, 520, 240, 150, 130, 140, 170, 170, 150],
  );

  writeSheet(
    workbook.worksheets.add("Generated Jobs"),
    "Generated Jobs",
    "Conservative job grouping inferred from calendar events. Confirm before backend import.",
    [
      { key: "jobId", label: "job_id" },
      { key: "siteId", label: "site_id" },
      { key: "siteName", label: "site_name" },
      { key: "jobNumber", label: "job_number" },
      { key: "jobTitle", label: "job_title" },
      { key: "jobType", label: "job_type" },
      { key: "priority", label: "priority" },
      { key: "status", label: "status" },
      { key: "firstSeenDate", label: "first_seen_date" },
      { key: "lastSeenDate", label: "last_seen_date" },
      { key: "sourceCalendarEventIds", label: "source_calendar_event_ids" },
      { key: "needsParts", label: "needs_parts" },
      { key: "needsReturnVisit", label: "needs_return_visit" },
      { key: "needsManagerReview", label: "needs_manager_review" },
      { key: "confidence", label: "confidence" },
      { key: "manualNotes", label: "manual_notes" },
    ],
    jobs,
    [120, 120, 240, 130, 300, 130, 120, 170, 140, 140, 260, 120, 150, 170, 120, 280],
  );

  writeSheet(
    workbook.worksheets.add("Generated Visits"),
    "Generated Visits",
    "One visit per calendar event, linked back to inferred jobs and sites.",
    [
      { key: "visitId", label: "visit_id" },
      { key: "jobId", label: "job_id" },
      { key: "siteId", label: "site_id" },
      { key: "technicianName", label: "technician_name" },
      { key: "startDateTime", label: "start_datetime" },
      { key: "endDateTime", label: "end_datetime" },
      { key: "durationMinutes", label: "duration_minutes" },
      { key: "visitStatus", label: "visit_status" },
      { key: "workSummary", label: "work_summary" },
      { key: "partsStatus", label: "parts_status" },
      { key: "partsSource", label: "parts_source" },
      { key: "sourceCalendarEventId", label: "source_calendar_event_id" },
      { key: "needsManualReview", label: "needs_manual_review" },
    ],
    visits,
    [120, 120, 120, 180, 170, 170, 150, 170, 520, 170, 160, 170, 150],
  );

  writeSheet(
    workbook.worksheets.add("Manual Review"),
    "Manual Review",
    "Records that need human confirmation before they become trusted seed data.",
    [
      { key: "reviewId", label: "review_id" },
      { key: "recordType", label: "record_type" },
      { key: "recordId", label: "record_id" },
      { key: "issueType", label: "issue_type" },
      { key: "issueDescription", label: "issue_description" },
      { key: "suggestedFix", label: "suggested_fix" },
      { key: "manualResolution", label: "manual_resolution" },
      { key: "resolved", label: "resolved" },
    ],
    manualReviewRows,
    [130, 150, 140, 180, 500, 360, 320, 110],
  );

  await fs.mkdir(outputDir, { recursive: true });

  const preview = await workbook.render({
    sheetName: "Sites",
    range: "A1:I25",
    scale: 1,
    format: "png",
  });
  await fs.writeFile(previewPath, new Uint8Array(await preview.arrayBuffer()));

  const output = await SpreadsheetFile.exportXlsx(workbook);
  await output.save(outputWorkbookPath);

  console.log(JSON.stringify({
    outputWorkbookPath,
    previewPath,
    sites: sites.length,
    calendarEvents: eventRows.length,
    jobs: jobs.length,
    visits: visits.length,
    manualReviewRows: manualReviewRows.length,
  }, null, 2));
}

await main();
