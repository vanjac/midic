#!/bin/sh
set -eu

case "${1:-}" in
	*.mid | *.midi | *.smf) ;;
	*) echo "Usage: $0 output.mid < input.hex"; exit ;;
esac

rm -f "$1"
awk -Wposix -f hexfilter.awk | xxd -r -p - "$1"
# Calculate and overwrite MTrk chunk size (assumes format 0)
printf '%08x' $(($(wc -c <"$1") - 22)) | xxd -r -p -s 18 - "$1"
