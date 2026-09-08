#!/usr/bin/env python3
import argparse
import re

# Syntax:
#   0-9 A-F   Hex digits
#   #         Line comment
#   < >       Skip lines between
#   :         Repeat line (: count : start : end)
#   __        Interpolate value
#   *+,-./    Ignored

parser = argparse.ArgumentParser()
parser.add_argument('-i', '--input', default='-', type=argparse.FileType('r'))
parser.add_argument('-o', '--output', default='-', type=argparse.FileType('w'))
args = parser.parse_args()

def parsefields(ev, count='1', start='0', end='0'):
    return ev, int(count, 0), int(start, 0), int(end, 0)
skip = False
for line in args.input:
    skip = (skip or line.startswith('<')) and not line.startswith('>')
    if not skip:
        f = re.sub(r'(^>|#.*|[*-/\s])', '', line).split(':')
        ev, count, start, end = parsefields(*f)
        for i in range(count):
            val = int(i / count * end + (count-i) / count * start)
            args.output.write(ev.replace('__', f'{val:02x}') + '\n')
