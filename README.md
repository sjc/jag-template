# Jaguar GPU-in-main Project Template

This is a template project for building games for the Atari Jaguar. If you want a simple, powerful, and comprehensive way to build Jaguar games, you probably want [JagStudio](https://reboot-games.com/jagstudio/). If instead you like to experiment with stuff that breaks if you look at it funny, this may be of interest.

This project uses [VBCC](http://www.compilers.de/vbcc.html) to build JRISC code for the Jaguar's GPU, which is then run (mainly) from the main memory.

## Dependencies

### Jaguar SDK

This project started off as [one of the example projects](https://github.com/cubanismo/jaguar-sdk/tree/master/jaguar/examples/jag256) found in the [Jaguar SDK](https://github.com/cubanismo/jaguar-sdk). It requires the tools and Makefile include files the SDK provides in order to build.

### VBCC

The JRISC compiler part of [VBCC](http://www.compilers.de/vbcc.html) is currently under development. It can be found in a separate archive near the bottom of the linked page. See [this AtariAge thread](https://forums.atariage.com/topic/390240-vbcc-optimizing-c-compiler-now-supports-jaguar-risc-and-68k/) for more details.

Please ensure that you follow the instructions in the README in the .zip to correctly set up the `VBCC` and `PATH` environment.

### New JBL

Files from the [new BJL](https://github.com/42Bastian/new_bjl) are used to produce the final .j64 file. Update the parameter in the Makefile to point to where you have the repo checked-out.

## Building

`make`

## Project Structure

The project consists of two main parts: Game code, which will be run from RAM, and loader code which will be run at start from ROM, copy the main code into RAM, and run it.
