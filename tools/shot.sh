#!/bin/bash
# Usage: tools/shot.sh <spec> <name>   -> writes <shot_dir>/<name>.png (shot_dir: tools/local.json)
# spec: title | map[:index] | scene:<loc>:<scene>[:steps] | cuaderno | review
G="$(python -X utf8 "$(dirname "$0")/local_config.py" godot)"
OUT="$(python -X utf8 "$(dirname "$0")/local_config.py" shot_dir)"
mkdir -p "$OUT"
"$G" --path "$(dirname "$0")/../game" --resolution 1280x720 -- --shot="$1" --out="$OUT/$2.png" 2>&1 | grep -E "ERROR|WARNING|at:|Parse|autoplay" | head -30
ls -la "$OUT/$2.png" 2>&1 | awk '{print $5, $9}'
