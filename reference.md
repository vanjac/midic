# MIDI-Hex Reference

## Syntax

- `#` Line comment
- `<` Playback skip
- `>` Playback resume
- `=` Major row highlight
- `-` Minor row highlight

## Events

- `T iiif` Tempo
  - `iii`: Integer part. Default: `078`
  - `f`: Fractional part
- `S ttrr` Delay + Repeat
  - `tt`: Delay ticks
  - `rr`: Repeat/interpolate next row
- `M cm00` Column Properties
  - `c`: MIDI channel (`0` to `F`)
  - `m`: 1 = mute, 0 = unmute
- `C bbpp` Program Change
  - `bb`: Bank
  - `pp`: Program
- `K kkvv` Note On
  - `kk`: Key
  - `vv`: Velocity
- `R kkvv` Note Off
  - `kk`: Key, or `80` = prev note
  - `vv`: Release velocity
- `N kkvv` Prev Note Off + Note On
  - `kk`: Key
  - `vv`: Velocity
- `L kkvv` Note On + Prev Note Off ("Legato")
  - `kk`: Key
  - `vv`: Velocity
- `A kkpp` Aftertouch
  - `kk`: Key, or `80` = channel
  - `pp`: Pressure
- `B ccvv` Control/RPN Change
  - `cc`: Controller (`00` to `7F`) or RPN (`80` to `FF`)
  - `vv`: Value
- `E vvvv` Pitch Wheel
  - `vvvv`: Pitch (`0000` to `3FFF`). Default: `2000`

### Controllers

- `B 00vv` Bank MSB; change to rhythm channel (`78`) or melodic channel (`79`)
- `B 01vv` Modulation (Vibrato)
- `B 07vv` Channel Volume. Default: `64`
- `B 0Avv` Channel Panning. Default: `40`
- `B 0Bvv` Expression. Default: `7F`
- `B 40vv` Sustain
- `B 7800` All Sound Off
- `B 7900` Reset All Controllers
- `B 7B00` All Notes Off
- `B 80vv` Pitch Bend Range
- `B 81vv` Fine Tune
- `B 82vv` Coarse Tune

## Meta Commands

- `tpqn` Ticks Per Quarter Note (must be first)
- `mode` MIDI Mode / Reset (GM, GM2, GS, XG)
- `stop` End of Track (must be last)
- `sysx` Raw SysEx bytes
- `soff` All Sound Off (all channels)

Text:
- `text` Text Event
- `copy` Copyright / Artist
- `trck` Track Name
- `inst` Instrument / Synth / Soundfont
- `lyrc` Lyric
- `mark` Marker
- `cuep` Cue Point

## Keys

|     Octave | C  | C# | D  | D# | E  | F  | F# | G  | G# | A  | A# | B  |
|-----------:|----|----|----|----|----|----|----|----|----|----|----|----|
|      **0** | 00 | 01 | 02 | 03 | 04 | 05 | 06 | 07 | 08 | 09 | 0A | 0B |
|          1 | 0C | 0D | 0E | 0F | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 |
|          2 | 18 | 19 | 1A | 1B | 1C | 1D | 1E | 1F | 20 | 21 | 22 | 23 |
|          3 | 24 | 25 | 26 | 27 | 28 | 29 | 2A | 2B | 2C | 2D | 2E | 2F |
|      **4** | 30 | 31 | 32 | 33 | 34 | 35 | 36 | 37 | 38 | 39 | 3A | 3B |
| (Middle) 5 | 3C | 3D | 3E | 3F | 40 | 41 | 42 | 43 | 44 | 45 | 46 | 47 |
|          6 | 48 | 49 | 4A | 4B | 4C | 4D | 4E | 4F | 50 | 51 | 52 | 53 |
|          7 | 54 | 55 | 56 | 57 | 58 | 59 | 5A | 5B | 5C | 5D | 5E | 5F |
|      **8** | 60 | 61 | 62 | 63 | 64 | 65 | 66 | 67 | 68 | 69 | 6A | 6B |
|          9 | 6C | 6D | 6E | 6F | 70 | 71 | 72 | 73 | 74 | 75 | 76 | 77 |
|         10 | 78 | 79 | 7A | 7B | 7C | 7D | 7E | 7F |    |    |    |    |
