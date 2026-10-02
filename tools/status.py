"""Print a progress bar for each part of the game build.

    python -X utf8 tools/status.py
"""

import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from local_config import get

ART =["title", "aeropuerto", "hotel", "metro", "mercado", "horchateria", "catedral",
       "farmacia", "playa", "ciencias", "congreso", "ruzafa", "tablao"]


def bar(label, done, total, note=""):
    width = 30
    filled = round(width * done / total) if total else width
    pct = 100 * done / total if total else 100
    print(f"  {label:<26} [{'█' * filled}{'░' * (width - filled)}] {done:>4}/{total:<4} "
          f"{pct:3.0f}%  {note}")


def rendered_on_spark():
    if not get("spark_host"):
        return None
    cmd = (f'ssh -o BatchMode=yes -o ConnectTimeout=8 -i "{get("spark_key")}" '
           f'{get("spark_user")}@{get("spark_host")} "ls ~/ideogram4/out | grep ^val_.*png"')
    r = subprocess.run(["bash", "-c", cmd], capture_output=True, text=True)
    return {l.strip()[4:-4] for l in r.stdout.splitlines()} if r.returncode == 0 else None


def main():
    content = json.loads((ROOT / "game/data/content.json").read_text(encoding="utf-8"))
    manifest = json.loads((ROOT / "tools/tts_manifest.json").read_text(encoding="utf-8"))
    voice = ROOT / "audio_src/voice"
    have = [l for l in manifest if (voice / f"{l['id']}.wav").exists()]
    report_path = ROOT / "tools/qa_report.json"
    report = json.loads(report_path.read_text(encoding="utf-8")) if report_path.exists() else {}
    checked = [l for l in have if l["id"] in report]
    state_path = ROOT / "tools/tts_state.json"
    state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {}
    speakers = {l["who"] for l in manifest}
    scenes = sum(len(l["scenes"]) for l in content["locations"])
    local_art = [a for a in ART if (ROOT / f"game/art/val_{a}.png").exists()]
    spark = rendered_on_spark()

    print("\nValencia: Camino a EUROCALL — build status\n")
    bar("Scenes written", scenes, 24)
    bar("Voices cast", len(speakers & set(state.get("chars", {}))), len(speakers))
    bar("Voice lines recorded", len(have), len(manifest))
    bar("Voice lines checked", len(checked), len(manifest), "(transcribed and compared)")
    if spark is None:
        print("  Illustrations rendered      (GPU box not configured or not reachable)")
    else:
        bar("Illustrations rendered", len(spark & set(ART)), len(ART), "(on the Spark)")
    bar("Illustrations in the game", len(local_art), len(ART))
    missing = [a for a in ART if a not in local_art]
    if missing:
        print(f"\n  art still to come: {', '.join(missing)}")
    print()


if __name__ == "__main__":
    main()
