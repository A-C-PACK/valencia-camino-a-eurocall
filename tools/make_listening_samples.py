"""Build three "harder listening" demo clips in samples/, each next to its clean
original, to hear what realistic conditions would do to the game's audio.

    python -X utf8 tools/make_listening_samples.py

1. market   -- an existing price line, 12% faster, under crowd babble
2. metro    -- an existing announcement through a tinny PA with echo and train rumble
3. colloquial -- a NEW, faster and more colloquial line (generated here), under babble

The babble is made from the game's own recordings: several voices layered and
muffled, so no outside sound files are needed.
"""

import json
import pathlib
import random
import subprocess
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import tts_generate as tts

ROOT = pathlib.Path(__file__).resolve().parent.parent
VOICE = ROOT / "audio_src" / "voice"
OUT = ROOT / "samples"
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from local_config import get

FFMPEG = get("ffmpeg")

MARKET_LINE = "f546e6ca7161"      # Amparo: zumo vs mesa, 1,80 / 2,50
METRO_LINE = "496e44134585"       # megafonía: cinco minutos de retraso
NEW_TEXT = ("A ver, ¿quién va ahora? ¿Tú, guapo? Dime. Mira, las de mesa te las dejo a dos "
            "cincuenta, que hoy están buenísimas, ¿eh? Y si te llevas dos kilos, te hago precio. "
            "¿Qué, te las pongo o qué?")


def ff(args):
    r = subprocess.run([FFMPEG, "-y", "-hide_banner", "-loglevel", "error"] + args,
                       capture_output=True, text=True)
    if r.returncode:
        sys.exit(f"ffmpeg failed: {r.stderr[-800:]}")


def make_babble(path, exclude):
    """Four overlapping streams of other people's lines, muffled: a crowd."""
    manifest = json.loads((ROOT / "tools" / "tts_manifest.json").read_text(encoding="utf-8"))
    pool = [l["id"] for l in manifest if l["who"] not in exclude and len(l["text"]) > 60]
    random.seed(11)
    inputs, filters, tracks = [], [], 4
    n = 0
    for t in range(tracks):
        picks = random.sample(pool, 4)
        labels = ""
        for p in picks:
            inputs += ["-i", str(VOICE / f"{p}.wav")]
            labels += f"[{n}:a]"
            n += 1
        filters.append(f"{labels}concat=n=4:v=0:a=1,atempo={1.0 + 0.04 * t}[t{t}]")
    mix = "".join(f"[t{t}]" for t in range(tracks))
    filters.append(f"{mix}amix=inputs={tracks}:normalize=0,lowpass=f=2200,highpass=f=150,"
                   f"aecho=0.6:0.5:40|75:0.3|0.2,volume=0.5[out]")
    ff(inputs + ["-filter_complex", ";".join(filters), "-map", "[out]", "-ar", "24000",
                 "-ac", "1", str(path)])


def main():
    OUT.mkdir(exist_ok=True)
    babble = OUT / "_babble.wav"
    make_babble(babble, {"AMPARO", "MEGAFONIA", "YO"})

    # 1. market: same words, a bit faster, with a crowd around you
    clean1 = VOICE / f"{MARKET_LINE}.wav"
    ff(["-i", str(clean1), str(OUT / "1_mercado_original.wav")])
    ff(["-i", str(clean1), "-i", str(babble), "-f", "lavfi", "-i",
        "anoisesrc=color=pink:amplitude=0.012:sample_rate=24000",
        "-filter_complex",
        "[0:a]atempo=1.12,adelay=900|900,volume=0.9[v];[1:a]volume=0.55[b];"
        "[v][b][2:a]amix=inputs=3:duration=first:normalize=0,apad=pad_dur=0.6,"
        "alimiter=limit=0.95[out]",
        "-map", "[out]", "-ar", "24000", "-ac", "1", str(OUT / "1_mercado_dificil.wav")])

    # 2. metro: a tinny loudspeaker in a tunnel with a train idling
    clean2 = VOICE / f"{METRO_LINE}.wav"
    ff(["-i", str(clean2), str(OUT / "2_metro_original.wav")])
    ff(["-i", str(clean2), "-f", "lavfi", "-i",
        "anoisesrc=color=brown:amplitude=0.25:sample_rate=24000", "-i", str(babble),
        "-filter_complex",
        "[0:a]adelay=700|700,highpass=f=450,lowpass=f=2900,acrusher=bits=9:mix=0.25,"
        "aecho=0.8:0.75:110|230|340:0.45|0.3|0.18,volume=1.1[v];"
        "[1:a]lowpass=f=180,volume=1.0[r];[2:a]volume=0.22[b];"
        "[v][r][b]amix=inputs=3:duration=first:normalize=0,apad=pad_dur=1.0,"
        "alimiter=limit=0.95[out]",
        "-map", "[out]", "-ar", "24000", "-ac", "1", str(OUT / "2_metro_dificil.wav")])

    # 3. a new line the way a stallholder really talks: fast, clipped, tag questions
    state = tts.load_state()
    line = {"id": "sample_amparo_colloquial", "who": "AMPARO", "text": NEW_TEXT}
    tts.voice_line(state, line)
    raw = VOICE / "sample_amparo_colloquial.wav"
    clean3 = OUT / "3_coloquial_limpio.wav"
    raw.replace(clean3)        # keep the demo take out of the game's voice folder
    ff(["-i", str(clean3), "-i", str(babble),
        "-filter_complex",
        "[0:a]atempo=1.15,adelay=600|600[v];[1:a]volume=0.6[b];"
        "[v][b]amix=inputs=2:duration=first:normalize=0,apad=pad_dur=0.6,"
        "alimiter=limit=0.95[out]",
        "-map", "[out]", "-ar", "24000", "-ac", "1", str(OUT / "3_coloquial_dificil.wav")])

    babble.unlink()
    (OUT / "LEEME.txt").write_text(
        "Harder-listening demo clips (not part of the game yet)\n\n"
        "1_mercado_original.wav   the line as it is in the game\n"
        "1_mercado_dificil.wav    same line, 12% faster, with crowd noise\n"
        "2_metro_original.wav     the announcement as it is in the game\n"
        "2_metro_dificil.wav      through a station loudspeaker, with echo and train rumble\n"
        "3_coloquial_limpio.wav   a new, more colloquial line, clean\n"
        "3_coloquial_dificil.wav  the same, 15% faster, with crowd noise\n\n"
        "Text of clip 3:\n" + NEW_TEXT + "\n", encoding="utf-8")
    for f in sorted(OUT.glob("*.wav")):
        print(f.name, f.stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()
