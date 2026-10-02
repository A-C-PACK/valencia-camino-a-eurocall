// Can you type into the game's text boxes in the browser? Opens the cuaderno,
// clicks its search box, types, and saves a screenshot. Also reports which
// element has keyboard focus at each point.
//
//   node tools/web_type_test.mjs <out folder> [url] [touch]

import { spawn } from "node:child_process";
import { writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const out = process.argv[2] ?? ".";
const url = process.argv[3] ?? "http://127.0.0.1:8765/index.html";
const touch = process.argv[4] === "touch";
const CHROME = "C:/Program Files/Google/Chrome/Application/chrome.exe";
const PORT = 9335;

const profile = mkdtempSync(join(tmpdir(), "valencia-typetest-"));
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
ws.onmessage = (m) => {
  const msg = JSON.parse(m.data);
  if (msg.id && pending.has(msg.id)) { pending.get(msg.id)(msg.result ?? msg.error); pending.delete(msg.id); }
};
const send = (method, params = {}) => new Promise((r) => { pending.set(++id, r); ws.send(JSON.stringify({ id, method, params })); });
const click = async (x, y) => {
  if (touch) {
    await send("Input.dispatchTouchEvent", { type: "touchStart", touchPoints: [{ x, y }] });
    await send("Input.dispatchTouchEvent", { type: "touchEnd", touchPoints: [] });
    return;
  }
  for (const type of ["mouseMoved", "mousePressed", "mouseReleased"])
    await send("Input.dispatchMouseEvent", { type, x, y, button: type === "mouseMoved" ? "none" : "left", clickCount: 1 });
};
const focus = async () => (await send("Runtime.evaluate", {
  expression: "(document.activeElement ? document.activeElement.tagName + '#' + document.activeElement.id : 'none') + ' hasFocus=' + document.hasFocus()",
  returnByValue: true })).result?.value;
const shot = async (name) => {
  const s = await send("Page.captureScreenshot", { format: "png" });
  writeFileSync(join(out, name + ".png"), Buffer.from(s.data, "base64"));
};

await send("Runtime.enable");
await send("Page.enable");
await send("Emulation.setDeviceMetricsOverride", { width: 1280, height: 720, deviceScaleFactor: 1, mobile: touch });
if (touch) await send("Emulation.setTouchEmulationEnabled", { enabled: true });
await send("Page.navigate", { url });
await sleep(25);
console.log("focus after load:", await focus());
await click(907, 617);            // Mi cuaderno
await sleep(3);
await click(650, 143);            // the search box
await sleep(1);
console.log("focus after clicking the box:", await focus());
for (const ch of "hola") {
  const code = "Key" + ch.toUpperCase();
  await send("Input.dispatchKeyEvent", { type: "keyDown", key: ch, code, text: ch, windowsVirtualKeyCode: ch.toUpperCase().charCodeAt(0) });
  await send("Input.dispatchKeyEvent", { type: "keyUp", key: ch, code, windowsVirtualKeyCode: ch.toUpperCase().charCodeAt(0) });
  await sleep(0.1);
}
await sleep(1);
await shot("type_test" + (touch ? "_touch" : ""));
console.log("saved screenshot");
ws.close();
chrome.kill();
process.exit(0);
