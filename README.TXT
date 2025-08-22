###What it is?####

An installer for appx/msix files on Linux using wine.

With thanks to benxyzzy for the hashing dependency


###How to build###

clone the repo and cd to the directory

run
	./getDependencies.sh

then run

	./installAppx.sh "<somefile>"


###Does winget work?###

No. See:

https://bugs.winehq.org/show_bug.cgi?id=53354