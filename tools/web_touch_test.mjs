// Drive the web build the way a phone does: a landscape phone-sized window and
// real touch events (taps, a two-finger pinch, a one-finger drag) sent over the
// DevTools protocol. Saves a screenshot after each step and prints the zoom the
// game reports.
//
//   python -m http.server 8765 --bind 127.0.0.1   (in web/)
//   node tools/web_touch_test.mjs <output folder>

import { spawn } from "node:child_process";
import { writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const out = process.argv[2] ?? ".";
const url = process.argv[3] ?? "http://127.0.0.1:8765/index.html";
const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const PORT = 9334;
const W = 844, H = 390;                       // a phone held sideways, in CSS pixels
const SCALE = Math.min(W / 1280, H / 720);
// game pixels (1280x720) -> where that lands in the window
const g = (x, y) => ({ x: (W - 1280 * SCALE) / 2 + x * SCALE, y: (H - 720 * SCALE) / 2 + y * SCALE });

const profile = mkdtempSync(join(tmpdir(), "valencia-touchtest-"));
const chrome = spawn(CHROME, ["--headless=new", `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${profile}`, "--enable-unsafe-swiftshader", "--use-angle=swiftshader",
  `--window-size=${W},${H}`, "--hide-scrollbars", "--autoplay-policy=no-user-gesture-required",
  "about:blank"], { stdio: "ignore" });

const sleep = (s) => new Promise((r) => setTimeout(r, s * 1000));

async function target() {
  for (let i = 0; i < 40; i++) {
    try {
      const list = await (await fetch(`http://127.0.0.1:${PORT}/json`)).json();
      const page = list.find((t) => t.type === "page");
      if (page) return page.webSocketDebuggerUrl;
    } catch {}
    await sleep(0.5);
  }
  throw new Error("Chrome did not start");
}

const ws = new WebSocket(await target());
await new Promise((r) => (ws.onopen = r));
let id = 0;
const pending = new Map();
const logs = [];
ws.onmessage = (m) => {
  const msg = JSON.parse(m.data);
  if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg.result ?? msg.error); pending.delete(msg.id); }
  if (msg.method === "Runtime.consoleAPICalled")
    logs.push(`[${msg.params.type}] ` + msg.params.args.map((a) => a.value ?? a.description ?? "").join(" "));
  if (msg.method === "Runtime.exceptionThrown")
    logs.push("[exception] " + (msg.params.exceptionDetails.exception?.description ?? msg.params.exceptionDetails.text));
};
const send = (method, params = {}) => new Promise((r) => { pending.set(++id, r); ws.send(JSON.stringify({ id, method, params })); });

await send("Runtime.enable");
await send("Page.enable");
await send("Emulation.setDeviceMetricsOverride", { width: W, height: H, deviceScaleFactor: 2, mobile: true });
await send("Emulation.setTouchEmulationEnabled", { enabled: true, maxTouchPoints: 5 });
await send("Page.navigate", { url });

const touch = (type, points) => send("Input.dispatchTouchEvent",
  { type, touchPoints: points.map((p, i) => ({ x: p.x, y: p.y, id: p.id ?? i })) });

async function tap(x, y) {
  await touch("touchStart", [g(x, y)]);
  await sleep(0.08);
  await touch("touchEnd", []);
}

// fingers: [[from, to], ...] in game pixels; the first finger lands a moment before the others
async function gesture(fingers, steps = 10) {
  const at = (t) => fingers.map(([a, b], i) =>
    ({ ...g(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), id: i }));
  await touch("touchStart", at(0).slice(0, 1));
  await sleep(0.06);
  if (fingers.length > 1) {
    await touch("touchStart", at(0));
    await sleep(0.06);
  }
  for (let n = 1; n <= steps; n++) {
    await touch("touchMove", at(n / steps));
    await sleep(0.04);
  }
  await touch("touchEnd", []);
}

async function shot(name) {
  const s = await send("Page.captureScreenshot", { format: "png" });
  writeFileSync(join(out, name + ".png"), Buffer.from(s.data, "base64"));
  console.log("saved", name);
}

await sleep(25);
await tap(1155, 523);                      // part 2: Empezar a leer
await sleep(5);
await tap(1237, 511);                      // Leer (first reading)
await sleep(5);
await shot("touch_1_scene");

await gesture([[[800, 300], [650, 200]], [[900, 380], [1050, 480]]]);   // two fingers spread
await sleep(1.5);
await shot("touch_2_pinch");

await gesture([[[900, 400], [400, 400]]]);  // one finger drags left: the view should move right
await sleep(1.5);
await shot("touch_3_drag_left");

await gesture([[[700, 500], [700, 150]]]);  // one finger drags up: the view should move down
await sleep(1.5);
await shot("touch_4_drag_up");

await tap(38, 398);                         // the - button (it does not move with the zoom)
await sleep(1);
await gesture([[[800, 300], [860, 340]], [[1000, 440], [940, 400]]]);   // pinch back in
await sleep(1.5);
await shot("touch_5_pinch_in");

console.log("--- page console ---");
console.log(logs.filter((l) => !/^\[log\]\s*$/.test(l)).slice(0, 40).join("\n") || "(nothing logged)");
ws.close();
chrome.kill();
process.exit(0);
