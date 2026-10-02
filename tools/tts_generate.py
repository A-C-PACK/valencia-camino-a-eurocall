"""Voice every line in tools/tts_manifest.json through qwen-tts-studio and drop
the WAV masters in audio_src/voice/<id>.wav, then encode them to Ogg for the game.

    python tools/tts_generate.py            # cast any new voices, generate missing lines
    python tools/tts_generate.py --cast     # only create and lock the voices
    python tools/tts_generate.py --limit 5  # stop after 5 lines (timing test)
    python tools/tts_generate.py --fresh id1,id2   # redo these lines with a new seed

Safe to re-run: a line whose WAV exists is skipped, and tools/tts_state.json
remembers the studio project, each locked character and each row, so an
interrupted run picks up where it stopped. The GPU is serialised on the Spark,
so this works through the lines one at a time on purpose.
"""

import json
import pathlib
import random
import sys
import time
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
BASE = "http://127.0.0.1:7000"
STATE = ROOT / "tools" / "tts_state.json"
MANIFEST = ROOT / "tools" / "tts_manifest.json"
CAST = ROOT / "content" / "cast.json"
OUT = ROOT / "audio_src" / "voice"     # WAV masters; encode_audio.py makes the game's Ogg files
LANG = "spanish"


def call(path, body=None, method=None, raw=False, timeout=900):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(BASE + path, data=data,
                                 method=method or ("POST" if data is not None else "GET"),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        payload = r.read()
    return payload if raw else json.loads(payload.decode("utf-8"))


def load_state():
    if STATE.exists():
        return json.loads(STATE.read_text(encoding="utf-8"))
    return {"slug": None, "chars": {}, "rows": {}}


def save_state(state):
    STATE.write_text(json.dumps(state, indent=1), encoding="utf-8")


def ensure_project(state):
    if state["slug"]:
        return
    project = call("/api/projects", {"name": "Valencia game"})
    state["slug"] = project["slug"]
    call(f"/api/projects/{state['slug']}", {"language": LANG}, method="PATCH")
    save_state(state)
    print(f"created studio project '{state['slug']}'")


def ensure_voice(state, who, spec):
    """Create, audition and lock one character. Every later line is cloned
    from this one reference clip, which is what keeps the voice from drifting."""
    if who in state["chars"]:
        return
    slug = state["slug"]
    char = call(f"/api/projects/{slug}/characters",
                {"name": who, "source": "design", "design_instruct": spec["voice"]})
    body = {"text": spec["ref"], "language": LANG}
    if spec.get("seed"):
        body["seed"] = spec["seed"]
    aud = call(f"/api/projects/{slug}/characters/{char['id']}/audition", body)["audition"]
    call(f"/api/projects/{slug}/characters/{char['id']}/lock",
         {"audition_id": aud["id"], "ref_text": spec["ref"]})
    state["chars"][who] = char["id"]
    save_state(state)
    print(f"  locked {who:<10} {aud.get('duration')}s  seed {aud.get('seed')}")


def voice_line(state, line, fresh=False):
    slug = state["slug"]
    row_id = state["rows"].get(line["id"])
    if not row_id:
        row = call(f"/api/projects/{slug}/rows",
                   {"text": line["text"], "character_id": state["chars"][line["who"]]})
        row_id = row["id"]
        state["rows"][line["id"]] = row_id
        save_state(state)
    # fresh: the existing take was judged bad, so make a new one with a new seed
    # (the newest take becomes the starred one).
    body = {"attempts": 4, "only_missing": not fresh}
    if fresh:
        body["seed"] = random.randint(1, 2**31 - 1)
    call(f"/api/projects/{slug}/rows/{row_id}/generate", body)
    wav = call(f"/api/projects/{slug}/rows/{row_id}/audio", raw=True)
    (OUT / f"{line['id']}.wav").write_bytes(wav)
    return len(wav)


def main():
    limit = int(sys.argv[sys.argv.index("--limit") + 1]) if "--limit" in sys.argv else None
    cast = json.loads(CAST.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    state = load_state()
    ensure_project(state)

    for who in sorted({l["who"] for l in manifest}):
        ensure_voice(state, who, cast[who])
    if "--cast" in sys.argv:
        return

    fresh = set()
    if "--fresh" in sys.argv:      # ids whose existing take should be thrown away
        fresh = set(sys.argv[sys.argv.index("--fresh") + 1].split(","))
    todo = [l for l in manifest if l["id"] in fresh or not (OUT / f"{l['id']}.wav").exists()]
    print(f"{len(manifest)} lines, {len(todo)} to generate")
    done = failed = 0
    start = time.time()
    for line in todo[:limit]:
        t0 = time.time()
        try:
            size = voice_line(state, line, line["id"] in fresh)
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            detail = exc.read().decode("utf-8", "replace")[:200] if hasattr(exc, "read") else exc
            print(f"  FAILED {line['id']} {line['who']}: {detail}")
            failed += 1
            continue
        done += 1
        print(f"  [{done}/{len(todo)}] {time.time() - t0:5.1f}s {size // 1024:>4} KB  "
              f"{line['who']:<9} {line['text'][:60]}", flush=True)
    print(f"done: {done} generated, {failed} failed, {time.time() - start:.0f}s")
    import encode_audio
    encode_audio.main()


if __name__ == "__main__":
    main()
