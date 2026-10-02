// Does the web build actually produce sound? Loads it in headless Chrome, taps
// every AudioContext just before its output, enters the first scene (whose first
// line plays by itself) and reports the signal level there.
//
//   node tools/web_audio_test.mjs [url]

import { spawn } from "node:child_process";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const url = process.argv[2] ?? "http://127.0.0.1:8765/index.html";
const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const PORT = 9334;

// Runs in the page before anything else: route whatever is connected to the
// speakers through an analyser first, so the level can be read back.
const TAP = `(() => {
  const Orig = window.AudioContext || window.webkitAudioContext;
  window.__ctxs = [];
  const Wrapped = function (...a) {
    const c = new Orig(...a);
    c.__an = c.createAnalyser();
    c.__an.fftSize = 2048;
    realConnect.call(c.__an, c.destination);
    window.__ctxs.push(c);
    return c;
  };
  const realConnect = AudioNode.prototype.connect;
  Wrapped.prototype = Orig.prototype;
  window.AudioContext = Wrapped;
  window.webkitAudioContext = Wrapped;
  AudioNode.prototype.connect = function (dest, ...r) {
    const c = this.context;
    if (dest === c.destination && c.__an && this !== c.__an) return realConnect.call(this, c.__an, ...r);
    return realConnect.call(this, dest, ...r);
  };
  window.__level = () => window.__ctxs.map((c) => {
    const b = new Float32Array(2048);
    c.__an.getFloatTimeDomainData(b);
    let s = 0;
    for (const v of b) s += v * v;
    return { state: c.state, rms: Math.sqrt(s / b.length), rate: c.sampleRate };
  });
})();`;

const profile = mkdtempSync(join(tmpdir(), "valencia-audiotest-"));
const chrome = spawn(CHROME, ["--headless=new", `--remote-debugging-port=${PORT}`,
  `--user-data-dir=${profile}`, "--enable-unsafe-swiftshader", "--use-angle=swiftshader",
  "--window-size=1280,720", "about:blank"], { stdio: "ignore" });
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
  if (msg.method === "Runtime.consoleAPICalled" && msg.params.type !== "log")
    logs.push(`[${msg.params.type}] ` + msg.params.args.map((a) => a.value ?? a.description ?? "").join(" "));
  if (msg.method === "Runtime.exceptionThrown")
    logs.push("[exception] " + (msg.params.exceptionDetails.exception?.description ?? msg.params.exceptionDetails.text));
};
const send = (method, params = {}) => new Promise((r) => { pending.set(++id, r); ws.send(JSON.stringify({ id, method, params })); });
const click = async (x, y) => {
  for (const type of ["mouseMoved", "mousePressed", "mouseReleased"])
    await send("Input.dispatchMouseEvent", { type, x, y, button: type === "mouseMoved" ? "none" : "left", clickCount: 1 });
};
const level = async () => (await send("Runtime.evaluate", { expression: "JSON.stringify(window.__level())", returnByValue: true })).result?.value;

await send("Runtime.enable");
await send("Page.enable");
await send("Emulation.setDeviceMetricsOverride", { width: 1280, height: 720, deviceScaleFactor: 1, mobile: false });
await send("Page.addScriptToEvaluateOnNewDocument", { source: TAP });
await send("Page.navigate", { url });
await sleep(25);
console.log("after load      :", await level());
await click(694, 617);          // Empezar el viaje
await sleep(4);
console.log("on the map      :", await level());
await click(1193, 455);         // Entrar: the first line starts playing
let peak = 0;
for (let i = 0; i < 16; i++) {
  await sleep(0.25);
  const l = JSON.parse(await level());
  for (const c of l) peak = Math.max(peak, c.rms);
}
console.log("first line plays:", await level());
console.log("peak level while the line should be playing:", peak.toFixed(4), peak > 0.002 ? "-> SOUND" : "-> SILENT");
console.log("--- warnings and errors ---");
console.log(logs.slice(0, 20).join("\n") || "(none)");
ws.close();
chrome.kill();
process.exit(0);
