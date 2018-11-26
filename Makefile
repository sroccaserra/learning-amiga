hd/example: doc/amiga-assembly-crashcourse/source.asm doc/amiga-assembly-crashcourse/masters3.raw
	rm -f hd/example
	cd doc/amiga-assembly-crashcourse ; \
		vasmm68k_mot -kick1hunks -Fhunkexe -o ../../hd/example -nosym source.asm

hd/copperbars: doc/1-copperbars/c1.asm doc/1-copperbars/amigavikke.raw
	rm -f hd/copperbars
	cd doc/1-copperbars ; \
		vasmm68k_mot -kick1hunks -Fhunkexe -o ../../hd/copperbars -nosym c1.asm

run: hd/example hd/copperbars
	fs-uae configuration.fs-uae

