"""Settings that belong to one machine, kept out of the repository.

They live in tools/local.json, which git ignores; copy tools/local.example.json
to start. Anything missing falls back to a plain command name, so a machine
with godot and ffmpeg on its PATH needs no file at all for the basic tools.

    from local_config import get, spark
    python tools/local_config.py godot      # print one value (used by the .sh scripts)
"""

import json
import pathlib
import sys
import tempfile

PATH = pathlib.Path(__file__).resolve().parent / "local.json"
DEFAULTS = {
    "godot": "godot",                 # the Godot 4 console executable
    "ffmpeg": "ffmpeg",
    "shot_dir": str(pathlib.Path(tempfile.gettempdir()) / "valencia-shots"),
    "spark_host": "",                 # the GPU box that runs TTS checks and image renders
    "spark_user": "",
    "spark_key": "",                  # path to the SSH private key for it
}


def get(key):
    values = dict(DEFAULTS)
    if PATH.exists():
        values.update(json.loads(PATH.read_text(encoding="utf-8")))
    return values[key]


def spark():
    """(user@host, key path) for the GPU box, or exit with a pointer to the config."""
    host, user, key = get("spark_host"), get("spark_user"), get("spark_key")
    if not (host and user and key):
        sys.exit("This step needs the GPU box: set spark_host, spark_user and spark_key in "
                 "tools/local.json (see tools/local.example.json).")
    return f"{user}@{host}", key


if __name__ == "__main__":
    print(get(sys.argv[1]))
