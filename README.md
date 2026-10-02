# Valencia: Camino a EUROCALL

A Spanish practice game (Peninsular Spanish) set in Valencia, in two parts that are
both open from the start:

- **Parte 1 · El viaje** (A2–B1) – twelve places, twenty-four voiced conversations:
  the airport to the flamenco tablao by way of the EUROCALL conference.
- **Parte 2 · La historia** (B1–B2) – ten real historical sites, twenty reading
  passages of 330–400 words, from Roman Valentia to the Cabanyal today.

Double-click `Jugar.cmd` to play. It runs offline: every spoken line is pre-recorded.

## How it plays

- **Map** – real Valencia from OpenStreetMap, in two views: the whole city, and the old
  town street by street (click the framed area to zoom in). The two buttons at the top
  of the side panel switch between the parts; each part has its own pins, in itinerary
  order, and finishing one scene opens the next place.
- **Readings** (part 2) – a short voiced exchange with Lucía, Jordi or don Ramón, then a
  passage to read at your own pace (not voiced), then questions on it: main idea, detail,
  inference, vocabulary in context, true/false, and putting events in order. **↑ Volver al
  texto** jumps back to the passage from any question. Each place's card says what there
  is to see there today, and has a **Lecturas para imprimir** page with the texts, the
  questions and the vocabulary.
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
- **Zoom** – pinch with two fingers, or use the + and − buttons on
  the left edge. Once zoomed in, drag with one finger, or with the mouse button held down,
  to move around; at the top or bottom edge the drag carries on into scrolling the text.
  Ctrl + mouse wheel also zooms. The level is remembered.

## Phrase sheets

Each part 1 place has a one-page **Hoja de frases** (button under the place's
description on the map): what to say in each situation, the key phrases with meanings,
and the culture notes. The cuaderno has a button for every place at once, readings
included.

## Web version

`python -X utf8 tools/web_build.py` exports the game to `web/` (about 56 MB; the
39 MB engine file compresses to roughly a quarter if the host serves gzip or
brotli). Upload the whole folder to any static host over HTTPS and link to its
`index.html`; it needs no special server headers. To try it locally:

    cd web
    python -m http.server 8765

then open http://127.0.0.1:8765/. Progress is saved in the visitor's browser.

`python -X utf8 tools/web_deploy.py` publishes `web/` to GitHub Pages (the `gh-pages`
branch): https://a-c-pack.github.io/valencia-camino-a-eurocall/
`node tools/web_test.mjs <folder>` loads the build in headless Chrome, clicks into a
scene and saves screenshots.
`node tools/web_touch_test.mjs <folder>` does the same in a phone-sized window with real
touch events: taps, a pinch and a one-finger drag.

## Layout

```
content/NN_place.txt     the script for each place (format documented in tools/build_content.py);
                         01–12 are part 1, 21–30 are part 2 (`@part 2`)
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
tools/web_deploy.py      push web/ to the gh-pages branch (GitHub Pages)
tools/local_config.py    machine-specific paths and hosts, read from tools/local.json (not in git)
tools/check.sh           load the project headless, print script errors
tools/shot.sh            save a screenshot of any screen (debug save, not your progress)
game/                    the Godot 4.7 project
```

## Changing or adding content

1. Edit or add a `content/NN_place.txt`. A reading is `H:` (its title) followed by `R:`
   lines, one per paragraph; `O:` is an ordering exercise.
2. `python -X utf8 tools/build_content.py` – it lists any word with no gloss;
   add those to `content/lexicon/`.
3. Start qwen-tts-studio, then `python -X utf8 tools/tts_generate.py` – only
   new or changed lines are generated.

The illustrations were made with Ideogram 4 (non-commercial licence).
Map data © OpenStreetMap contributors, available under the Open Database Licence.
