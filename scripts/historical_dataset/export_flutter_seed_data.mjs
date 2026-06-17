import fs from "node:fs/promises";
import path from "node:path";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";
import { normalizeCellText, normalizeDateCell } from "./seed_export_utils.mjs";

const workbookPath = path.join(process.cwd(), "outputs", "historical-dataset-v0.1", "historical_dataset_review.xlsx");
const outputPath = path.join(process.cwd(), "app", "security_depot_fsm", "assets", "data", "seed_data.json");

async function readTable(workbook, sheetId) {
  const inspected = await workbook.inspect({
    kind: "table",
    sheetId,
    tableMaxRows: 1000,
    tableMaxCols: 30,
    tableMaxCellChars: 2000,
    maxChars: 500000,
  });
  const record = inspected.ndjson
    .split(/\r?\n/)
    .filter(Boolean)
    .map((line) => JSON.parse(line))
    .find((item) => item.kind === "table" && Array.isArray(item.values));

  if (!record) {
    throw new Error(`No table found for ${sheetId}`);
  }

  const headerIndex = record.values.findIndex((row) => row.some((cell) => typeof cell === "string" && cell.endsWith("_id")));
  if (headerIndex === -1) {
    throw new Error(`No header row found for ${sheetId}`);
  }

  const headers = record.values[headerIndex].map((header) => String(header ?? ""));
  return record.values.slice(headerIndex + 1).filter((row) => row.some((cell) => cell !== null && cell !== "")).map((row) => {
    const output = {};
    headers.forEach((header, index) => {
      output[header] = row[index] ?? "";
    });
    return output;
  });
}

function cleanJobs(jobs) {
  return jobs.map((job) => ({
    id: normalizeCellText(job.job_id),
    siteId: normalizeCellText(job.site_id),
    siteName: normalizeCellText(job.site_name),
    jobNumber: normalizeCellText(job.job_number),
    title: normalizeCellText(job.job_title),
    type: normalizeCellText(job.job_type || "Unknown"),
    priority: normalizeCellText(job.priority || "Normal"),
    status: normalizeCellText(job.status || "Scheduled"),
    firstSeenDate: normalizeDateCell(job.first_seen_date),
    lastSeenDate: normalizeDateCell(job.last_seen_date),
    sourceCalendarEventIds: normalizeCellText(job.source_calendar_event_ids),
    details: "",
    rawCalendarDetails: [],
    needsParts: String(job.needs_parts ?? "").toUpperCase() === "TRUE",
    needsReturnVisit: String(job.needs_return_visit ?? "").toUpperCase() === "TRUE",
    needsManagerReview: String(job.needs_manager_review ?? "").toUpperCase() === "TRUE",
    confidence: normalizeCellText(job.confidence),
  }));
}

function cleanSites(sites) {
  return sites.map((site) => ({
    id: normalizeCellText(site.site_id),
    name: normalizeCellText(site.site_name),
    normalizedName: normalizeCellText(site.normalized_site_name),
    address: normalizeCellText(site.address),
    slackChannel: normalizeCellText(site.slack_channel),
    source: normalizeCellText(site.address_source),
    needsManualReview: String(site.needs_manual_review ?? "").toUpperCase() === "TRUE",
  }));
}

function cleanVisits(visits) {
  return visits.map((visit) => ({
    id: normalizeCellText(visit.visit_id),
    jobId: normalizeCellText(visit.job_id),
    siteId: normalizeCellText(visit.site_id),
    technicianName: normalizeCellText(visit.technician_name || "Roman Kushner"),
    startDateTime: normalizeDateCell(visit.start_datetime),
    endDateTime: normalizeDateCell(visit.end_datetime),
    durationMinutes: Number(visit.duration_minutes || 0),
    status: normalizeCellText(visit.visit_status || "Unknown"),
    workSummary: normalizeCellText(visit.work_summary),
    partsStatus: normalizeCellText(visit.parts_status || "No Parts Mentioned"),
    needsManualReview: String(visit.needs_manual_review ?? "").toUpperCase() === "TRUE",
  }));
}

function enrichJobsWithCalendarDetails(jobs, calendarEvents) {
  const eventsById = new Map(calendarEvents.map((event) => [String(event.calendar_event_id ?? ""), event]));
  return jobs.map((job) => {
    const eventIds = job.sourceCalendarEventIds
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean);
    const sourceEvents = eventIds.map((eventId) => eventsById.get(eventId)).filter(Boolean);
    const detailBlocks = sourceEvents.map((event) => {
      const lines = [
        `Event: ${normalizeCellText(event.summary)}`,
        `Start: ${normalizeDateCell(event.start_datetime)}`,
      ];
      if (normalizeCellText(event.location) !== "") {
        lines.push(`Location: ${normalizeCellText(event.location)}`);
      }
      lines.push("", normalizeCellText(event.description));
      return lines.join("\n").trim();
    }).filter(Boolean);

    return {
      ...job,
      details: detailBlocks.join("\n\n---\n\n"),
      rawCalendarDetails: sourceEvents.map((event) => ({
        calendarEventId: normalizeCellText(event.calendar_event_id),
        uid: normalizeCellText(event.uid),
        summary: normalizeCellText(event.summary),
        startDateTime: normalizeDateCell(event.start_datetime),
        endDateTime: normalizeDateCell(event.end_datetime),
        location: normalizeCellText(event.location),
        description: normalizeCellText(event.description),
      })),
    };
  });
}

async function main() {
  const input = await FileBlob.load(workbookPath);
  const workbook = await SpreadsheetFile.importXlsx(input);
  const [sites, jobs, visits, calendarEvents] = await Promise.all([
    readTable(workbook, "Sites"),
    readTable(workbook, "Generated Jobs"),
    readTable(workbook, "Generated Visits"),
    readTable(workbook, "Calendar Events"),
  ]);

  const payload = {
    generatedAt: new Date().toISOString(),
    source: "outputs/historical-dataset-v0.1/historical_dataset_review.xlsx",
    sites: cleanSites(sites),
    jobs: enrichJobsWithCalendarDetails(cleanJobs(jobs), calendarEvents),
    visits: cleanVisits(visits),
    technicians: [
      { id: "tech_roman", name: "Roman Kushner", email: "roman.kushner@gmail.com", initials: "RK" },
      { id: "tech_dex", name: "Dex", email: "dex@securitydepot.ca", initials: "DX" },
      { id: "tech_mike", name: "Mike", email: "mike@securitydepot.ca", initials: "MK" },
      { id: "tech_alan", name: "Alan", email: "alan@securitydepot.ca", initials: "AL" },
    ],
  };

  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, `${JSON.stringify(payload, null, 2)}\n`);
  console.log(JSON.stringify({
    outputPath,
    sites: payload.sites.length,
    jobs: payload.jobs.length,
    visits: payload.visits.length,
  }, null, 2));
}

await main();
