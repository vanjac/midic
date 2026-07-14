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
awk -Wposix -F ':' '
	/^</,/^>/ { if (!/^>/) next }
	{
		gsub(/(^>|#.*|[*-/])/, "")
		count = (NF > 1) ? $2 : 1
		for (i = 0; i < count; i++) {
			line = $1
			gsub(/__/, sprintf("%02x", i / count * $4 + (count-i) / count * $3), line)
			print line
		}
	}
' | xxd -r -p - "$1"
# Calculate and overwrite MTrk chunk size
printf '%08x' $(($(wc -c <"$1") - 22)) | xxd -r -p -s 18 - "$1"
