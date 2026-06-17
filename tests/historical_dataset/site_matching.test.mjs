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
