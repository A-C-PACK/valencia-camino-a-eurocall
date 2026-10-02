"""Check the generated voice lines without listening to all of them.

    python tools/qa_audio.py              # transcribe on the Spark, list suspect lines
    python tools/qa_audio.py --redo      # also delete and regenerate the suspect lines

Each WAV is transcribed with faster-whisper (inside the open-webui container on
the GPU box, which already has it) and compared with the script. A line is suspect
when the transcript is far from the text, or when its speaking rate is far from
normal -- the two ways a cloned-voice take usually goes wrong (garbled or
repeated words, or a clip cut short).
"""

import difflib
import json
import pathlib
import re
import subprocess
import sys
import unicodedata

ROOT = pathlib.Path(__file__).resolve().parent.parent
VOICE = ROOT / "audio_src" / "voice"
MANIFEST = ROOT / "tools" / "tts_manifest.json"
REPORT = ROOT / "tools" / "qa_report.json"
sys.path.insert(0, str(ROOT / "tools"))
from local_config import spark

REMOTE = "valencia_qa"          # scratch folder in the remote home directory

MIN_SIMILARITY = 0.72
RATE_BOUNDS = (7.0, 26.0)    # characters per second


def sh(cmd):
    return subprocess.run(["bash", "-c", cmd], capture_output=True, text=True, encoding="utf-8")


def norm(text):
    text = unicodedata.normalize("NFD", text.lower())
    text = "".join(c for c in text if unicodedata.category(c) != "Mn")
    return re.sub(r"[^a-z0-9 ]+", " ", text).split()


def transcribe(ids):
    HOST, KEY = spark()
    ssh = f'ssh -o BatchMode=yes -i "{KEY}" {HOST}'
    files = " ".join(f"{i}.wav" for i in ids)
    steps = [
        f'{ssh} "rm -rf {REMOTE} && mkdir -p {REMOTE}"',
        f'cd "{VOICE.as_posix()}" && tar cf - {files} | {ssh} "tar xf - -C {REMOTE}"',
        f'scp -q -o BatchMode=yes -i "{KEY}" "{(ROOT / "tools" / "qa_transcribe.py").as_posix()}" '
        f'{HOST}:{REMOTE}/',
        f'{ssh} "docker exec open-webui rm -rf /tmp/valencia_qa; '
        f'docker cp -q {REMOTE} open-webui:/tmp/valencia_qa"',
    ]
    for step in steps:
        r = sh(step)
        if r.returncode:
            sys.exit(f"failed: {step}\n{r.stderr}")
    r = sh(f'{ssh} "docker exec open-webui python /tmp/valencia_qa/qa_transcribe.py '
           f'/tmp/valencia_qa 2>/dev/null; docker exec open-webui rm -rf /tmp/valencia_qa; '
           f'rm -rf {REMOTE}"')
    if r.returncode or not r.stdout.strip():
        sys.exit(f"transcription failed:\n{r.stderr[-2000:]}")
    return json.loads(r.stdout)


def main():
    manifest = {l["id"]: l for l in json.loads(MANIFEST.read_text(encoding="utf-8"))}
    report = json.loads(REPORT.read_text(encoding="utf-8")) if REPORT.exists() else {}
    have = [i for i in manifest if (VOICE / f"{i}.wav").exists()]
    todo = [i for i in have if i not in report]
    missing = [i for i in manifest if i not in have]
    print(f"{len(manifest)} lines, {len(have)} with audio, {len(todo)} to transcribe")
    if todo:
        report.update(transcribe(todo))
        REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")

    suspects = []
    for i in have:
        want, got = norm(manifest[i]["text"]), norm(report[i]["text"])
        sim = difflib.SequenceMatcher(None, want, got).ratio()
        rate = len(manifest[i]["text"]) / max(report[i]["duration"], 0.1)
        # Very short lines ("Sí.") are scored on rate alone; one misheard word
        # would swing their similarity to zero.
        bad_text = sim < MIN_SIMILARITY and len(want) > 3
        # ...and short lines carry proportionally more leading/trailing silence,
        # so only a long line counts as "too slow".
        too_slow = rate < RATE_BOUNDS[0] and len(manifest[i]["text"]) > 25
        bad_rate = too_slow or rate > RATE_BOUNDS[1]
        if bad_text or bad_rate:
            suspects.append((sim, rate, i))
    for sim, rate, i in sorted(suspects):
        l = manifest[i]
        print(f"\n  {i} {l['who']}  similarity {sim:.2f}  {rate:.1f} chars/s")
        print(f"    script: {l['text']}")
        print(f"    heard : {report[i]['text']}")
    print(f"\n{len(suspects)} suspect, {len(missing)} with no audio yet")

    if "--redo" in sys.argv and suspects:
        for _, _, i in suspects:
            (VOICE / f"{i}.wav").unlink()
            report.pop(i, None)
        REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=1), encoding="utf-8")
        ids = ",".join(i for _, _, i in suspects)
        subprocess.run([sys.executable, "-X", "utf8", str(ROOT / "tools" / "tts_generate.py"),
                        "--fresh", ids])


if __name__ == "__main__":
    main()
