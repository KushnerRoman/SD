import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = path.join(process.cwd(), "outputs", "slack-active-channels-2026-05-31");
const outputPath = path.join(outputDir, "slack_channel_addresses.xlsx");
const previewPath = path.join(outputDir, "addresses_preview.png");

const rows = [
  ["Symmetry and Harmony", "#symmetry-and-harmony", "121 Copperpond Cmn SE, Calgary, AB T2Z 5B6", "Details / Purpose"],
  ["Bridleview Pointe", "#bridleview-pointe", "8 Bridlecrest Dr SW, Calgary, AB T2Y 0H7", "Details / Purpose"],
  ["Hestia Aspen", "#hestia-aspen", "1830 85 St SW", "Topic"],
  ["Panorama Pointe", "#panorama-pointe", "60 Panatella Street NW, Calgary, AB T3K, Canada", "Details / Purpose"],
  ["Orchard Sky", "#orchardsky", "302 Skyview Ranch Dr, Calgary, AB T3N 0P4", "Details / Purpose"],
  ["Noble Townhomes", "#nobletownhomes", "Norford Ave. & Kovitz Lane NW, Calgary, AB T3B 6H3", "Details / Purpose"],
  ["Sandgate Mahogany", "#sandgate-mahogany", "10 Mahogany Mews SE", "Topic"],
  ["Highbury Towers", "#highbury-towers", "10 Shawnee Hill SW, Calgary, AB T2Y 0K4", "Topic"],
  ["Centro 733", "#centro-733", "733 14th Avenue SW", "Details / Purpose"],
  ["Autumn", "#autumn", "3107 Warren St NW", "Topic"],
  ["PK Product Knowledge", "#pk-productknowledge", "", "No address found"],
  ["Lawrie Park Okotoks", "#lawrie-park-okotoks", "100 Banister Drive, Okotoks, AB T1S 5R1", "Topic"],
  ["Versace", "#versace", "504 5th Ave NE", "Topic"],
  ["Legacy Gate", "#legacy-gate", "81 Legacy Blvd SE", "Topic"],
  ["Mantra", "#mantra", "910 18 Ave SW, Calgary, AB T2T 0H1, Canada", "Topic"],
  ["Sky Mills", "#skymills", "240 Skyview Ranch Rd, Calgary, AB T3N 1B6", "Topic"],
  ["Rocky Ridge Landing", "#rocky-ridge-landing", "500 Rocky Vista Gardens NW", "Topic"],
  ["Gateway Garrisonwood", "#gatewaygarrisonwood", "2233 34 Avenue SW, Calgary, AB T2T 6N2", "Topic / Details"],
  ["Hestia Okotoks Darcy Heights", "#hestia-okotoks-darcy-heights", "53 Avens Way, Okotoks, AB T1S 1R1", "Topic"],
  ["Shaheen Silver Springs", "#shaheen-silver-springs", "", "No address found"],
  ["Community Kitchen", "#community-kitchen", "3751 21st Street NE, Calgary, AB T2E 6T5", "Topic"],
  ["Kensington 301", "#kensington-301", "301 10th Street NW", "Details / Purpose"],
  ["A ADI", "#a-adi", "", "No address found"],
  ["Announcements", "#announcements", "", "No address found"],
  ["Versant", "#versant", "3000 Stewart Creek Drive, Canmore", "Details / Purpose"],
  ["Wolseley Canmore", "#wolseley-canmore", "", "No address found"],
  ["Simon", "#simon", "", "No address found"],
  ["Alora", "#alora", "", "No address found"],
];

const workbook = Workbook.create();
const sheet = workbook.worksheets.add("Channel Addresses");

sheet.getRange("A1:D1").merge();
sheet.getRange("A1").values = [["Slack channel addresses"]];
sheet.getRange("A2:D2").merge();
sheet.getRange("A2").values = [["Extracted from the active-channel file generated on 2026-05-31. Blank address means no street address was visible in Topic or Details/Purpose."]];

sheet.getRange("A4:D4").values = [["Place Name", "Channel Name", "Extracted Address", "Source"]];
sheet.getRangeByIndexes(4, 0, rows.length, 4).values = rows;
sheet.tables.add(`A4:D${rows.length + 4}`, true, "ChannelAddressesTable");

sheet.getRange("A1").format = { font: { bold: true, size: 16, color: "#0F172A" } };
sheet.getRange("A2").format = { font: { italic: true, color: "#475569" } };
sheet.getRange("A4:D4").format = {
  fill: "#0F766E",
  font: { bold: true, color: "#FFFFFF" },
};
sheet.getRange(`A4:D${rows.length + 4}`).format = {
  wrapText: true,
  verticalAlignment: "top",
};
sheet.getRange("A:A").format.columnWidthPx = 250;
sheet.getRange("B:B").format.columnWidthPx = 260;
sheet.getRange("C:C").format.columnWidthPx = 440;
sheet.getRange("D:D").format.columnWidthPx = 160;
sheet.getRange(`A5:D${rows.length + 4}`).format.rowHeightPx = 36;
sheet.freezePanes.freezeRows(4);
sheet.showGridLines = false;

await fs.mkdir(outputDir, { recursive: true });

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "final formula error scan",
});
console.log(errors.ndjson);

const preview = await workbook.render({
  sheetName: "Channel Addresses",
  range: "A1:D24",
  scale: 1,
  format: "png",
});
await fs.writeFile(previewPath, new Uint8Array(await preview.arrayBuffer()));

const xlsx = await SpreadsheetFile.exportXlsx(workbook);
await xlsx.save(outputPath);
console.log(outputPath);
