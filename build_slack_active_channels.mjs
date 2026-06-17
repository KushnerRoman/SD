import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";

const outputDir = path.join(process.cwd(), "outputs", "slack-active-channels-2026-05-31");
const outputPath = path.join(outputDir, "slack_active_channels_last_week.xlsx");
const previewPath = path.join(outputDir, "preview.png");

const rows = [
  {
    name: "#symmetry-and-harmony",
    id: "C0A4TF76HED",
    lastActivity: "2026-05-29 20:03 MDT",
    type: "private_channel",
    archived: "false",
    created: "2025-12-18 07:53:07 MST",
    creator: "Edward (U8CFCRG8Z)",
    topic: "",
    purpose: "121 Copperpond Cmn S E, Calgary, AB T2Z 5B6",
    link: "https://securitydepot.slack.com/archives/C0A4TF76HED",
  },
  {
    name: "#bridleview-pointe",
    id: "CE03QV7EK",
    lastActivity: "2026-05-29 12:40 MDT",
    type: "private_channel",
    archived: "false",
    created: "2018-11-08 10:17:33 MST",
    creator: "Duncan (UCEJZH4KW)",
    topic: "Lockbox in 2000 #1927",
    purpose: "Jennifer BM 4036050598 8 Bridlecrest Dr SW, Calgary, AB T2Y 0H7",
    link: "https://securitydepot.slack.com/archives/CE03QV7EK",
  },
  {
    name: "#hestia-aspen",
    id: "C072ZRX4Q5P",
    lastActivity: "2026-05-29 12:04 MDT",
    type: "private_channel",
    archived: "false",
    created: "2024-05-08 15:08:29 MDT",
    creator: "Iain (U8DSXU63Y)",
    topic: "1830 85St SW",
    purpose: "J22095 Aspen",
    link: "https://securitydepot.slack.com/archives/C072ZRX4Q5P",
  },
  {
    name: "#panorama-pointe",
    id: "C07HA92NQLX",
    lastActivity: "2026-05-29 10:54 MDT",
    type: "private_channel",
    archived: "false",
    created: "2024-08-20 10:39:11 MDT",
    creator: "Edward (U8CFCRG8Z)",
    topic: "CondoCorp2025! NVR and Cams PW",
    purpose: "60 Panatella Street NW, Calgary, AB T3K, Canada BM Girish 587-889-0783 General contractor lock box in building 1000 entrance code 2018- (entrance key) - Second lockbox with contractor keys - on electrical room door code 2019",
    link: "https://securitydepot.slack.com/archives/C07HA92NQLX",
  },
  {
    name: "#orchardsky",
    id: "GDVBT5CP8",
    lastActivity: "2026-05-29 10:34 MDT",
    type: "private_channel",
    archived: "false",
    created: "2018-11-01 14:53:05 MDT",
    creator: "Edward (U8CFCRG8Z)",
    topic: "",
    purpose: "302 Skyview Ranch Dr, Calgary, AB T3N 0P4\nLockbox codes updated Aug 08 2025\n1000 - 2973\n2000 - 3570\n3000 - 3896\n4000 - 3849\n5000 - 3568\n6000 - 3149\n7000 - 3860",
    link: "https://securitydepot.slack.com/archives/GDVBT5CP8",
  },
  {
    name: "#nobletownhomes",
    id: "G01D2EYKA05",
    lastActivity: "2026-05-29 10:16 MDT",
    type: "private_channel",
    archived: "false",
    created: "2020-10-22 14:45:26 MDT",
    creator: "Edward (U8CFCRG8Z)",
    topic: "",
    purpose: "Norford Ave. & Kovitz Lane NW Calgary, Alberta | T3B 6H3 lockbox 6239",
    link: "https://securitydepot.slack.com/archives/G01D2EYKA05",
  },
  {
    name: "#sandgate-mahogany",
    id: "C03MPPZHJTD",
    lastActivity: "2026-05-29 10:14 MDT",
    type: "private_channel",
    archived: "false",
    created: "2022-06-29 10:56:56 MDT",
    creator: "Iain (U8DSXU63Y)",
    topic: "10 Mahogany Mews SE",
    purpose: "B40 LockBox code is 1468. located on back of door\nIntercom code B20: *5309\nLockbox code on electrical room door by elevators (this door has the computer in it): 8203\nB30, intercom code is: *3030\nGarbage LB 2594. 10 LB 2584",
    link: "https://securitydepot.slack.com/archives/C03MPPZHJTD",
  },
  {
    name: "#highbury-towers",
    id: "C02H42UUJN8",
    lastActivity: "2026-05-29 09:13 MDT",
    type: "private_channel",
    archived: "false",
    created: "2021-10-07 11:41:29 MDT",
    creator: "Iain (U8DSXU63Y)",
    topic: "10 Shawnee Hill SW, Calgary, AB T2Y 0K4",
    purpose: "*9150 Intercom and 8256 Lockbox\nThe lockbox is at the main level from the round about which is in the middle of the two buildings. Park outside the garbage room.",
    link: "https://securitydepot.slack.com/archives/C02H42UUJN8",
  },
  {
    name: "#centro-733",
    id: "C05N53VSH97",
    lastActivity: "2026-05-29 09:05 MDT",
    type: "private_channel",
    archived: "false",
    created: "2023-08-14 16:02:36 MDT",
    creator: "Iain (U8DSXU63Y)",
    topic: "Lock box code is 3725. If you need assistance 403-389-9266. This Sonia Purkiss, She is the Property Manager",
    purpose: "733 14th Avenue SW\nTwo controllers - one in the lobby and the other at the rear door\nLockbox key is on black pillar inside foyer 3725",
    link: "https://securitydepot.slack.com/archives/C05N53VSH97",
  },
  {
    name: "#autumn",
    id: "C0AUUSJL8AH",
    lastActivity: "2026-05-28 16:20 MDT",
    type: "private_channel",
    archived: "false",
    created: "2026-04-23 15:39:09 MDT",
    creator: "Edward (U8CFCRG8Z)",
    topic: "3107 Warren St NW",
    purpose: "The site contact for Autumn is Alex Gagnon (Homes by Avi) 403-390-5062. He is onsite every day and will be able to provide you access to anywhere in the building.",
    link: "https://securitydepot.slack.com/archives/C0AUUSJL8AH",
  },
  {
    name: "#pk-productknowledge",
    id: "GHAV3C3JQ",
    lastActivity: "2026-05-28 15:07 MDT",
    type: "private_channel",
    archived: "false",
    created: "2019-03-26 15:23:05 MDT",
    creator: "Iain (U8DSXU63Y)",
    topic: "",
    purpose: "Share products that we can use",
    link: "https://securitydepot.slack.com/archives/GHAV3C3JQ",
  },
  {
    name: "#lawrie-park-okotoks",
    id: "C09NUVCL46R",
    lastActivity: "2026-05-28 14:37 MDT",
    type: "private_channel",
    archived: "false",
    created: "2025-10-27 10:41:36 MDT",
    creator: "Iain (U8DSXU63Y)",
    topic: "100 Banister Drive\nOkotoks, AB T1S 5R1",
    purpose: "Access: 0-3761\nLockbox: 8264\nPrograming code 5716. as of Apr 14 2026",
    link: "https://securitydepot.slack.com/archives/C09NUVCL46R",
  },
  {
    name: "#versace",
    id: "C02AVKYJK5W",
    lastActivity: "2026-05-28 08:47 MDT",
    type: "private_channel",
    archived: "false",
    created: "2021-08-04 08:18:50 MDT",
    creator: "Edward (U8CFCRG8Z)",
    topic: "504 5th Ave NE",
    purpose: "lockboxes 1785 and 1786 within the stairwell (1 has fob and other has keys for mechanical room)",
    link: "https://securitydepot.slack.com/archives/C02AVKYJK5W",
  },
  {
    name: "#legacy-gate",
    id: "CCE46JQ3A",
    lastActivity: "2026-05-28 08:09 MDT",
    type: "private_channel",
    archived: "false",
    created: "2018-08-24 10:47:06 MDT",
    creator: "Edward (U8CFCRG8Z)",
    topic: "81 Legacy Blvd SE\nSharon Prevost <Sharon.legacygatepm@outlook.com> Property Attendant 403-988-1331\n*Always advise Sharon when going to site*",
    purpose: "June 21 - Per Sharon there is only 1 lockbox in B2000\nLockBox -1359\nSTAFF Parking only\nwww.youpark.io, enter license plate, select staff parking, enter code 78233, click ok",
    link: "https://securitydepot.slack.com/archives/CCE46JQ3A",
  },
  {
    name: "#mantra",
    id: "C05MFHY9VGB",
    lastActivity: "2026-05-27 14:31 MDT",
    type: "private_channel",
    archived: "false",
    created: "2023-08-11 10:11:17 MDT",
    creator: "Iain (U8DSXU63Y)",
    topic: "910 18 Ave SW, Calgary, AB T2T 0H1, Canada",
    purpose: "Garbage code 7590\nLockbox 2490",
    link: "https://securitydepot.slack.com/archives/C05MFHY9VGB",
  },
  {
    name: "#skymills",
    id: "GFTJC5MTR",
    lastActivity: "2026-05-27 12:03 MDT",
    type: "private_channel",
    archived: "false",
    created: "2019-01-29 14:05:22 MST",
    creator: "Edward (U8CFCRG8Z)",
    topic: "240 Skyview Ranch Rd, Calgary, AB T3N 1B6",
    purpose: "Mechanical Lock: 153 (Elec Rm, entrance of B1000) (If lock isn't working, try turning the handle counter clockwise to reset the lock)\nLockbox:6274 (Inside Elec Rm Bld 1000)\nMiddle Box 5463\nBttm Box 1379\nKeyless: All Bldgs -*2947\nRoof hatch 6274",
    link: "https://securitydepot.slack.com/archives/GFTJC5MTR",
  },
  {
    name: "#rocky-ridge-landing",
    id: "C06PMV25Y2Y",
    lastActivity: "2026-05-27 12:03 MDT",
    type: "private_channel",
    archived: "false",
    created: "2024-03-14 09:15:44 MDT",
    creator: "Edward (U8CFCRG8Z)",
    topic: "500 Rocky Vista Gardens NW",
    purpose: "Lockbox 1832\nKeyless Entry code *2846 router p/w rockyridgeSD",
    link: "https://securitydepot.slack.com/archives/C06PMV25Y2Y",
  },
  {
    name: "#gatewaygarrisonwood",
    id: "G0195FFARHS",
    lastActivity: "2026-05-27 11:37 MDT",
    type: "private_channel",
    archived: "false",
    created: "2020-08-17 09:27:56 MDT",
    creator: "Edward (U8CFCRG8Z)",
    topic: "2233 34 Avenue SW, Calgary, Alberta",
    purpose: "May 21 2025 Electrical room in lobby combo lock code 342\nMay 21 2025 Contractor Lockbox 1794\nThe key is (or should be) in our lockbox in the inner lobby - 1794\n2233 34 Ave SW, Calgary, AB T2T 6N2",
    link: "https://securitydepot.slack.com/archives/G0195FFARHS",
  },
  {
    name: "#hestia-okotoks-darcy-heights",
    id: "C06MJGMHZ89",
    lastActivity: "2026-05-27 10:50 MDT",
    type: "private_channel",
    archived: "false",
    created: "2024-02-28 17:07:43 MST",
    creator: "Iain (U8DSXU63Y)",
    topic: "53 Avens Way, Okotoks, AB T1S 1R1",
    purpose: "",
    link: "https://securitydepot.slack.com/archives/C06MJGMHZ89",
  },
  {
    name: "#shaheen-silver-springs",
    id: "C0B6M2A1BU4",
    lastActivity: "2026-05-27 10:29 MDT",
    type: "private_channel",
    archived: "false",
    created: "2026-05-27 09:38:01 MDT",
    creator: "Edward (U8CFCRG8Z)",
    topic: "",
    purpose: "Lockbox on loading bay door 4332",
    link: "https://securitydepot.slack.com/archives/C0B6M2A1BU4",
  },
  {
    name: "#community-kitchen",
    id: "C0A9CR16K52",
    lastActivity: "2026-05-27 09:32 MDT",
    type: "private_channel",
    archived: "false",
    created: "2026-01-16 13:43:58 MST",
    creator: "Iain (U8DSXU63Y)",
    topic: "3751 21st Street NE\nCalgary AB T2E 6T5 Ken (403) 690-5387",
    purpose: "",
    link: "https://securitydepot.slack.com/archives/C0A9CR16K52",
  },
  {
    name: "#kensington-301",
    id: "G01GES4GJJJ",
    lastActivity: "2026-05-27 08:30 MDT",
    type: "private_channel",
    archived: "false",
    created: "2020-12-10 10:28:16 MST",
    creator: "Edward (U8CFCRG8Z)",
    topic: "",
    purpose: "301 10th Street NW - 2560 for Mech door code",
    link: "https://securitydepot.slack.com/archives/G01GES4GJJJ",
  },
  {
    name: "#a-adi",
    id: "GHZ8MJFGD",
    lastActivity: "2026-05-27 06:55 MDT",
    type: "private_channel",
    archived: "false",
    created: "2019-04-17 10:29:00 MDT",
    creator: "Edward (U8CFCRG8Z)",
    topic: "",
    purpose: "please check this channel each time you arrive at ADI. Misc orders that are not part of scheduled pick ups will be placed here. Please bring back to the office.\n\nRespond in channel that you picked up PO XXXXX so that others know that its been done",
    link: "https://securitydepot.slack.com/archives/GHZ8MJFGD",
  },
  {
    name: "#announcements",
    id: "GHXL0THTN",
    lastActivity: "2026-05-26 07:36 MDT",
    type: "private_channel",
    archived: "false",
    created: "2019-04-16 16:20:13 MDT",
    creator: "Edward (U8CFCRG8Z)",
    topic: "",
    purpose: "",
    link: "https://securitydepot.slack.com/archives/GHXL0THTN",
  },
  {
    name: "#versant",
    id: "GL587N37A",
    lastActivity: "2026-05-25 15:07 MDT",
    type: "private_channel",
    archived: "false",
    created: "2019-07-04 11:46:28 MDT",
    creator: "Edward (U8CFCRG8Z)",
    topic: "",
    purpose: "lockbox code is 1236, lockbox is found on the side of the EXT elevator lobby on building B\nPhase 3 - Building 'E'3000\n3000 Stewart Creek Drive, Canmore",
    link: "https://securitydepot.slack.com/archives/GL587N37A",
  },
  {
    name: "#wolseley-canmore",
    id: "C0B5GQJPVRP",
    lastActivity: "2026-05-25 14:17 MDT",
    type: "private_channel",
    archived: "false",
    created: "2026-05-21 13:59:18 MDT",
    creator: "Iain (U8DSXU63Y)",
    topic: "",
    purpose: "",
    link: "https://securitydepot.slack.com/archives/C0B5GQJPVRP",
  },
  {
    name: "#simon",
    id: "C0ACW3U3WCW",
    lastActivity: "2026-05-25 12:44 MDT",
    type: "private_channel",
    archived: "false",
    created: "2026-02-04 06:48:28 MST",
    creator: "Edward (U8CFCRG8Z)",
    topic: "",
    purpose: "",
    link: "https://securitydepot.slack.com/archives/C0ACW3U3WCW",
  },
  {
    name: "#alora",
    id: "GG1FUPSJZ",
    lastActivity: "2026-05-25 09:36 MDT",
    type: "private_channel",
    archived: "false",
    created: "2019-02-07 14:15:36 MST",
    creator: "Edward (U8CFCRG8Z)",
    topic: "Ken or Karen BM",
    purpose: "lock box code for Alora is 1508 as of Feb 06 2024 per email from Karen and Tracey",
    link: "https://securitydepot.slack.com/archives/GG1FUPSJZ",
  },
];

const workbook = Workbook.create();
const sheet = workbook.worksheets.add("Active Channels");

const title = "Slack active channels - last week";
const subtitle = "Read-only extract. Activity window: 2026-05-24 through 2026-05-31. Includes accessible public/private channels returned by Slack search.";
sheet.getRange("A1:J1").merge();
sheet.getRange("A1").values = [[title]];
sheet.getRange("A2:J2").merge();
sheet.getRange("A2").values = [[subtitle]];

const headers = [
  "Channel",
  "Channel ID",
  "Last Activity",
  "Type",
  "Archived",
  "Created",
  "Creator",
  "Topic",
  "Purpose / Details",
  "Slack Link",
];

const data = rows.map((row) => [
  row.name,
  row.id,
  row.lastActivity,
  row.type,
  row.archived,
  row.created,
  row.creator,
  row.topic,
  row.purpose,
  row.link,
]);

sheet.getRange("A4:J4").values = [headers];
sheet.getRangeByIndexes(4, 0, data.length, headers.length).values = data;

const used = sheet.getRange(`A4:J${data.length + 4}`);
sheet.tables.add(`A4:J${data.length + 4}`, true, "ActiveChannelsTable");

sheet.getRange("A1").format = {
  font: { bold: true, size: 16, color: "#0F172A" },
};
sheet.getRange("A2").format = {
  font: { italic: true, color: "#475569" },
};
sheet.getRange("A4:J4").format = {
  fill: "#0F766E",
  font: { bold: true, color: "#FFFFFF" },
};
used.format = {
  wrapText: true,
  verticalAlignment: "top",
};

sheet.getRange("A:A").format.columnWidthPx = 190;
sheet.getRange("B:B").format.columnWidthPx = 120;
sheet.getRange("C:C").format.columnWidthPx = 160;
sheet.getRange("D:D").format.columnWidthPx = 130;
sheet.getRange("E:E").format.columnWidthPx = 80;
sheet.getRange("F:F").format.columnWidthPx = 170;
sheet.getRange("G:G").format.columnWidthPx = 150;
sheet.getRange("H:H").format.columnWidthPx = 280;
sheet.getRange("I:I").format.columnWidthPx = 520;
sheet.getRange("J:J").format.columnWidthPx = 320;

sheet.getRange("A1:A2").format.rowHeightPx = 28;
sheet.getRange(`A5:J${data.length + 4}`).format.rowHeightPx = 84;
sheet.freezePanes.freezeRows(4);
sheet.showGridLines = false;

const notes = workbook.worksheets.add("Source Notes");
notes.getRange("A1:B1").values = [["Field", "Value"]];
notes.getRange("A2:B8").values = [
  ["Generated", "2026-05-31"],
  ["Slack access", "Read-only connector calls only"],
  ["Activity definition", "At least one Slack message returned by search after 2026-05-24"],
  ["Scope", "Accessible public/private channels in the connected workspace"],
  ["No changes made", "No messages, reactions, channel edits, creates, deletes, or settings changes were performed"],
  ["Rows", rows.length],
  ["Details source", "Slack channel search details: topic, purpose, creator, created date, archive flag, channel type, permalink"],
];
notes.getRange("A1:B1").format = {
  fill: "#0F766E",
  font: { bold: true, color: "#FFFFFF" },
};
notes.getRange("A:B").format = { wrapText: true, verticalAlignment: "top" };
notes.getRange("A:A").format.columnWidthPx = 180;
notes.getRange("B:B").format.columnWidthPx = 620;
notes.showGridLines = false;

await fs.mkdir(outputDir, { recursive: true });

const preview = await workbook.render({
  sheetName: "Active Channels",
  range: "A1:J20",
  scale: 1,
  format: "png",
});
await fs.writeFile(previewPath, new Uint8Array(await preview.arrayBuffer()));

const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A",
  options: { useRegex: true, maxResults: 100 },
  summary: "final formula error scan",
});
console.log(errors.ndjson);

const xlsx = await SpreadsheetFile.exportXlsx(workbook);
await xlsx.save(outputPath);
console.log(outputPath);
