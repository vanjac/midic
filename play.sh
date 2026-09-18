#!/bin/sh
set -eu

fluidsynth -iq -f "$(dirname "$0")/fluidsynth.conf" "$1"
