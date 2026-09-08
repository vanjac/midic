%.mid: %.hex
	rm -f "$@"
	python midic.py -f smf -i "$<" -o "$@"
