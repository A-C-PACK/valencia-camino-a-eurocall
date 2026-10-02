// Load the web build in a headless Chrome over the DevTools protocol, click
// through a few screens, and save screenshots plus anything the page logged.
//
//   python -m http.server 8765 --bind 127.0.0.1   (in web/)
//   node tools/web_test.mjs <output folder>
//
// Each step is "optionally click at x,y or drag from one point to another,
// wait N seconds, screenshot as name".

import { spawn } from "node:child_process";
import { writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const out = process.argv[2] ?? ".";
const url = process.argv[3] ?? "http://127.0.0.1:8765/index.html";
const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const PORT = 9333;
const steps = [
  { wait: 25, name: "web_title" },
  { click: [1155, 523], wait: 5, name: "web_map" },         // part 2: Empezar a leer
  { click: [1237, 511], wait: 5, name: "web_scene" },       // Leer (first reading)
  { click: [1163, 668], wait: 4, name: "web_scene2" },      // Continuar
  { click: [38, 323], wait: 2, name: "web_zoom" },          // the + zoom button
  { drag: [[900, 400], [500, 250]], wait: 2, name: "web_zoom_drag" },   // mouse drag moves the view
  { click: [38, 398], wait: 2, name: "web_zoom_out" },      // and back out with -
];

const profile = mkdtempSync(join(tmpdir(), "valencia-webtest-"));
const chrome = spawn(CHROME, ["--headless=new", `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${profile}`, "--enable-unsafe-swiftshader", "--use-angle=swiftshader",
  "--window-size=1280,720", "--hide-scrollbars", "--autoplay-policy=no-user-gesture-required",
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
  if (msg.method === "Network.loadingFailed")
    logs.push("[network failed] " + msg.params.errorText);
};
const send = (method, params = {}) => new Promise((r) => { pending.set(++id, r); ws.send(JSON.stringify({ id, method, params })); });

await send("Runtime.enable");
await send("Network.enable");
await send("Page.enable");
await send("Emulation.setDeviceMetricsOverride", { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
await send("Page.navigate", { url });

for (const s of steps) {
  if (s.click) {
    const [x, y] = s.click;
    for (const type of ["mouseMoved", "mousePressed", "mouseReleased"])
      await send("Input.dispatchMouseEvent", { type, x, y, button: type === "mouseMoved" ? "none" : "left", clickCount: 1 });
  }
  if (s.drag) {
    const [[x0, y0], [x1, y1]] = s.drag;
    await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: x0, y: y0, button: "none" });
    await send("Input.dispatchMouseEvent", { type: "mousePressed", x: x0, y: y0, button: "left", buttons: 1, clickCount: 1 });
    for (let n = 1; n <= 10; n++) {
      await send("Input.dispatchMouseEvent", { type: "mouseMoved", x: x0 + (x1 - x0) * n / 10,
        y: y0 + (y1 - y0) * n / 10, button: "left", buttons: 1 });
      await sleep(0.04);
    }
    await send("Input.dispatchMouseEvent", { type: "mouseReleased", x: x1, y: y1, button: "left", clickCount: 1 });
  }
  await sleep(s.wait);
  const shot = await send("Page.captureScreenshot", { format: "png" });
  writeFileSync(join(out, s.name + ".png"), Buffer.from(shot.data, "base64"));
  console.log("saved", s.name);
}
console.log("--- page console ---");
console.log(logs.filter((l) => !/^\[log\]\s*$/.test(l)).slice(0, 40).join("\n") || "(nothing logged)");
ws.close();
chrome.kill();
process.exit(0);
