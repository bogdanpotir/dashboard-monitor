const DATA_URL = "dati.json";
const REFRESH_MS = 60000;
const MEDIA_TARGET = 110;
const MEDIA_FULL_SCALE_PERCENT = 10; // -10% rosso pieno, +10% verde pieno

const $ = (id) => document.getElementById(id);

const COLORS = {
  base: [14, 116, 144],
  red: [185, 28, 28],
  green: [21, 128, 61],
  textRed: "#fecaca",
  textGreen: "#bbf7d0",
  textBase: "#e0f2fe"
};

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function mixColor(a, b, t) {
  const r = Math.round(a[0] + (b[0] - a[0]) * t);
  const g = Math.round(a[1] + (b[1] - a[1]) * t);
  const bl = Math.round(a[2] + (b[2] - a[2]) * t);
  return [r, g, bl];
}

function rgb(c, alpha = 1) {
  return `rgba(${c[0]}, ${c[1]}, ${c[2]}, ${alpha})`;
}

function mediaDeltaPercent(value) {
  const n = Number(value);
  if (Number.isNaN(n)) return null;
  return ((n - MEDIA_TARGET) / MEDIA_TARGET) * 100;
}

function colorForMedia(value) {
  const delta = mediaDeltaPercent(value);
  if (delta === null) return COLORS.base;

  const strength = clamp(Math.abs(delta) / MEDIA_FULL_SCALE_PERCENT, 0, 1);
  if (delta < 0) return mixColor(COLORS.base, COLORS.red, strength);
  if (delta > 0) return mixColor(COLORS.base, COLORS.green, strength);
  return COLORS.base;
}

function textColorForMedia(value) {
  const delta = mediaDeltaPercent(value);
  if (delta === null) return COLORS.textBase;
  if (delta < -0.05) return COLORS.textRed;
  if (delta > 0.05) return COLORS.textGreen;
  return COLORS.textBase;
}

function formatNumber(value) {
  if (value === null || value === undefined || Number.isNaN(Number(value))) return "--";
  return Number(value).toLocaleString("it-IT", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

function formatDelta(value) {
  const delta = mediaDeltaPercent(value);
  if (delta === null) return "--";
  const sign = delta > 0 ? "+" : "";
  return `${sign}${delta.toLocaleString("it-IT", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}%`;
}

function formatDateFromSheetName(sheetName) {
  const raw = String(sheetName || "").trim();
  const m = raw.match(/^(\d{2})-(\d{2})-(\d{4})$/);
  if (m) return `${m[1]}/${m[2]}/${m[3]}`;
  return new Date().toLocaleDateString("it-IT", { day: "2-digit", month: "2-digit", year: "numeric" });
}

async function loadData() {
  const res = await fetch(`${DATA_URL}?t=${Date.now()}`, { cache: "no-store" });
  if (!res.ok) throw new Error(`Errore caricamento dati: ${res.status}`);
  return res.json();
}

function updateDynamicCard(cardId, value, deltaId) {
  const card = $(cardId);
  const n = Number(value);
  const c = colorForMedia(n);
  const deltaTextColor = textColorForMedia(n);

  if (!Number.isNaN(n)) {
    card.style.setProperty("--metric-main", rgb(c, 0.44));
    card.style.setProperty("--metric-soft", rgb(c, 0.18));
    card.style.setProperty("--metric-border", rgb(c, 0.55));
    card.style.setProperty("--metric-glow", rgb(c, 0.18));
  }

  $(deltaId).textContent = formatDelta(value);
  $(deltaId).style.color = deltaTextColor;
}

function updateCards(data) {
  const mediaGiornaliera = data.media_giornaliera;
  const mediaMensilePk = data.media_mensile_pk;

  $("efficienza").textContent = formatNumber(data.efficienza_mensile);
  $("mediaGiornaliera").textContent = formatNumber(mediaGiornaliera);
  $("mediaMensilePk").textContent = formatNumber(mediaMensilePk);

  updateDynamicCard("mediaCard", mediaGiornaliera, "scostamentoMedia");
  updateDynamicCard("mediaMensileCard", mediaMensilePk, "scostamentoMediaMensile");

  $("ultimoAggiornamento").textContent = data.ultimo_aggiornamento || "--";
  $("foglioReport").textContent = data.foglio_report || "--";
  $("foglioReportMedia").textContent = data.foglio_report || "--";
  $("foglioColli").textContent = data.foglio_colli || "--";
  $("dataGiorno").textContent = formatDateFromSheetName(data.foglio_colli);
}

function normalizeTrend(points) {
  if (!Array.isArray(points)) return [];

  const cleaned = points
    .map((p) => ({
      ora: String(p.ora || "").trim(),
      media: Number(p.media)
    }))
    .filter((p) => p.ora !== "" && !Number.isNaN(p.media));

  const lastRealIndex = cleaned.reduce((last, p, i) => p.media > 0 ? i : last, -1);
  if (lastRealIndex === -1) return [];

  return cleaned.slice(0, lastRealIndex + 1);
}

function drawChart(rawPoints) {
  const points = normalizeTrend(rawPoints);
  const svg = $("lineChart");
  const empty = $("emptyState");
  svg.innerHTML = "";

  if (!points || points.length === 0) {
    empty.classList.add("show");
    return;
  }
  empty.classList.remove("show");

  const W = 1100, H = 430;
  const margin = { top: 48, right: 48, bottom: 96, left: 82 };
  const cw = W - margin.left - margin.right;
  const ch = H - margin.top - margin.bottom;

  const values = points.map(p => Number(p.media)).filter(v => !Number.isNaN(v));
  const maxData = Math.max(...values, MEDIA_TARGET);
  const maxVal = Math.max(120, Math.ceil((maxData + 8) / 10) * 10);
  const minVal = 0;

  const x = (i) => margin.left + (points.length === 1 ? cw / 2 : (i * cw / (points.length - 1)));
  const y = (v) => margin.top + ch - ((Number(v) - minVal) / (maxVal - minVal || 1)) * ch;

  function add(tag, attrs = {}, text = "") {
    const el = document.createElementNS("http://www.w3.org/2000/svg", tag);
    Object.entries(attrs).forEach(([k, v]) => el.setAttribute(k, v));
    if (text !== "") el.textContent = text;
    svg.appendChild(el);
    return el;
  }

  const gridLines = 4;
  for (let i = 0; i <= gridLines; i++) {
    const val = minVal + (maxVal - minVal) * i / gridLines;
    const yy = y(val);
    add("line", { x1: margin.left, y1: yy, x2: W - margin.right, y2: yy, class: "grid" });
    add("text", { x: margin.left - 16, y: yy + 6, class: "tick", "text-anchor": "end" }, Math.round(val).toString());
  }

  const targetY = y(MEDIA_TARGET);
  if (targetY >= margin.top && targetY <= H - margin.bottom) {
    add("line", { x1: margin.left, y1: targetY, x2: W - margin.right, y2: targetY, class: "target-line" });
    add("text", { x: W - margin.right - 8, y: targetY - 10, class: "target-label", "text-anchor": "end" }, `Target ${MEDIA_TARGET}`);
  }

  add("text", { x: 18, y: margin.top + 12, class: "axis-title", transform: `rotate(-90 18 ${margin.top + 12})` }, "Media/h");
  add("line", { x1: margin.left, y1: margin.top, x2: margin.left, y2: H - margin.bottom, class: "axis" });
  add("line", { x1: margin.left, y1: H - margin.bottom, x2: W - margin.right, y2: H - margin.bottom, class: "axis" });

  const linePath = points.map((p, i) => `${i === 0 ? "M" : "L"}${x(i)},${y(p.media)}`).join(" ");
  const areaPath = `${linePath} L${x(points.length - 1)},${H - margin.bottom} L${x(0)},${H - margin.bottom} Z`;
  add("path", { d: areaPath, class: "area" });

  for (let i = 0; i < points.length - 1; i++) {
    const avgSegment = (points[i].media + points[i + 1].media) / 2;
    const c = colorForMedia(avgSegment);
    add("line", {
      x1: x(i),
      y1: y(points[i].media),
      x2: x(i + 1),
      y2: y(points[i + 1].media),
      class: "line-segment",
      style: `stroke: ${rgb(c, 1)}`
    });
  }

  const tickStep = points.length > 14 ? 3 : points.length > 10 ? 2 : 1;
  const labelStep = points.length > 12 ? 3 : points.length > 8 ? 2 : 1;
  const maxValue = values.length ? Math.max(...values) : null;
  const maxIndex = maxValue === null ? -1 : points.findIndex(p => Number(p.media) === maxValue);
  const lastIndex = points.length - 1;

  points.forEach((p, i) => {
    const xx = x(i);
    const yy = y(p.media);
    const pointColor = colorForMedia(p.media);

    add("circle", { cx: xx, cy: yy, r: 7, class: "point", style: `fill: ${rgb(pointColor, 1)}` });

    if (i === 0 || i === lastIndex || i % tickStep === 0) {
      add("text", {
        x: xx,
        y: H - margin.bottom + 42,
        class: "tick-x",
        "text-anchor": "end",
        transform: `rotate(-38 ${xx} ${H - margin.bottom + 42})`
      }, p.ora);
    }

    const shouldShowValue = p.media > 0 && (points.length <= 8 || i % labelStep === 0 || i === maxIndex || i === lastIndex);
    if (shouldShowValue) {
      const offset = i % 2 === 0 ? -18 : 26;
      add("text", {
        x: xx,
        y: yy + offset,
        class: "point-label",
        "text-anchor": "middle"
      }, formatNumber(p.media));
    }
  });
}

async function refresh() {
  try {
    const data = await loadData();
    updateCards(data);
    drawChart(data.trend_orario || []);
    $("statusDot").className = "dot ok";
    $("statusText").textContent = "Dati aggiornati";
  } catch (err) {
    console.error(err);
    $("statusDot").className = "dot err";
    $("statusText").textContent = "Errore dati";
  }
}

refresh();
setInterval(refresh, REFRESH_MS);
