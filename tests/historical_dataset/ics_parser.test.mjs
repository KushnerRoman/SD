import test from "node:test";
import assert from "node:assert/strict";
import {
  decodeIcsText,
  parseIcsDate,
  parseIcsEvents,
  unfoldIcsLines,
} from "../../scripts/historical_dataset/ics_parser.mjs";

test("unfoldIcsLines joins continuation lines", () => {
  const input = "SUMMARY:Gateway\r\n description continued\r\nLOCATION:Calgary";
  assert.deepEqual(unfoldIcsLines(input), [
    "SUMMARY:Gatewaydescription continued",
    "LOCATION:Calgary",
  ]);
});

test("decodeIcsText handles escaped commas, newlines, and backslashes", () => {
  assert.equal(decodeIcsText("Door\\, reader\\nNeeds part\\\\tool"), "Door, reader\nNeeds part\\tool");
});

test("parseIcsDate parses UTC calendar timestamps", () => {
  assert.equal(parseIcsDate("20260520T143000Z").toISOString(), "2026-05-20T14:30:00.000Z");
});

test("parseIcsEvents extracts normalized events", () => {
  const rawEvent = [
    "UID:event-1",
    "DTSTART:20260520T143000Z",
    "DTEND:20260520T153000Z",
    "SUMMARY:Rocky ridge Landing",
    "LOCATION:500 Rocky Vista Gardens NW\\, Calgary",
    "DESCRIPTION:Need return visit\\nWaiting for parts",
  ].join("\r\n");
  const ics = `BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\n${rawEvent}\r\nEND:VEVENT\r\nEND:VCALENDAR`;

  assert.deepEqual(parseIcsEvents(ics), [
    {
      calendarEventId: "cal_0001",
      uid: "event-1",
      startDateTime: "2026-05-20T14:30:00.000Z",
      endDateTime: "2026-05-20T15:30:00.000Z",
      summary: "Rocky ridge Landing",
      location: "500 Rocky Vista Gardens NW, Calgary",
      description: "Need return visit\nWaiting for parts",
      rawEvent,
    },
  ]);
});
