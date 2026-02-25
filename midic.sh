#!/bin/sh
set -eu

# Usage: sh midic.sh output.mid < input.hex
# Only format 0 files are supported.

# Skip comments ('#') and all unrecognized characters
grep -o '^[^#]*' | xxd -r -p > "$1"
# Calculate and overwrite MTrk chunk size
printf "%08x\n" $(($(stat -c "%s" "$1") - 22)) | xxd -r -p -s 18 - "$1"
