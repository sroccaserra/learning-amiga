
hd/example: doc/amiga-assembly-crashcourse/source.asm doc/amiga-assembly-crashcourse/masters3.raw
	rm -f hd/example
	cd doc/amiga-assembly-crashcourse ; \
		vasmm68k_mot -kick1hunks -Fhunkexe -o ../../hd/example -nosym source.asm

hd/c1: doc/1-copperbars/c1.asm doc/1-copperbars/amigavikke.raw
	rm -f hd/c1
	cd doc/1-copperbars ; \
		vasmm68k_mot -kick1hunks -Fhunkexe -o ../../hd/c1 -nosym c1.asm

hd/h1: doc/2-horizontalshift/h1.asm doc/2-horizontalshift/amigavikke_new.raw
	rm -f hd/h1
	cd doc/2-horizontalshift ; \
		vasmm68k_mot -kick1hunks -Fhunkexe -o ../../hd/h1 -nosym h1.asm

run: hd/example hd/c1 hd/h1
	fs-uae configuration.fs-uae

