#!/usr/bin/env python3
import argparse, os, re

parser = argparse.ArgumentParser()
parser.add_argument('-i', '--input', default='-', type=argparse.FileType('r'))
parser.add_argument('-o', '--output', default='-', type=argparse.FileType('wb'))
parser.add_argument('-f', '--format', default='hex', choices=['hex', 'smf', 'fluidsynth'])
args = parser.parse_args()

# Syntax:
#   0-9 A-F   Hex digits
#   #         Line comment
#   < >       Skip lines between
#   :         Repeat line (: count : start : end)
#   __        Interpolate value
#   *+,-./    Ignored

def parse_fields(hexstr, count='1', start='0', end='0'):
    return hexstr, int(count, 0), int(start, 0), int(end, 0)

def make_fluidsynth_cmd(b):
    chan = b[0] & 0xF
    match b[0] >> 4:
        case 0x8: return f'noteoff {chan} {b[1]}\n'
        case 0x9: return f'noteon {chan} {b[1]} {b[2]}\n'
        case 0xB: return f'cc {chan} {b[1]} {b[2]}\n'
        case 0xC: return f'prog {chan} {b[1]}\n'
        case 0xE: return f'pitch_bend {chan} {b[1] + 128 * b[2]}\n'
        case _: return ''

skip = False
for line in args.input:
    skip = (skip or line.startswith('<')) and not line.startswith('>')
    if not skip:
        f = re.sub(r'(^>|#.*|[*-/])', '', line).split(':')
        hexstr, count, start, end = parse_fields(*f)
        for i in range(count):
            val = int(i / count * end + (count-i) / count * start)
            b = bytes.fromhex(hexstr.replace('__', f'{val:02x}'))
            if args.format == 'smf':
                args.output.write(b)
                continue
            evidx = 0
            for j in range(1, len(b) + 1):
                if j == len(b) or (b[j] & 0x80) != 0:
                    ev = b[evidx:j]
                    evidx = j
                    if args.format == 'fluidsynth':
                        args.output.write(make_fluidsynth_cmd(ev).encode())
                    elif args.format == 'hex':
                        args.output.write((ev.hex() + '\n').encode())
                    args.output.flush()
if args.format == 'smf':
    size = args.output.tell() - 22
    args.output.seek(18, os.SEEK_SET)
    args.output.write(size.to_bytes(4, 'big'))
