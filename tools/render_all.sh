#!/bin/bash
# Runs ON the GPU box: render every val_*.json caption that has no PNG yet.
# One at a time -- the model peaks near 41 GB and the TTS stack shares the GPU.
export HF_HUB_CACHE="$HOME/ideogram4/hf-cache"
cd ~/ideogram4/repo || exit 1
for cap in ~/ideogram4/captions/val_*.json; do
  name=$(basename "$cap" .json)
  out=~/ideogram4/out/$name.png
  [ -f "$out" ] && continue
  echo "=== $name $(date +%H:%M:%S)"
  ../.venv/bin/python run_inference.py \
    --prompt "$(cat "$cap")" \
    --no-magic-prompt --quantization nf4 --sampler-preset V4_DEFAULT_20 \
    --height 1152 --width 768 --seed 7 \
    --output "$out" 2>&1 | grep -vE "Loading weights|it/s\]"
done
echo "=== ALL DONE $(date +%H:%M:%S)"
