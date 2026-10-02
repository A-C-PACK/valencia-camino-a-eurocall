# Valencia: Camino a EUROCALL

A Spanish practice game (A2–B1, Peninsular Spanish) set in twelve places around
Valencia. Double-click `Jugar.cmd` to play. It runs offline: every line is
pre-recorded.

## How it plays

- **Map** – real Valencia from OpenStreetMap, in two views: the whole city, and the old
  town street by street (click the framed area to zoom in). Twelve places in itinerary
  order; finishing one scene opens the next place.
- **Scenes** – a voiced conversation. You answer comprehension questions, choose
  the most appropriate reply, and type what you would say. Options also answer
  to the keys A/B/C.
- **Tap any word** for an English gloss. Words you look up, and the key phrases
  in red, go into the **cuaderno**.
- **Cuaderno** – spaced-repetition review: phrases come back after 1 day, 3 days,
  then at growing intervals.
  Filter by place or search, tick the phrases you want, then **Practicar
  seleccionadas** or **Imprimir tarjetas** (opens a print-ready flashcard page in
  your browser; print double-sided, flip on the long edge).
- **Modo escucha** (map screen) hides every line until you ask to see it.
- **Grabar / Mi voz / Comparar** – record yourself saying any line, then hear the
  model and your own take back to back. Takes are not saved to disk.
- **F11** toggles fullscreen.

## Phrase sheets

Each place has a one-page **Hoja de frases** (button under the place's description on
the map): what to say in each situation, the key phrases with meanings, and the
culture notes. The cuaderno has a button for all twelve at once.

## Web version

`python -X utf8 tools/web_build.py` exports the game to `web/` (about 56 MB; the
39 MB engine file compresses to roughly a quarter if the host serves gzip or
brotli). Upload the whole folder to any static host over HTTPS and link to its
`index.html`; it needs no special server headers. To try it locally:

    cd web
    python -m http.server 8765

then open http://127.0.0.1:8765/. Progress is saved in the visitor's browser.
`node tools/web_test.mjs <folder>` loads the build in headless Chrome, clicks into a
scene and saves screenshots.

## Layout

```
content/NN_place.txt     the script for each place (format documented in tools/build_content.py)
content/cast.json        characters and their voice descriptions
content/lexicon/*.txt    word|gloss, the tap-to-gloss dictionary
tools/build_content.py   content -> game/data/content.json + tools/tts_manifest.json
tools/tts_generate.py    voices every line through qwen-tts-studio (resumable)
tools/make_captions.py   Ideogram captions for the place illustrations
tools/fetch_osm.py       one-off download of the OpenStreetMap data into tools/osm/
tools/make_map.py        draws both map views and the round pin thumbnails from that data
tools/qa_audio.py        transcribe the recordings on the Spark and flag suspect ones
tools/status.py          progress bars for voices, audio check and illustrations
tools/encode_audio.py     WAV masters (audio_src/) -> the Ogg files the game ships
tools/web_build.py       export the web version into web/
tools/check.sh           load the project headless, print script errors
tools/shot.sh            save a screenshot of any screen (debug save, not your progress)
game/                    the Godot 4.7 project
```

## Changing or adding content

1. Edit or add a `content/NN_place.txt`.
2. `python -X utf8 tools/build_content.py` – it lists any word with no gloss;
   add those to `content/lexicon/`.
3. Start qwen-tts-studio, then `python -X utf8 tools/tts_generate.py` – only
   new or changed lines are generated.

The illustrations were made with Ideogram 4 (non-commercial licence).
Map data © OpenStreetMap contributors, available under the Open Database Licence.
