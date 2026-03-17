%.mid: %.hex
	sh midic.sh "$@" < "$<"
