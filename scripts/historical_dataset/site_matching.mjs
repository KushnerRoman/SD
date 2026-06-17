export function normalizeName(value = "") {
  return value
    .toLowerCase()
    .replace(/[#_]/g, " ")
    .replace(/[^a-z0-9]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

export function detectJobNumber(value = "") {
  const match = value.match(/\bJ\d{4,6}\b/i);
  return match ? match[0].toUpperCase() : "";
}

function stripJobNumber(value = "") {
  return value.replace(/\bJ\d{4,6}\b/gi, "").trim();
}

function includesAddressFragment(location, address) {
  const normalizedLocation = normalizeName(location);
  const normalizedAddress = normalizeName(address);
  if (!normalizedLocation || !normalizedAddress) {
    return false;
  }

  const addressTokens = normalizedAddress.split(" ").slice(0, 4).join(" ");
  return addressTokens.length >= 6 && normalizedLocation.includes(addressTokens);
}

export function matchSite(event, sites) {
  const summaryWithoutJob = stripJobNumber(event.summary ?? "");
  const normalizedSummary = normalizeName(summaryWithoutJob);
  const combinedText = normalizeName(`${event.summary ?? ""} ${event.location ?? ""} ${event.description ?? ""}`);

  for (const site of sites) {
    if (normalizedSummary && normalizedSummary === normalizeName(site.siteName)) {
      return {
        siteId: site.siteId,
        detectedSiteName: site.siteName,
        matchConfidence: "high",
        needsManualReview: false,
      };
    }
  }

  for (const site of sites) {
    const normalizedSite = normalizeName(site.siteName);
    if (normalizedSite && combinedText.includes(normalizedSite)) {
      return {
        siteId: site.siteId,
        detectedSiteName: site.siteName,
        matchConfidence: "medium",
        needsManualReview: false,
      };
    }
  }

  for (const site of sites) {
    if (includesAddressFragment(event.location ?? "", site.address ?? "")) {
      return {
        siteId: site.siteId,
        detectedSiteName: site.siteName,
        matchConfidence: "medium",
        needsManualReview: false,
      };
    }
  }

  return {
    siteId: "",
    detectedSiteName: stripJobNumber(event.summary ?? ""),
    matchConfidence: "none",
    needsManualReview: true,
  };
}

export function inferVisitStatus(text = "") {
  const normalized = normalizeName(text);

  if (/\b(waiting|wait)\b.*\b(parts?|reader|board|lock|strike|maglock)\b/.test(normalized)) {
    return "Waiting for Parts";
  }
  if (/\b(come back|return visit|go back|need return|needs return)\b/.test(normalized)) {
    return "Need Return Visit";
  }
  if (/\b(no access|could not access|couldn t access|locked out)\b/.test(normalized)) {
    return "Could Not Access Site";
  }
  if (/\b(done|completed|finished|fixed|tested|resolved)\b/.test(normalized)) {
    return "Completed";
  }
  if (normalized.length > 0) {
    return "Unknown";
  }

  return "Unknown";
}

export function inferPartsStatus(text = "") {
  const normalized = normalizeName(text);

  if (/\b(waiting|wait)\b.*\b(parts?|reader|board|lock|strike|maglock)\b/.test(normalized)) {
    return "Waiting for Parts";
  }
  if (/\b(order|ordered|need to order)\b/.test(normalized)) {
    return "Need to Order";
  }
  if (/\b(need|needed|requires|required)\b.*\b(parts?|reader|board|lock|strike|maglock|rex|contact)\b/.test(normalized)) {
    return "Parts Needed";
  }
  if (/\b(used|installed|replaced)\b.*\b(parts?|reader|board|lock|strike|maglock|rex|contact)\b/.test(normalized)) {
    return "Parts Used";
  }

  return "No Parts Mentioned";
}
