#!/bin/bash

if [ -z "${1}" ]; then
	exit 255
fi

if [ "${1}" -le 0 ] || [ "${1}" -gt 65535 ]; then
	exit 255
fi

netstat -an \
	| grep LISTEN \
	| awk '{print substr($4,match($4, "\\\.[^\.]*$") ? RSTART + 1 : 0);}' \
	| sort -n \
	| uniq \
	| grep -q "${1}"
