"""Export the game for the web into web/ (upload that folder to a website).

    python -X utf8 tools/web_build.py

Steps: make sure the Ogg audio is current, store the big illustrations with
lossy compression (they are paintings; the saving is about 15 MB of download),
re-import, export with the single-threaded web template (which needs no special
server headers), and report the size.
"""

import pathlib
import re
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
WEB = ROOT / "web"

CREDITS = """Valencia: Camino a EUROCALL

Map data (c) OpenStreetMap contributors, Open Database Licence
  https://www.openstreetmap.org/copyright
Illustrations generated with Ideogram 4 under its Non-Commercial Model
  Agreement: this build is for non-commercial use.
Voices generated with Qwen3-TTS.
Fonts: Source Sans 3, Lora and Noto Sans Symbols 2, SIL Open Font Licence 1.1.
Built with Godot Engine (MIT licence), https://godotengine.org/license
"""

sys.path.insert(0, str(ROOT / "tools"))
import encode_audio
from local_config import get

GODOT = get("godot")


def lossy_art():
    changed = 0
    for imp in (GAME / "art").glob("*.png.import"):
        if imp.name.startswith("pin_"):
            continue            # small, and they need a clean alpha edge
        s = imp.read_text(encoding="utf-8")
        t = re.sub(r"compress/mode=\d", "compress/mode=1", s)
        t = re.sub(r"compress/lossy_quality=[\d.]+", "compress/lossy_quality=0.86", t)
        if t != s:
            imp.write_text(t, encoding="utf-8", newline="\n")
            changed += 1
    return changed


def godot(*args):
    r = subprocess.run([GODOT, "--headless", "--path", str(GAME), *args],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    bad = [l for l in (r.stdout + r.stderr).splitlines()
           if ("ERROR" in l or "Parse Error" in l) and "leaked" not in l]
    return r.returncode, bad


def main():
    encode_audio.main()
    print("art switched to lossy:", lossy_art())
    code, bad = godot("--import")
    if bad:
        print("\n".join(bad[:10]))
    # Empty the folder rather than remove it: a local test server may be serving it.
    WEB.mkdir(exist_ok=True)
    for old in WEB.iterdir():
        shutil.rmtree(old) if old.is_dir() else old.unlink()
    code, bad = godot("--export-release", "Web", str(WEB / "index.html"))
    if bad:
        print("\n".join(bad[:15]))
    if not (WEB / "index.html").exists():
        sys.exit("export failed: no index.html")
    (WEB / "CREDITS.txt").write_text(CREDITS, encoding="utf-8")
    files = sorted(WEB.iterdir())
    for f in files:
        print(f"  {f.name:<34} {f.stat().st_size / 1e6:7.2f} MB")
    print(f"web build: {sum(f.stat().st_size for f in files) / 1e6:.1f} MB in {WEB}")


if __name__ == "__main__":
    main()
