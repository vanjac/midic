#!/bin/sh
set -eu

python3 "$(dirname "$0")/midic.py" -f fluidsynth | fluidsynth -q
