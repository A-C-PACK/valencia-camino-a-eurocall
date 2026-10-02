"""Encode the WAV masters in audio_src/voice/ to Ogg Vorbis in game/audio/voice/.

    python -X utf8 tools/encode_audio.py

The game ships Ogg (about a tenth of the size of WAV, which matters for the web
build); the WAVs stay outside the Godot project so they are never exported.
Only missing or out-of-date files are encoded, and Ogg files whose line no
longer exists are removed.
"""

import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "audio_src" / "voice"
OUT = ROOT / "game" / "audio" / "voice"
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from local_config import get

FFMPEG = get("ffmpeg")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    made = 0
    for wav in sorted(SRC.glob("*.wav")):
        ogg = OUT / (wav.stem + ".ogg")
        if ogg.exists() and ogg.stat().st_mtime >= wav.stat().st_mtime:
            continue
        r = subprocess.run([FFMPEG, "-y", "-hide_banner", "-loglevel", "error", "-i", str(wav),
                            "-ac", "1", "-c:a", "libvorbis", "-q:a", "4", str(ogg)],
                           capture_output=True, text=True)
        if r.returncode:
            sys.exit(f"ffmpeg failed on {wav.name}: {r.stderr[-300:]}")
        made += 1
    removed = 0
    for ogg in OUT.glob("*.ogg"):
        if not (SRC / (ogg.stem + ".wav")).exists():
            ogg.unlink()
            imp = ogg.with_name(ogg.name + ".import")
            if imp.exists():
                imp.unlink()
            removed += 1
    total = sum(f.stat().st_size for f in OUT.glob("*.ogg"))
    print(f"audio: {made} encoded, {removed} removed, "
          f"{len(list(OUT.glob('*.ogg')))} Ogg files, {total / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
