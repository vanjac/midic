#!/bin/sh
set -eu

"$(dirname "$0")/midic.py" -f fluidsynth | fluidsynth -q -f "$(dirname "$0")/fluidsynth.conf"
