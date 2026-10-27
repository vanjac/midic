#!/usr/bin/env python3
import argparse, logging, os, re, sys
from collections.abc import Sequence
from dataclasses import dataclass, field
from enum import Enum
logger = logging.getLogger(__name__)

class MidiStandard(Enum):
	NONE = 'OFF'
	GM   = 'GM'
	GM2  = 'GM2'
	GS   = 'GS'
	XG   = 'XG'

@dataclass
class ColumnState:
	channel: int = 0
	mute: bool = False
	held_key: int = -1
	interp_from: int = 0

@dataclass
class State:
	standard: MidiStandard = MidiStandard.NONE
	skip: bool = False
	delta_ticks: int = 0
	repeat: int = 0
	columns: list[ColumnState] = field(default_factory=list)

class ParseError(Exception):
	pass

def parse_hex(s: str) -> int:
	try:
		return int(s, 16)
	except ValueError:
		raise ParseError(f'Invalid hex: {s}')

def validate_range(i: int, minval: int, maxval: int):
	if not minval <= i <= maxval:
		raise ParseError(f'Value out of range: {i:X}')

def validate_cmd_fields(cmd: str, fields: list[str], expected_len: int):
	if len(fields) != expected_len:
		raise ParseError(f'Invalid syntax for {cmd}')

def write_bytes(args: argparse.Namespace, b: bytes):
	match args.format:
		case 'hex':
			args.output.write((b.hex() + '\n').encode())
		case 'smf':
			args.output.write(b)

def write_varlen(args: argparse.Namespace, val: int):
	b = bytearray()
	b.append(val & 0x7F)
	val >>= 7
	while val != 0:
		b.append((val & 0x7F) | 0x80)
		val >>= 7
	b.reverse()
	write_bytes(args, b)

def write_midi_event(args: argparse.Namespace, state: State, data: Sequence[int]):
	match args.format:
		case 'port':
			args.midiout.send_message(bytes(data))
		case 'event':
			args.output.write((bytes(data).hex() + '\n').encode())
		case _:
			write_varlen(args, state.delta_ticks)
			state.delta_ticks = 0
			write_bytes(args, bytes(data))

def write_col_midi_event(args: argparse.Namespace, state: State, col: ColumnState, data: list[int]):
	if not col.mute:
		data[0] |= col.channel
		write_midi_event(args, state, data)

def write_sysex(args: argparse.Namespace, state: State, data: Sequence[int]):
	if len(data) >= 255:
		raise ParseError('SysEx data too long')
	if args.format in ['event', 'port']:
		write_midi_event(args, state, [0xF0, *data, 0xF7])
	else:
		write_midi_event(args, state, [0xF0, len(data) + 1, *data, 0xF7])

def write_meta_event(args: argparse.Namespace, state: State, evtype: int, data: Sequence[int]):
	if args.format not in ['event', 'port']:
		write_midi_event(args, state, [0xFF, evtype, len(data), *data])

def play_note(args: argparse.Namespace, state: State, col: ColumnState, key: int, vel: int):
	write_col_midi_event(args, state, col, [0x90, key, vel])
	col.held_key = key

def release_note(args: argparse.Namespace, state: State, col: ColumnState, key: int, vel: int):
	if key != -1:
		write_col_midi_event(args, state, col, [0x80, key, vel])
	if col.held_key == key:
		col.held_key = -1

def write_reset_message(args: argparse.Namespace, state: State):
	match state.standard:
		case MidiStandard.NONE:
			write_sysex(args, state, [0x7E, 0x7F, 0x09, 0x02])
		case MidiStandard.GM:
			write_sysex(args, state, [0x7E, 0x7F, 0x09, 0x01])
		case MidiStandard.GM2:
			write_sysex(args, state, [0x7E, 0x7F, 0x09, 0x03])
		case MidiStandard.GS:
			write_sysex(args, state, [0x41, 0x10, 0x42, 0x12, 0x40, 0x00, 0x7F, 0x00, 0x41])
		case MidiStandard.XG:
			write_sysex(args, state, [0x43, 0x10, 0x4C, 0x00, 0x00, 0x7E, 0x00])

def write_meta_text(args: argparse.Namespace, state: State, fields: list[str], evtype: int):
	if len(fields) < 2:
		raise ParseError('Text is empty')
	if len(fields) > 2:
		raise ParseError('Tabs not allowed in text event')
	if len(fields[1]) > 255:
		raise ParseError('Text is too long')
	write_meta_event(args, state, evtype, fields[1].encode('ascii'))

def write_header(args: argparse.Namespace, tpqn: int):
	write_bytes(args, bytes([
		0x4D, 0x54, 0x68, 0x64, # MThd
		0x00, 0x00, 0x00, 0x06, # length
		0x00, 0x00, # format
		0x00, 0x01, # ntrks
		tpqn >> 8, tpqn & 0xFF,
		0x4D, 0x54, 0x72, 0x6B, # MTrk
		0xFF, 0xFF, 0xFF, 0xFF, # length (to be overwritten)
	]))

def process_event(args: argparse.Namespace, state: State, col: ColumnState, field: str, t: float):
	evstr = re.sub(r' ', '', field)
	if not evstr:
		return
	if len(evstr) != 5:
		raise ParseError(f'Invalid event syntax: {field}')

	w = parse_hex(evstr[1:5])
	if t == 1:
		col.interp_from = w
	else:
		w = int(w * t + col.interp_from * (1-t))
	b1 = w >> 8
	b2 = w & 0xFF
	match evstr[0].upper():
		case 'M':
			mute = b1 & 0xF
			validate_range(mute, 0, 1)
			validate_range(b2, 0, 0) # reserved
			release_note(args, state, col, col.held_key, 0x7F)
			col.channel = b1 >> 4
			col.mute = bool(mute)
		case 'K':
			validate_range(b1, 0, 0x7F) # key
			validate_range(b2, 0, 0x7F) # velocity
			play_note(args, state, col, b1, b2)
		case 'R':
			validate_range(b1, 0, 0x80) # key
			validate_range(b2, 0, 0x7F) # velocity
			if b1 == 0x80:
				release_note(args, state, col, col.held_key, b2)
			else:
				release_note(args, state, col, b1, b2)
		case 'N':
			validate_range(b1, 0, 0x7F) # key
			validate_range(b2, 0, 0x7F) # velocity
			release_note(args, state, col, col.held_key, 0x7F)
			play_note(args, state, col, b1, b2)
		case 'L':
			validate_range(b1, 0, 0x7F) # key
			validate_range(b2, 0, 0x7F) # velocity
			held = col.held_key
			play_note(args, state, col, b1, b2)
			release_note(args, state, col, held, 0x7F)
		case 'A':
			validate_range(b1, 0, 0x80) # key
			validate_range(b2, 0, 0x7F) # pressure
			if b1 == 0x80:
				write_col_midi_event(args, state, col, [0xD0, b2])
			else:
				write_col_midi_event(args, state, col, [0xA0, b1, b2])
		case 'B':
			validate_range(b2, 0, 0x7F) # value
			if b1 >= 0x80: # RPN
				write_col_midi_event(args, state, col, [0xB0, 0x65, 0x00])
				write_col_midi_event(args, state, col, [0xB0, 0x64, b1 & 0x7F])
				write_col_midi_event(args, state, col, [0xB0, 0x06, b2])
			else:
				write_col_midi_event(args, state, col, [0xB0, b1, b2])
		case 'C':
			validate_range(b1, 0, 0x7F) # bank
			validate_range(b2, 0, 0x7F) # program
			# https://www.fluidsynth.org/wiki/settings/synth/#settings_synth_midi-bank-select
			match state.standard:
				case MidiStandard.GS:
					write_col_midi_event(args, state, col, [0xB0, 0x00, b1])
				case MidiStandard.GM2 | MidiStandard.XG:
					write_col_midi_event(args, state, col, [0xB0, 0x20, b1])
			write_col_midi_event(args, state, col, [0xC0, b2])
		case 'E':
			validate_range(w, 0, 0x3FFF)
			write_col_midi_event(args, state, col, [0xE0, w & 0x7F, w >> 7])
		case 'T':
			validate_range(w, 0x3A, 0xFFFF)
			bpm = w / 16
			uspqn = int(60000000 / bpm)
			write_meta_event(args, state, 0x51, uspqn.to_bytes(3, 'big'))
		case 'S':
			state.delta_ticks += b1
			state.repeat = b2
		case cmd:
			raise ParseError(f'Unknown event command: {cmd}')

def process_line(args: argparse.Namespace, state: State, line: str):
	fields = re.sub(r'(\n|#.*)', '', line).split('\t')
	if '<' in fields[0]:
		state.skip = True
	if '>' in fields[0]:
		state.skip = False
	if state.skip:
		return
	cmd = re.sub(r'[<>\-= ]', '', fields[0])
	match cmd.lower():
		case '':
			repeat = state.repeat
			state.repeat = 0
			for i in range(repeat + 1):
				for c, f in enumerate(fields[1:]):
					if len(state.columns) < c + 1:
						state.columns.append(ColumnState())
					process_event(args, state, state.columns[c], f, (i + 1) / (repeat + 1))
		case 'tpqn':
			validate_cmd_fields(cmd, fields, 2)
			tpqn = parse_hex(fields[1])
			validate_range(tpqn, 0, 0x7FFF)
			write_header(args, tpqn)
		case 'mode':
			validate_cmd_fields(cmd, fields, 2)
			try:
				state.standard = MidiStandard(fields[1].upper())
			except ValueError:
				raise ParseError(f'Unknown standard name: {fields[1]}')
			write_reset_message(args, state)
			for col in state.columns:
				col.held_key = -1
		case 'stop':
			validate_cmd_fields(cmd, fields, 1)
			write_meta_event(args, state, 0x2F, [])
		case 'sysx':
			validate_cmd_fields(cmd, fields, 2)
			try:
				msg = bytes.fromhex(fields[1])
			except ValueError:
				raise ParseError(f'Invalid hex: {fields[1]}')
			write_sysex(args, state, msg)
		case 'soff':
			for c in range(0, 16):
				write_midi_event(args, state, [0xB0 | c, 0x78, 0x00])
		case 'text':
			write_meta_text(args, state, fields, 0x01)
		case 'copy':
			write_meta_text(args, state, fields, 0x02)
		case 'trck':
			write_meta_text(args, state, fields, 0x03)
		case 'inst':
			write_meta_text(args, state, fields, 0x04)
		case 'lyrc':
			write_meta_text(args, state, fields, 0x05)
		case 'mark':
			write_meta_text(args, state, fields, 0x06)
		case 'cuep':
			write_meta_text(args, state, fields, 0x07)
		case _:
			raise ParseError(f'Unknown command: {cmd}')

def main() -> int:
	logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
	parser = argparse.ArgumentParser()
	parser.add_argument('-i', '--input', default='-', type=argparse.FileType('r'))
	parser.add_argument('-o', '--output', default='-', type=argparse.FileType('wb'))
	parser.add_argument('-f', '--format', default='smf', choices=['hex', 'smf', 'event', 'port'])
	parser.add_argument('-p', '--portname', default='*')
	args = parser.parse_args()
	if args.format == 'smf' and not args.output.seekable():
		logger.error('SMF output must be a seekable file')
		return 1

	if args.format == 'port':
		import fnmatch, rtmidi # type: ignore
		args.midiout = rtmidi.MidiOut()
		ports = args.midiout.get_ports()
		logger.info('Ports available:\n' + ''.join(f'  {name}\n' for name in ports))
		pattern = args.portname.lower()
		portidx = next((i for i,p in enumerate(ports) if fnmatch.fnmatch(p.lower(), pattern)), None)
		if portidx is None:
			logger.error('No matching port')
			return 1
		logger.info(f'Selected port: {ports[portidx]}')
		args.midiout.open_port(portidx)

	state = State()
	status = 0
	for i, line in enumerate(args.input):
		try:
			process_line(args, state, line)
		except ParseError as e:
			logger.error(f'on line {i + 1}: {e.args[0]}')
			status = 1
		if args.format == 'event':
			args.output.flush()

	if args.format == 'smf':
		size = args.output.tell() - 22
		if size < 0:
			logger.error('Not enough data (missing header?)')
			return 1
		args.output.seek(18, os.SEEK_SET)
		args.output.write(size.to_bytes(4, 'big'))
	return status

if __name__ == '__main__':
	sys.exit(main())
