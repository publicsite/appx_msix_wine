#!/bin/sh

cd "$(dirname "$(realpath "$0")")"

if [ ! -d "deps" ]; then
mkdir deps
fi

cd deps

wget "https://raw.githubusercontent.com/benxyzzy/pubid/refs/heads/master/pubid.py" -O pubid_new.py

if [ -f "pubid_new.py" ]; then
	if [ -f "pubid.py" ]; then
		rm "pubid.py"
	fi

	mv "pubid_new.py" "pubid.py"
	chmod +x "pubid.py"
fi

cd ..