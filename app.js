const DATA_URL = "dati.json";
const REFRESH_MS = 60000;

const $ = (id) => document.getElementById(id);

function formatNumber(value) {
  if (value === null || value === undefined || Number.isNaN(Number(value))) return "--";
  return Number(value).toLocaleString("it-IT", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

async function loadData() {
  const res = await fetch(`${DATA_URL}?t=${Date.now()}`, { cache: "no-store" });
  if (!res.ok) throw new Error(`Errore caricamento dati: ${res.status}`);
  return res.json();
}

function updateCards(data) {
  $("efficienza").textContent = formatNumber(data.efficienza_mensile);
  $("mediaGiornaliera").textContent = formatNumber(data.media_giornaliera);
  $("ultimoAggiornamento").textContent = data.ultimo_aggiornamento || "--";
  $("foglioReport").textContent = data.foglio_report || "--";
  $("foglioColli").textContent = data.foglio_colli || "--";
}

function drawChart(points) {
  const svg = $("lineChart");
  const empty = $("emptyState");
  svg.innerHTML = "";

  if (!points || points.length === 0) {
    empty.classList.add("show");
    return;
  }
  empty.classList.remove("show");

  const W = 1000, H = 420;
  const margin = { top: 34, right: 44, bottom: 70, left: 74 };
  const cw = W - margin.left - margin.right;
  const ch = H - margin.top - margin.bottom;

  const values = points.map(p => Number(p.media)).filter(v => !Number.isNaN(v));
  const maxVal = Math.max(10, Math.ceil(Math.max(...values) / 10) * 10);
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

  // grid and y labels
  const gridLines = 4;
  for (let i = 0; i <= gridLines; i++) {
    const val = minVal + (maxVal - minVal) * i / gridLines;
    const yy = y(val);
    add("line", { x1: margin.left, y1: yy, x2: W - margin.right, y2: yy, class: "grid" });
    add("text", { x: margin.left - 16, y: yy + 7, class: "tick", "text-anchor": "end" }, Math.round(val).toString());
  }

  add("line", { x1: margin.left, y1: margin.top, x2: margin.left, y2: H - margin.bottom, class: "axis" });
  add("line", { x1: margin.left, y1: H - margin.bottom, x2: W - margin.right, y2: H - margin.bottom, class: "axis" });

  const linePath = points.map((p, i) => `${i === 0 ? "M" : "L"}${x(i)},${y(p.media)}`).join(" ");
  const areaPath = `${linePath} L${x(points.length - 1)},${H - margin.bottom} L${x(0)},${H - margin.bottom} Z`;

  add("path", { d: areaPath, class: "area" });
  add("path", { d: linePath, class: "line" });

  points.forEach((p, i) => {
    const xx = x(i);
    const yy = y(p.media);
    add("circle", { cx: xx, cy: yy, r: 7, class: "point" });
    add("text", { x: xx, y: H - margin.bottom + 38, class: "tick", "text-anchor": "middle" }, p.ora);
    add("text", { x: xx, y: yy - 16, class: "point-label", "text-anchor": "middle" }, formatNumber(p.media));
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
