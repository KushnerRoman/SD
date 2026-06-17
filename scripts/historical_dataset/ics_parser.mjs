export function unfoldIcsLines(text) {
  const rawLines = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n").split("\n");
  const lines = [];

  for (const line of rawLines) {
    if (/^[ \t]/.test(line) && lines.length > 0) {
      lines[lines.length - 1] += line.slice(1);
    } else if (line.length > 0) {
      lines.push(line);
    }
  }

  return lines;
}

export function decodeIcsText(value = "") {
  return value
    .replace(/\\n/gi, "\n")
    .replace(/\\,/g, ",")
    .replace(/\\;/g, ";")
    .replace(/\\\\/g, "\\")
    .trim();
}

export function parseIcsDate(value) {
  const cleaned = value.trim();
  const match = cleaned.match(/^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})(Z)?)?$/);
  if (!match) {
    return null;
  }

  const [, year, month, day, hour = "00", minute = "00", second = "00", utc] = match;
  if (utc) {
    return new Date(Date.UTC(Number(year), Number(month) - 1, Number(day), Number(hour), Number(minute), Number(second)));
  }

  return new Date(Number(year), Number(month) - 1, Number(day), Number(hour), Number(minute), Number(second));
}

function parsePropertyLine(line) {
  const separatorIndex = line.indexOf(":");
  if (separatorIndex === -1) {
    return null;
  }

  const rawName = line.slice(0, separatorIndex);
  const value = line.slice(separatorIndex + 1);
  const [name] = rawName.split(";");

  return {
    name: name.toUpperCase(),
    value,
  };
}

function getProperty(properties, name) {
  return properties.get(name)?.[0] ?? "";
}

export function parseIcsEvents(text) {
  const lines = unfoldIcsLines(text);
  const events = [];
  let current = null;

  for (const line of lines) {
    if (line === "BEGIN:VEVENT") {
      current = [];
      continue;
    }

    if (line === "END:VEVENT") {
      if (current) {
        events.push(current);
      }
      current = null;
      continue;
    }

    if (current) {
      current.push(line);
    }
  }

  return events.map((eventLines, index) => {
    const properties = new Map();
    for (const line of eventLines) {
      const property = parsePropertyLine(line);
      if (!property) {
        continue;
      }
      if (!properties.has(property.name)) {
        properties.set(property.name, []);
      }
      properties.get(property.name).push(property.value);
    }

    const startDate = parseIcsDate(getProperty(properties, "DTSTART"));
    const endDate = parseIcsDate(getProperty(properties, "DTEND"));

    return {
      calendarEventId: `cal_${String(index + 1).padStart(4, "0")}`,
      uid: decodeIcsText(getProperty(properties, "UID")),
      startDateTime: startDate ? startDate.toISOString() : "",
      endDateTime: endDate ? endDate.toISOString() : "",
      summary: decodeIcsText(getProperty(properties, "SUMMARY")),
      location: decodeIcsText(getProperty(properties, "LOCATION")),
      description: decodeIcsText(getProperty(properties, "DESCRIPTION")),
      rawEvent: eventLines.join("\r\n").trim(),
    };
  });
}
