#!/usr/bin/env python3
import argparse
import os
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
parser.add_argument('-o', '--output', default='-', type=argparse.FileType('wb'))
parser.add_argument('-f', '--format', default='hex', choices=['hex', 'smf'])
args = parser.parse_args()

def parsefields(hexstr, count='1', start='0', end='0'):
    return hexstr, int(count, 0), int(start, 0), int(end, 0)
skip = False
for line in args.input:
    skip = (skip or line.startswith('<')) and not line.startswith('>')
    if not skip:
        f = re.sub(r'(^>|#.*|[*-/])', '', line).split(':')
        hexstr, count, start, end = parsefields(*f)
        for i in range(count):
            val = int(i / count * end + (count-i) / count * start)
            b = bytes.fromhex(hexstr.replace('__', f'{val:02x}'))
            if args.format == 'smf':
                args.output.write(b)
            else:
                cmdidx = 0
                for i in range(1, len(b) + 1):
                    if i == len(b) or (b[i] & 0x80) != 0:
                        args.output.write((b[cmdidx:i].hex() + '\n').encode())
                        cmdidx = i
if args.format == 'smf':
    size = args.output.tell() - 22
    args.output.seek(18, os.SEEK_SET)
    args.output.write(size.to_bytes(4))
