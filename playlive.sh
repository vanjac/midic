#!/bin/sh
set -eu

while read -r line; do
	while [ -n "$line" ]; do
		cmd=$(echo "$line" | cut -c 1)
		case $cmd in
			0|1|2|3|4|5|6|7)
				line=$(echo "$line" | cut -c 3-)
				;;
			8)
				channel=$(echo "$line" | cut -c 2)
				key=$(echo "$line" | cut -c 3-4)
				# Ignore velocity
				line=$(echo "$line" | cut -c 7-)
				echo "noteoff $((0x$channel)) $((0x$key))"
				;;
			9)
				channel=$(echo "$line" | cut -c 2)
				key=$(echo "$line" | cut -c 3-4)
				vel=$(echo "$line" | cut -c 5-6)
				line=$(echo "$line" | cut -c 7-)
				echo "noteon $((0x$channel)) $((0x$key)) $((0x$vel))"
				;;
			a|A)
				line=$(echo "$line" | cut -c 7-)
				;;
			b|B)
				channel=$(echo "$line" | cut -c 2)
				ctrl=$(echo "$line" | cut -c 3-4)
				val=$(echo "$line" | cut -c 5-6)
				line=$(echo "$line" | cut -c 7-)
				echo "cc $((0x$channel)) $((0x$ctrl)) $((0x$val))"
				;;
			c|C)
				channel=$(echo "$line" | cut -c 2)
				num=$(echo "$line" | cut -c 3-4)
				line=$(echo "$line" | cut -c 5-)
				echo "prog $((0x$channel)) $((0x$num))"
				;;
			d|D)
				line=$(echo "$line" | cut -c 5-)
				;;
			e|E)
				channel=$(echo "$line" | cut -c 2)
				lo=$(echo "$line" | cut -c 3-4)
				hi=$(echo "$line" | cut -c 5-6)
				line=$(echo "$line" | cut -c 7-)
				echo "pitch_bend $((0x$channel)) $((0x$lo + 128 * 0x$hi))"
				;;
			f|F)
				type=$(echo "$line" | cut -c 2)
				case $type in
					0)
						len=$(echo "$line" | cut -c 3-4)
						line=$(echo "$line" | cut -c $((5 + 2 * 0x$len))-)
						;;
					f|F)
						len=$(echo "$line" | cut -c 5-6)
						line=$(echo "$line" | cut -c $((7 + 2 * 0x$len))-)
						;;
					*)
						line=$(echo "$line" | cut -c 3-)
						;;
				esac
				;;
			*)
				line=$(echo "$line" | cut -c 2-)
				;;
		esac
	done
done | fluidsynth -q
