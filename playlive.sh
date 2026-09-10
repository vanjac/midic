#!/bin/sh
set -eu

"$(dirname "$0")/midic.py" -f fluidsynth | fluidsynth -q
