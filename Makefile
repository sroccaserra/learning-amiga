hd/learning: src/learning.asm
	vasmm68k_mot -kick1hunks -Fhunkexe -chklabels -x -quiet -o hd/learning -nosym src/learning.asm

hd/example: doc/amiga-assembly-crashcourse/source.asm doc/amiga-assembly-crashcourse/masters3.raw
	rm -f hd/example
	cd doc/amiga-assembly-crashcourse ; \
		vasmm68k_mot -kick1hunks -chklabels -x -quiet -Fhunkexe -o ../../hd/example -nosym source.asm

hd/copperbars: doc/1-copperbars/c1.asm doc/1-copperbars/amigavikke.raw
	rm -f hd/copperbars
	cd doc/1-copperbars ; \
		vasmm68k_mot -kick1hunks -Fhunkexe -o ../../hd/copperbars -nosym c1.asm

hd/horizontalshift: doc/2-horizontalshift/h1.asm doc/2-horizontalshift/amigavikke_new.raw
	rm -f hd/horizontalshift
	cd doc/2-horizontalshift ; \
		vasmm68k_mot -kick1hunks -Fhunkexe -o ../../hd/horizontalshift -nosym h1.asm

hd/copperroller: doc/3-copperroller/c2.asm doc/3-copperroller/av.raw
	rm -f hd/copperroller
	cd doc/3-copperroller ; \
		vasmm68k_mot -kick1hunks -Fhunkexe -o ../../hd/copperroller -nosym c2.asm

hd/copperrollerbig: doc/4-copperroller-big/c3.asm doc/4-copperroller-big/amigavikke-flowers.raw
	rm -f hd/copperrollerbig
	cd doc/4-copperroller-big ; \
		vasmm68k_mot -kick1hunks -Fhunkexe -o ../../hd/copperrollerbig -nosym c3.asm

hd/horizontalscroller: doc/5-horizontalscroller/s1.asm doc/5-horizontalscroller/font.raw
	cd doc/5-horizontalscroller ; \
		vasmm68k_mot -kick1hunks -Fhunkexe -o ../../hd/horizontalscroller -nosym s1.asm

.PHONY: build
build: hd/learning hd/example hd/copperbars hd/horizontalshift hd/copperroller hd/copperrollerbig hd/horizontalscroller

run:
	fs-uae configuration.fs-uae

