"""Compile content/*.txt (the scene script format below) into game/data/content.json
and tools/tts_manifest.json (every line that needs a voice).

    python tools/build_content.py            # build, report words with no gloss
    python tools/build_content.py --missing  # print only the unglossed words, one per line

Script format, one file per location:

    @id mercado            @name Mercado Central      @zone Ciutat Vella
    @geo 39.4735 -0.3789 centre l     (lat lon, which map view, label side)
    @blurb ...             @goal ...                  @route how you get there
    == frutas | En el puesto de fruta ==
    N: narration (not voiced)
    AMPARO: a voiced line          AMPARO*: voiced, text hidden until revealed
    YO: a scripted line for the player (voiced by the model voice)
    Q: comprehension question
      * right answer || feedback
      - wrong answer || feedback
    C: situation, choose your reply
      * best reply || feedback      ~ acceptable reply || feedback      - poor reply || feedback
    T: situation, type what you would say
      = accepted answer (first one is the model answer, voiced)
      ! hint
    K: Title || body of a culture note
    M: solea               (a compás demo)

Inline: {surface|gloss} glosses a chunk; {{surface|gloss}} also files it in the cuaderno.
Every other word is glossed from content/lexicon/*.txt, one "word|gloss" per line
("-" as the gloss means "needs no gloss": names, letters, English words).
"""

import hashlib
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "content"
OUT = ROOT / "game" / "data" / "content.json"
MANIFEST = ROOT / "tools" / "tts_manifest.json"

LETTERS = "A-Za-zÁÉÍÓÚÜÑáéíóúüñçÇàèìòùÀÈÌÒÙïÏ·"
MARK = re.compile(r"\{\{(.+?)\|(.+?)\}\}|\{(.+?)\|(.+?)\}")
WORD = re.compile(rf"[{LETTERS}]+(?:[-'][{LETTERS}]+)*")
SPEAKER = re.compile(r"^([A-ZÑ_]+)(\*?):\s*(.*)$")
SCENE = re.compile(r"^==\s*(\w+)\s*\|\s*(.+?)\s*==$")
OPTION = re.compile(r"^\s+([*~\-=!])\s+(.*)$")

PLAIN, WORD_K, CHUNK, KEY = 0, 1, 2, 3


def sha(text, n=12):
    return hashlib.sha1(text.encode("utf-8")).hexdigest()[:n]


class Builder:
    def __init__(self):
        self.lexicon = self.load_lexicon()
        self.missing = {}
        self.phrases = {}
        self.voice = {}
        self.where = ""

    def load_lexicon(self):
        lex = {}
        for path in sorted((SRC / "lexicon").glob("*.txt")):
            for raw in path.read_text(encoding="utf-8").splitlines():
                if not raw.strip() or raw.startswith("#"):
                    continue
                word, _, gloss = raw.partition("|")
                lex[word.strip().lower()] = gloss.strip()
        return lex

    def plain(self, text):
        return MARK.sub(lambda m: m.group(1) or m.group(3), text).strip()

    def words(self, text, segs):
        pos = 0
        for m in WORD.finditer(text):
            if m.start() > pos:
                segs.append([text[pos:m.start()], "", PLAIN])
            word = m.group(0)
            gloss = self.lexicon.get(word.lower())
            if gloss is None:
                self.missing.setdefault(word.lower(), self.where)
                gloss = ""
            if gloss in ("", "-"):
                segs.append([word, "", PLAIN])
            else:
                segs.append([word, gloss, WORD_K])
            pos = m.end()
        if pos < len(text):
            segs.append([text[pos:], "", PLAIN])

    def segs(self, text, audio=None):
        """Split a marked-up line into [text, gloss, kind(, phrase id)] pieces."""
        text = text.strip()
        out, pos, ctx = [], 0, self.plain(text)
        for m in MARK.finditer(text):
            self.words(text[pos:m.start()], out)
            if m.group(1):
                surface, gloss = m.group(1), m.group(2)
                pid = sha(surface.lower() + "|" + gloss, 10)
                self.phrases.setdefault(pid, {"es": surface, "en": gloss, "ctx": ctx,
                                              "audio": audio or "", "loc": self.loc_id})
                if audio and not self.phrases[pid]["audio"]:
                    self.phrases[pid].update(ctx=ctx, audio=audio)
                out.append([surface, gloss, KEY, pid])
            else:
                out.append([m.group(3), m.group(4), CHUNK])
            pos = m.end()
        self.words(text[pos:], out)
        return out

    def say(self, who, text):
        """Register a voiced line, return its audio id."""
        spoken = self.plain(text)
        aid = sha(who + "|" + spoken)
        self.voice[aid] = {"id": aid, "who": who, "text": spoken}
        return aid

    def split_fb(self, body):
        text, _, fb = body.partition("||")
        return text.strip(), fb.strip()

    def parse(self, path):
        loc = {"scenes": []}
        scene = step = None
        self.loc_id = path.stem
        for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            self.where = f"{path.name}:{n}"
            if not raw.strip() or raw.lstrip().startswith("#"):
                continue
            if raw.startswith("@"):
                key, _, val = raw[1:].partition(" ")
                val = val.strip()
                if key == "geo":       # lat lon view(city|centre) [label side: r l t b]
                    bits = val.split()
                    loc["geo"] = [float(bits[0]), float(bits[1])]
                    loc["view"] = bits[2]
                    loc["side"] = bits[3] if len(bits) > 3 else "r"
                elif key in ("blurb", "goal", "route"):
                    loc[key] = self.segs(val)
                else:
                    loc[key] = val
                    if key == "id":
                        self.loc_id = val
                continue
            m = SCENE.match(raw)
            if m:
                scene = {"id": m.group(1), "title": m.group(2), "steps": []}
                loc["scenes"].append(scene)
                step = None
                continue
            if scene is None:
                sys.exit(f"{self.where}: content before the first == scene ==")
            m = OPTION.match(raw)
            if m:
                if step is None:
                    sys.exit(f"{self.where}: option with no question above it")
                self.option(step, m.group(1), m.group(2))
                continue
            m = SPEAKER.match(raw.strip())
            if not m:
                sys.exit(f"{self.where}: cannot parse: {raw!r}")
            who, star, body = m.groups()
            step = self.step(who, bool(star), body)
            scene["steps"].append(step)
        return loc

    def step(self, who, hidden, body):
        if who == "N":
            return {"t": "narr", "segs": self.segs(body)}
        if who == "Q":
            return {"t": "q", "segs": self.segs(body), "opts": []}
        if who == "C":
            return {"t": "choice", "segs": self.segs(body), "opts": []}
        if who == "T":
            return {"t": "type", "segs": self.segs(body), "answers": [], "hint": []}
        if who == "K":
            title, text = self.split_fb(body)
            return {"t": "note", "title": title, "segs": self.segs(text)}
        if who == "M":
            return {"t": "compas", "palo": body.strip()}
        aid = self.say(who, body)
        return {"t": "line", "who": who, "segs": self.segs(body, aid),
                "text": self.plain(body), "audio": aid, "hidden": hidden}

    def option(self, step, mark, body):
        kind = step["t"]
        if kind == "q" and mark in "*-":
            text, fb = self.split_fb(body)
            step["opts"].append({"segs": self.segs(text), "ok": mark == "*",
                                 "fb": self.segs(fb)})
        elif kind == "choice" and mark in "*~-":
            text, fb = self.split_fb(body)
            grade = {"*": 2, "~": 1, "-": 0}[mark]
            opt = {"text": self.plain(text), "grade": grade, "fb": self.segs(fb)}
            # Only replies the player can actually end up saying get a voice.
            opt["audio"] = self.say("YO", text) if grade else ""
            opt["segs"] = self.segs(text, opt["audio"] or None)
            step["opts"].append(opt)
        elif kind == "type" and mark == "=":
            if not step["answers"]:
                step["audio"] = self.say("YO", body)
                step["model"] = self.segs(body, step["audio"])
            step["answers"].append(self.plain(body))
        elif kind == "type" and mark == "!":
            step["hint"] = self.segs(body)
        else:
            sys.exit(f"{self.where}: '{mark}' does not belong under a {kind} step")

    def check(self, loc):
        for scene in loc["scenes"]:
            for s in scene["steps"]:
                tag = f"{loc.get('id')}/{scene['id']}"
                if s["t"] == "q" and sum(o["ok"] for o in s["opts"]) != 1:
                    sys.exit(f"{tag}: a Q needs exactly one * answer")
                if s["t"] == "choice" and not any(o["grade"] == 2 for o in s["opts"]):
                    sys.exit(f"{tag}: a C needs a * reply")
                if s["t"] == "type" and not s["answers"]:
                    sys.exit(f"{tag}: a T needs at least one = answer")


def main():
    b = Builder()
    cast = json.loads((SRC / "cast.json").read_text(encoding="utf-8"))
    locations = []
    for path in sorted(SRC.glob("[0-9]*.txt")):
        loc = b.parse(path)
        b.check(loc)
        locations.append(loc)

    unknown = sorted({v["who"] for v in b.voice.values()} - set(cast))
    if unknown:
        sys.exit(f"speakers missing from cast.json: {unknown}")

    if "--missing" in sys.argv:
        for w in sorted(b.missing):
            print(w)
        return

    OUT.parent.mkdir(parents=True, exist_ok=True)
    public_cast = {k: {f: v[f] for f in ("name", "role", "color")} for k, v in cast.items()}
    OUT.write_text(json.dumps({"cast": public_cast, "locations": locations,
                               "phrases": b.phrases}, ensure_ascii=False),
                   encoding="utf-8")
    MANIFEST.write_text(json.dumps(list(b.voice.values()), ensure_ascii=False, indent=1),
                        encoding="utf-8")

    scenes = sum(len(l["scenes"]) for l in locations)
    print(f"{len(locations)} locations, {scenes} scenes, {len(b.voice)} voiced lines, "
          f"{len(b.phrases)} key phrases")
    if b.missing:
        print(f"{len(b.missing)} words have no gloss (run with --missing to list), e.g. "
              + ", ".join(sorted(b.missing)[:12]))


if __name__ == "__main__":
    main()
