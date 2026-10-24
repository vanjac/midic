#!/usr/bin/env python3
import argparse, logging, os, re, sys

parser = argparse.ArgumentParser()
parser.add_argument('-i', '--input', default='-', type=argparse.FileType('r'))
parser.add_argument('-o', '--output', default='-', type=argparse.FileType('wb'))
parser.add_argument('-f', '--format', default='hex', choices=['hex', 'smf'])
parser.add_argument('-p', '--portname')
args = parser.parse_args()

def parse_fields(hexstr, count='1', start='0', end='0'):
    return hexstr, int(count, 0), int(start, 0), int(end, 0)

def sub_macro(m): return f'B{m[2]}7{ord(m[1].upper())-67:x}00009{m[2]}'

if args.portname:
    import fnmatch, rtmidi
    midiout = rtmidi.MidiOut()
    ports = midiout.get_ports()
    print('Ports:\n  ' + '\n  '.join(ports))
    pattern = args.portname.lower()
    portidx = next((i for i,p in enumerate(ports) if fnmatch.fnmatch(p.lower(), pattern)), None)
    if portidx is None: sys.exit('No matching port')
    print('Selected:', ports[portidx])
    midiout.open_port(portidx)

status = 0
skip = False
for line in args.input:
    skip = (skip or line.startswith('<')) and not line.startswith('>')
    if skip: continue
    f = re.sub(r'(^>|#.*|[*-/])', '', line).split(':')
    try:
        hexstr, count, start, end = parse_fields(*f)
        hexstr = re.sub(r'(?i)([k-r])([0-9a-f])', sub_macro, hexstr)
        for i in range(count):
            val = int(i / count * end + (count-i) / count * start)
            b = bytes.fromhex(hexstr.replace('__', f'{val:02x}'))
            if args.format == 'smf':
                args.output.write(b)
                continue
            evidx = 0
            for j in range(1, len(b) + 1):
                if j == len(b) or ((b[j] & 0x80) != 0 and (b[evidx] & 0xF0) != 0xF0):
                    ev = bytearray(b[evidx:j-1])
                    evidx = j
                    if len(ev) == 0: continue
                    if ev[0] == 0xF0: del ev[1]
                    if args.portname:
                        midiout.send_message(ev)
                    elif args.format == 'hex':
                        args.output.write((ev.hex() + '\n').encode())
            args.output.flush()
    except (IndexError, TypeError, ValueError):
        logging.exception('While parsing line: `%s`', line.rstrip())
        status = 1
if args.format == 'smf':
    size = args.output.tell() - 22
    args.output.seek(18, os.SEEK_SET)
    args.output.write(size.to_bytes(4, 'big'))
sys.exit(status)
