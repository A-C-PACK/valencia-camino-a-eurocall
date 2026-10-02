"""Repackage the web build (web/) so it can be published as a claude.ai Artifact.

    python -X utf8 tools/artifact_build.py

An Artifact's supporting files are capped at 15 MB each, and the engine
(index.wasm, ~40 MB) and game data (index.pck, ~16 MB) are bigger than that. So
both are cut into parts, and the page carries a small fetch() shim that hands
the engine the parts joined back together. Output goes to artifact/:
valencia.html (the page), the engine scripts, and the parts. files.json lists
what to publish alongside the page.
"""

import json
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
OUT = ROOT / "artifact"
PART = 12 * 1024 * 1024

PAGE = """<title>Valencia: Camino a EUROCALL</title>
<style>
/* Layout: the game canvas fills the viewport; a loading card sits centred over it until the engine starts. */
:root {
  --bg: #f6e7c8;
  --ink: #1f3a4d;
  --accent: #d9622b;
  --muted: #6b7780;
  --track: #e2cf9f;
  --display: Georgia, "Times New Roman", serif;
  --body: "Segoe UI", system-ui, -apple-system, "Helvetica Neue", Arial, sans-serif;
  color-scheme: light;
}
html, body { height: 100%; }
body { background: var(--bg); color: var(--ink); font-family: var(--body); overflow: hidden; }
#canvas { display: block; width: 100%; height: 100%; outline: none; background: var(--bg); }
#status {
  position: fixed; inset: 0; display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: 14px; padding-inline: 16px; background: var(--bg);
  text-align: center;
}
#status .kicker { font-size: 0.8rem; letter-spacing: 0.14em; text-transform: uppercase;
  color: var(--accent); font-weight: 700; }
#status h1 { font-family: var(--display); font-size: clamp(2.6rem, 9vw, 4.6rem); margin: 0;
  line-height: 1; text-wrap: balance; }
#status p { margin: 0; color: var(--muted); max-width: 34rem; }
#status-progress { width: min(22rem, 80vw); height: 10px; accent-color: var(--accent); }
#status-notice { color: var(--accent); font-weight: 600; max-width: 36rem; }
</style>

<canvas id="canvas" tabindex="0">Tu navegador no puede mostrar el juego.</canvas>
<div id="status">
  <div class="kicker">Camino a EUROCALL</div>
  <h1>Valencia</h1>
  <p id="status-text">Cargando el juego: unos 55 MB la primera vez.</p>
  <progress id="status-progress"></progress>
  <div id="status-notice"></div>
</div>

<script>
// The engine and the game data are published in parts (each under the file-size
// cap). When the engine asks for the whole file, fetch the parts and join them.
const PARTS = __PARTS__;
const plainFetch = window.fetch.bind(window);
window.fetch = async function (input, init) {
  const url = typeof input === "string" ? input : input.url;
  const name = url.split("/").pop().split("?")[0];
  if (!PARTS[name]) return plainFetch(input, init);
  const buffers = await Promise.all(PARTS[name].map(async (part) => {
    const r = await plainFetch(part);
    if (!r.ok) throw new Error("No se pudo cargar " + part + " (" + r.status + ")");
    return r.arrayBuffer();
  }));
  const type = name.endsWith(".wasm") ? "application/wasm" : "application/octet-stream";
  const blob = new Blob(buffers, { type });
  return new Response(blob, { status: 200, headers: { "Content-Type": type, "Content-Length": String(blob.size) } });
};
</script>
<script src="index.js"></script>
<script>
const GODOT_CONFIG = __CONFIG__;
(function () {
  const overlay = document.getElementById("status");
  const progress = document.getElementById("status-progress");
  const notice = document.getElementById("status-notice");
  const text = document.getElementById("status-text");
  function fail(err) {
    console.error(err);
    progress.hidden = true;
    text.hidden = true;
    notice.textContent = "El juego no ha podido arrancar: " + (err && err.message ? err.message : String(err));
  }
  if (typeof Engine === "undefined") { fail(new Error("no se cargó el motor (index.js)")); return; }
  const missing = Engine.getMissingFeatures({ threads: false });
  if (missing.length) { fail(new Error("faltan funciones del navegador: " + missing.join(", "))); return; }
  const engine = new Engine(GODOT_CONFIG);
  engine.startGame({
    onProgress: function (current, total) {
      if (current > 0 && total > 0) { progress.value = current; progress.max = total; }
      else { progress.removeAttribute("value"); progress.removeAttribute("max"); }
    },
  }).then(function () { overlay.remove(); }, fail);
}());
</script>
"""


def main():
    OUT.mkdir(exist_ok=True)
    for old in OUT.iterdir():
        old.unlink()
    shell = (WEB / "index.html").read_text(encoding="utf-8")
    start = shell.index("const GODOT_CONFIG = ") + len("const GODOT_CONFIG = ")
    config = shell[start:shell.index(";\n", start)]

    files, parts = {}, {}
    for name in ("index.js", "index.audio.worklet.js", "index.audio.position.worklet.js"):
        shutil.copy(WEB / name, OUT / name)
        files[name] = name
    for name, ctype in (("index.wasm", "application/wasm"), ("index.pck", "application/octet-stream")):
        data = (WEB / name).read_bytes()
        parts[name] = []
        # Artifacts only serve known file types; raw data parts travel as .wasm
        # (the shim reads them as plain bytes, so the label does not matter).
        ext = "wasm"
        for i in range(0, len(data), PART):
            part = f"{name.replace('.', '_')}_{i // PART}.{ext}"
            (OUT / part).write_bytes(data[i:i + PART])
            parts[name].append(part)
            files[part] = {"from": part, "contentType": "application/wasm"}

    page = PAGE.replace("__PARTS__", json.dumps(parts)).replace("__CONFIG__", config)
    (OUT / "valencia.html").write_text(page, encoding="utf-8", newline="\n")
    (OUT / "files.json").write_text(json.dumps(files, indent=1), encoding="utf-8")
    # A stand-in for the publish skeleton, to test the page locally before publishing.
    (OUT / "_local_test.html").write_text(
        "<!doctype html><html><head><meta charset='utf-8'>"
        "<meta name='viewport' content='width=device-width, initial-scale=1'>"
        "<style>body{margin:0}</style></head><body>" + page + "</body></html>", encoding="utf-8")
    total = sum(f.stat().st_size for f in OUT.iterdir())
    print(f"artifact: {len(files)} supporting files, {total / 1e6:.1f} MB")
    for k, v in parts.items():
        print(f"  {k}: {len(v)} parts")


if __name__ == "__main__":
    main()
