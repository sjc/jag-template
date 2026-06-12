#
# Template for loading and executing GPU code from main RAM
#

include $(JAGSDK)/tools/build/jagdefs.mk

#
# Point to a copy of the repo https://github.com/42Bastian/new_bjl
#
BJL_ROOT = ../new_bjl/bin

#
# The ROM-based setup and load code
#
LOADOBJS = shared_storage.o startup.o init_olist.o olist.o gpures.o

#
# The main code which is copied to and run from RAM
#
SRCOBJS = shared_storage.o bootstrap.o gpures_funcs.o 

CGPUOBJS = jag.o

OBJS = $(SRCOBJS) $(CGPUOBJS)

#
# Our final target
#
PROGS = gim.j64

#
# Capture the addresses and function names PRINTed from gpures.s
#
gpures.o gpures_funcs.s &: gpures.s
	$(ASM) $(ASMFLAGS) $< > gpures_funcs.s

#
# Link the in-memory files into a .bin which is set to be loaded to and run from $8000 in RAM
#
ram.bin: $(OBJS)
	$(LINK) -r$(LINKALIGN) -w -m -z -n -a 4000 x x -o $@ $(OBJS) > ram.map

# TODO: compress this .bin, if we think it's necessary
# TODO: other resources which remain in ROM but are accessible (address known) from RAM

#
# Link the loader code plus the RAM .bin into a ROM
#
gim.rom: ram.bin $(LOADOBJS)
	$(eval BSSADDR := $(shell sed -r -n -f scripts/bssaddr.sed ram.map))
	$(LINK) -r$(LINKALIGN) -w -m -z -n -a 802000 x $(BSSADDR) -o $@ -i ram.bin ram_bin $(LOADOBJS) > rom.map

gim.j64: gim.rom
	@cat $(BJL_ROOT)/Univ.bin $< >$@
	@cat $< >> $@
	@bzcat $(BJL_ROOT)/allff.bin.bz2 >> $@
	@truncate -s 1M $@

GENERATED += ram.bin gim.rom $(LOADOBJS) ram.map rom.map

include $(JAGSDK)/tools/build/jagrules.mk

#
# Change `$(CGPUOBJS):%o:%c` stage to use vbcc
# Means all C files to be compiled to GPU code should be added to
# 	the CGPUOBJS list
#
CC_JRISC = vc +jrisc-ram
CFLAGS_JRISC = -k

$(CGPUOBJS):%o:%c
	$(CC_JRISC) $(CDEFS) $(CINCLUDES) $(CFLAGS_JRISC) -c -o $@ $<
