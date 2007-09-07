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

BIN = ../bin

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
		mkdir -p  ../bin
		cc -lm -o ../bin/rdmars rdmars.o
	

###############################################################################
# dmarscat2iex
###############################################################################
../bin/dmarscat2iex:	dmarscat2iex.o
		mkdir -p  ../bin
		cc -lm -o ../bin/dmarscat2iex dmarscat2iex.o
	
###############################################################################
# dmars
###############################################################################
#### bin_dmars2iex:	../bin/dmars2iex

../bin/dmars2iex:	dmars2iex.o
	$(CC) -c dmars2iex.c
	mkdir -p  ../bin
	cc -lm -o $@ dmars2iex.o
	
###############################################################################
# pospac2ybin Converts a pospac SBET data file produced by pospac 
# software into a binary file which can be read by rbsbet.i
###############################################################################
../bin/pospac2ybin:	pospac2ybin.o
		mkdir -p  ../bin
		cc -lm -o ../bin/pospac2ybin pospac2ybin.o


../bin/ytk:	ytk
	cp ytk ../bin/ytk
	chmod uog+rx ../bin/ytk

../bin/checksys:	checksys
	cp $<	$@

../bin/shapefile_filter:	shapefile_filter.pl
	install -m uog+rx  $<	$@

<<<<<<< destination
=======
../bin/showdays:	showdays
	install -m uog+rx  $<	$@

../bin/mk_opsconf:	mk_opsconf
	install -m uog+rx  $<	$@

../bin/wrsync:	wrsync
	install -m uog+rx  $<	$@

../bin/mktrajfiles:	mktrajfiles
	install -m uog+rx  $<	$@

../bin/pnav2kml:	pnav2kml.pl
	install -m uog+rx  $<	$@

../bin/pnav2gm:	pnav2gm.pl
	install -m uog+rx  $<	$@

../bin/iex_ascii2pbd:	iex_ascii2pbd
	install -m uog+rx  $<	$@

../bin/mkeidx:	mkeidx
	install -m uog+rx  $<	$@

../bin/xyz2track:	xyz2track.pl
	install -m uog+rx  $<	$@


# It is very hard to make make make a #
../bin/comment:	comment
	install -m uog+rx  $<	$@
	ln ../bin/comment ../bin/\#

>>>>>>> evolving
###############################################################################
# all  Builds all the "C" programs in this directory that need it.  You can force
###############################################################################
<<<<<<< destination
all:		../bin/efdb ../bin/gga2bin ../bin/mkidx ../bin/pnav2ybin \
		../bin/tans2bin ../bin/rdmars ../bin/dmars2iex           \
		../bin/dmarscat2iex ../bin/checksys                      \
		../bin/shapefile_filter
=======
all:		../bin/efdb ../bin/erange ../bin/gga2bin ../bin/mkidx    \
		../bin/pnav2ybin ../bin/tans2bin ../bin/fix-dos-crlf-ash \
		../bin/rdmars ../bin/dmars2iex ../bin/dmarscat2iex       \
		../bin/check_to_archive ../bin/checksys                  \
		../bin/shapefile_filter                                  \
		../bin/showdays ../bin/mk_opsconf ../bin/wrsync          \
		../bin/mktrajfiles                                       \
		../bin/pnav2kml                                          \
		../bin/pnav2gm                                           \
		../bin/mkeidx                                            \
		../bin/iex_ascii2pbd                                     \
		../bin/xyz2track                                         \
		../bin/comment
>>>>>>> evolving


###############################################################################
# rebuildall  Force a rebuild of all the "C" programs here.
###############################################################################
rebuildall:	all
		touch *.o
		make all
		

