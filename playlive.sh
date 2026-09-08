#!/bin/sh
set -eu

python3 -u midic.py -f fluidsynth | fluidsynth -q
