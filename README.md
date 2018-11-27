Work in progress, trying to understand these examples & guides:

- <https://www.reaktor.com/blog/crash-course-to-amiga-assembly-programming/>
- <http://vikke.net/index.php?id=copperbars-1>
- <http://coppershade.org/>
- <https://www.youtube.com/watch?v=p83QUZ1-P10&list=PLc3ltHgmiidpK-s0eP5hTKJnjdTHz0_bW>
- [Amiga Hardware Reference Manual](http://amigadev.elowar.com/read/ADCD_2.1/Hardware_Manual_guide/node0000.html)

To build the programs, I use [vasm](http://sun.hasenbraten.de/vasm/) to build the binaries in the `hd` dir, see Makefile for info.

To run the programs, I use the [FS-UAE](https://fs-uae.net/) emulator by mounting the `hd` dir and running the examples from an Amiga shell. I'm using an Amiga 500 configuration with a 1.3 Kickstart, booting with a Workbench 1.34 disk, see the FS-UAE config file.
