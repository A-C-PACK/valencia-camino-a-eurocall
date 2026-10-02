"""Runs inside the open-webui container on the Spark (it ships faster-whisper
and a cached model): transcribe every WAV in a folder to JSON on stdout.

    python qa_transcribe.py /tmp/valencia_qa > transcripts.json
"""

import json
import pathlib
import sys

from faster_whisper import WhisperModel

CACHE = "/app/backend/data/cache/whisper/models"


def main():
    folder = pathlib.Path(sys.argv[1])
    model = WhisperModel("base", device="cpu", compute_type="int8", download_root=CACHE,
                         local_files_only=True)
    out = {}
    for wav in sorted(folder.glob("*.wav")):
        segments, info = model.transcribe(str(wav), language="es", beam_size=5)
        out[wav.stem] = {"text": " ".join(s.text.strip() for s in segments),
                         "duration": round(info.duration, 2)}
        print(wav.stem, file=sys.stderr, flush=True)
    json.dump(out, sys.stdout, ensure_ascii=False)


if __name__ == "__main__":
    main()
