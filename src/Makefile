#
#
#
#   $Id$
#
#   Orginal Makefile by W. Wright 7/21/2002
#
#
#

../bin/efdb:	efdb.o
		mkdir -p  ../bin
		cc -lm -o ../bin/efdb efdb.o

###################################################################################
# gga2bin Convert ASCII NMEA gps message strings from ASCII to a Yorick friendly
# and readable format.  It also checks verifies the checksum produced by Ashtech
# gps receivers.  This program produces a file to be read b rbgga.i
###################################################################################
../bin/gga2bin:	gga2bin.o
		mkdir -p  ../bin
		cc -lm -o ../bin/gga2bin gga2bin.o



###################################################################################
# mkidx Generates an index (.idx) file which can be 
# used to access all the files from a mission as a single entity.
###################################################################################
../bin/mkidx:	mkidx.o
		mkdir -p  ../bin
		cc -lm -o ../bin/mkidx mkidx.o

###################################################################################
###################################################################################
../bin/pnav2ybin:	pnav2ybin.o
		mkdir -p  ../bin
		cc -lm -o ../bin/pnav2ybin pnav2ybin.o

###################################################################################
###################################################################################
../bin/tans2bin:	tans2bin.o
		mkdir -p  ../bin
		cc -lm -o ../bin/tans2bin tans2bin.o


###################################################################################
###################################################################################
all:		../bin/efdb ../bin/gga2bin ../bin/mkidx \
		../bin/pnav2ybin ../bin/tans2bin


