#!/bin/bash
# Load the project headless for a moment and print only script errors/warnings.
G="$(python -X utf8 "$(dirname "$0")/local_config.py" godot)"
"$G" --headless --path "$(dirname "$0")/../game" --quit-after 20 2>&1 | grep -E "ERROR|WARNING|at:|Parse|error" | head -40
echo "check done"
