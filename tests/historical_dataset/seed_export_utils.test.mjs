import test from "node:test";
import assert from "node:assert/strict";
import {
  normalizeCellText,
  normalizeDateCell,
} from "../../scripts/historical_dataset/seed_export_utils.mjs";

test("normalizeDateCell converts Excel serial dates to ISO strings", () => {
  assert.equal(normalizeDateCell(46106.583333333336), "2026-03-25T14:00:00.000Z");
});

test("normalizeCellText repairs common UTF-8 mojibake from workbook export", () => {
  assert.equal(
    normalizeCellText("Resident didnât answer.Â  Leave message."),
    "Resident didn't answer. Leave message.",
  );
});

test("normalizeCellText removes Google Calendar invitation metadata blocks", () => {
  assert.equal(
    normalizeCellText("Continued installation\n\n-::~:~::~:~:~:~:~:~:~:~:~\nPlease do not edit this section."),
    "Continued installation",
  );
  assert.equal(
    normalizeCellText("-::~:~::~:~:~:~:~:~:~:~:~\nJoin with Google Meet."),
    "",
  );
});
