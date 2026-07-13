#!/bin/sh
set -eu

# Only format 0 files are supported.

case "${1:-}" in
	*.mid | *.midi | *.smf) ;;
	*) echo "Usage: $0 output.mid < input.hex"; exit ;;
esac

rm -f "$1"
awk -Wposix '
	{ sub(/#.*/, "") }
	/^</,/^>/ { if (/^>/) sub(/^>/, ""); else next }
	/\*/ {
		split($0, parts, "*")
		for (i = 0; i < parts[2]; i++) {
			v = i / parts[2] * parts[4] + (parts[2] - i) / parts[2] * parts[3]
			line = parts[1]; gsub(/__/, sprintf("%02x", v), line)
			print line
		}
		next
	}
	{ print }
' | xxd -r -p - "$1"
# Calculate and overwrite MTrk chunk size
printf "%08x" $(($(stat -c "%s" "$1") - 22)) | xxd -r -p -s 18 - "$1"
