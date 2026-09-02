#!/bin/sh
set -eu

while read -r line; do
	while [ -n "$line" ]; do
		cmd=$(echo "$line" | cut -c 1)
		case $cmd in
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
			e|E)
				channel=$(echo "$line" | cut -c 2)
				lo=$(echo "$line" | cut -c 3-4)
				hi=$(echo "$line" | cut -c 5-6)
				line=$(echo "$line" | cut -c 7-)
				echo "pitch_bend $((0x$channel)) $((0x$lo + 128 * 0x$hi))"
				;;
			*)
				line=$(echo "$line" | cut -c 2-)
				;;
		esac
	done
done | fluidsynth -q
