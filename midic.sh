#!/bin/sh
set -eu

# Only format 0 files are supported.
# Syntax:
#   0-9 A-F   Hex digits
#   #         Line comment
#   < >       Skip lines between
#   :         Repeat line (: count : start : end)
#   __        Interpolate value
#   *+,-./    Ignored

case "${1:-}" in
	*.mid | *.midi | *.smf) ;;
	*) echo "Usage: $0 output.mid < input.hex"; exit ;;
esac

rm -f "$1"
awk -Wposix -f hexfilter.awk | xxd -r -p - "$1"
# Calculate and overwrite MTrk chunk size
printf '%08x' $(($(wc -c <"$1") - 22)) | xxd -r -p -s 18 - "$1"
