#
#
#
#   $Id$
#
#   Orginal Makefile by W. Wright 7/21/2002
# 
#
#
#

../bin/efdb:	efdb.o
		mkdir -p  ../bin
		cc -lm -o ../bin/efdb efdb.o

###############################################################################
# gga2bin Convert ASCII NMEA gps message strings from ASCII to a Yorick friendly
# and readable format.  It also checks verifies the checksum produced by Ashtech
# gps receivers.  This program produces a file to be read b rbgga.i
###############################################################################
../bin/gga2bin:	gga2bin.o
		mkdir -p  ../bin
		cc -lm -o ../bin/gga2bin gga2bin.o



###############################################################################
# mkidx Generates an index (.idx) file which can be 
# used to access all the files from a mission as a single entity.
###############################################################################
../bin/mkidx:	mkidx.o
		mkdir -p  ../bin
		cc -lm -o ../bin/mkidx mkidx.o



###############################################################################
# pnav2ybin Converts an Ashtech "PNAV" ascii file to a binary format 
# which can be read by rbpnav.i
###############################################################################
../bin/pnav2ybin:	pnav2ybin.o
		mkdir -p  ../bin
		cc -lm -o ../bin/pnav2ybin pnav2ybin.o




###############################################################################
# tans2bin Converts a tansvector ASCII data file captured by the EAARL realtime
# software into a binary file which can be read by rbtans.i
###############################################################################
../bin/tans2bin:	tans2bin.o
		mkdir -p  ../bin
		cc -lm -o ../bin/tans2bin tans2bin.o

###############################################################################
# rdmars
###############################################################################
../bin/rdmars:	rdmars.o
		cc -lm -o ../bin/rdmars rdmars.o
	

###############################################################################
# dmars
###############################################################################
../bin/dmars2iex:	dmars2iex.o
		cc -lm -o ../bin/dmars2iex tans2bin.o
	
###############################################################################
# pospac2ybin Converts a pospac SBET data file produced by pospac 
# software into a binary file which can be read by rbsbet.i
###############################################################################
../bin/pospac2ybin:	pospac2ybin.o
		mkdir -p  ../bin
		cc -lm -o ../bin/pospac2ybin pospac2ybin.o



###############################################################################
# all  Builds all the "C" programs in this directory that need it.  You can force
###############################################################################
all:		../bin/efdb ../bin/gga2bin ../bin/mkidx \
		../bin/pnav2ybin ../bin/tans2bin \
		../bin/rdmars ../bin/dmars2iex




###############################################################################
# rebuildall  Force a rebuild of all the "C" programs here.
###############################################################################
rebuildall:	all
		touch *.o
		make all
		



