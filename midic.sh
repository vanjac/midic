#!/bin/sh
set -eu

# Only format 0 files are supported.

case "${1:-}" in
	*.mid | *.midi | *.smf) ;;
	*) echo "Usage: $0 output.mid < input.hex"; exit ;;
esac

rm -f "$1"
sed 's/#.*//;/^</,/^>/{/^>/!d};s/^>//' | # Skip comments ('#') and lines between < > markers
	while read -r line; do
		case "$line" in
			*[*]*) # Match loop syntax
				printf "%02x\n" $(seq ${line##*[*]}) | while read hex; do
					printf "%s" "${line%[*]*}" | sed "s/__/$hex/g"
				done ;;
			*) printf "%s" "$line" ;;
		esac
	done |
	xxd -r -p - "$1"
# Calculate and overwrite MTrk chunk size
printf "%08x" $(($(stat -c "%s" "$1") - 22)) | xxd -r -p -s 18 - "$1"
