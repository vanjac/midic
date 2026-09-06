#!/usr/bin/env -S awk -Wposix -f
BEGIN { FS = ":" }
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
