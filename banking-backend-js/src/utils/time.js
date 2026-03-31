function nowIso() {
  return new Date().toISOString();
}

function nowIdTs() {
  const d = new Date();
  const pad = (n, w = 2) => String(n).padStart(w, "0");
  return `${d.getUTCFullYear()}${pad(d.getUTCMonth() + 1)}${pad(d.getUTCDate())}T${pad(
    d.getUTCHours()
  )}${pad(d.getUTCMinutes())}${pad(d.getUTCSeconds())}${pad(d.getUTCMilliseconds(), 3)}Z`;
}

function hoursDiff(fromIso) {
  return (Date.now() - new Date(fromIso).getTime()) / (1000 * 60 * 60);
}

module.exports = { nowIso, nowIdTs, hoursDiff };
