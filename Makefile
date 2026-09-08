%.mid: %.hex
	rm -f "$@"
	python3 midic.py -f smf -i "$<" -o "$@"
