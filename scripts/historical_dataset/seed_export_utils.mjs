const excelEpochOffsetDays = 25569;
const millisecondsPerDay = 86400000;

export function normalizeDateCell(value) {
  if (typeof value === "number" && Number.isFinite(value) && value > 20000 && value < 80000) {
    const milliseconds = Math.round((value - excelEpochOffsetDays) * millisecondsPerDay);
    return new Date(milliseconds).toISOString();
  }

  return normalizeCellText(value);
}

export function normalizeCellText(value = "") {
  const raw = String(value ?? "");
  const repaired = looksLikeMojibake(raw) ? Buffer.from(raw, "latin1").toString("utf8") : raw;

  return repaired
    .replace(/(^|\n)\s*-::~:~::~[\s\S]*$/g, "")
    .replace(/\u00a0/g, " ")
    .replace(/[\u2018\u2019]/g, "'")
    .replace(/[\u201c\u201d]/g, '"')
    .replace(/[\u2013\u2014]/g, "-")
    .replace(/[ \t]+/g, " ")
    .replace(/[ \t]+\n/g, "\n")
    .trim();
}

function looksLikeMojibake(value) {
  return /(?:Â.|â[\u0080-\u00bf]{1,2})/.test(value);
}
