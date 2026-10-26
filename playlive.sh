#!/bin/sh
set -eu

"$(dirname "$0")/midic2.py" -f port -p '*synth*'
