import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";
import { normalizeName } from "./site_matching.mjs";

export async function readSiteSourceRows(workbookPath) {
  const input = await FileBlob.load(workbookPath);
  const workbook = await SpreadsheetFile.importXlsx(input);
  const inspected = await workbook.inspect({
    kind: "table",
    tableMaxRows: 1000,
    tableMaxCols: 10,
    tableMaxCellChars: 500,
    maxChars: 50000,
  });

  const tableRecord = inspected.ndjson
    .split(/\r?\n/)
    .filter(Boolean)
    .map((line) => JSON.parse(line))
    .find((record) => record.kind === "table" && Array.isArray(record.values));

  if (!tableRecord) {
    throw new Error(`Could not find table values in ${workbookPath}`);
  }

  const headerIndex = tableRecord.values.findIndex((row) => row.includes("Place Name"));
  if (headerIndex === -1) {
    throw new Error(`Could not find Place Name header in ${workbookPath}`);
  }

  const rows = tableRecord.values.slice(headerIndex + 1);
  return rows
    .filter((row) => row[0])
    .map((row, index) => ({
      siteId: `site_${String(index + 1).padStart(4, "0")}`,
      siteName: String(row[0] ?? "").trim(),
      normalizedSiteName: normalizeName(String(row[0] ?? "")),
      address: String(row[2] ?? "").trim(),
      slackChannel: String(row[1] ?? "").trim(),
      addressSource: String(row[3] ?? "").trim(),
      source: "slack_channel_addresses",
    }));
}
