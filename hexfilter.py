#!/usr/bin/env python3
import re
import sys

# Syntax:
#   0-9 A-F   Hex digits
#   #         Line comment
#   < >       Skip lines between
#   :         Repeat line (: count : start : end)
#   __        Interpolate value
#   *+,-./    Ignored

def parsefields(ev, count='1', start='0', end='0'):
    return ev, int(count, 0), int(start, 0), int(end, 0)
skip = False
for line in sys.stdin:
    skip = (skip or line.startswith('<')) and not line.startswith('>')
    if not skip:
        f = re.sub(r'(^>|#.*|[*-/\s])', '', line).split(':')
        ev, count, start, end = parsefields(*f)
        for i in range(count):
            val = int(i / count * end + (count-i) / count * start)
            print(ev.replace('__', f'{val:02x}'))
