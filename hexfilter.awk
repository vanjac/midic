#!/usr/bin/env -S awk -Wposix -f

# Syntax:
#   0-9 A-F   Hex digits
#   #         Line comment
#   < >       Skip lines between
#   :         Repeat line (: count : start : end)
#   __        Interpolate value
#   *+,-./    Ignored

BEGIN { FS = ":" }
/^</,/^>/ { if (!/^>/) next }
{
	gsub(/(^>|#.*|[*-/]|[[:space:]])/, "")
	count = (NF > 1) ? $2 : 1
	for (i = 0; i < count; i++) {
		line = $1
		gsub(/__/, sprintf("%02x", i / count * $4 + (count-i) / count * $3), line)
		print line
	}
}
