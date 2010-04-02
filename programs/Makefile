#   Original Makefile by W. Wright 7/21/2002

SHELL = /bin/sh
prefix = ../..
bindir = $(prefix)/bin

var:
	@ echo "make all         to compile all programs"
	@ echo "make install     to install programs"
	@ echo "make clean       to remove temporary files"
	@ echo "make rebuild     to force recompile all programs"
	@ echo "make reinstall   to force recompile and reinstall"

# erange  This is a "C" program which reads raw EAARL data from a single file
# and extracts range data. It's an old program not used for anything, but does
# show how to make a "C" program for reading data directly from a data file.
#
# gga2bin Convert ASCII NMEA gps message strings from ASCII to a Yorick friendly
# and readable format.  It also checks verifies the checksum produced by Ashtech
# gps receivers.  This program produces a file to be read b rbgga.i
#
# mkidx Generates an index (.idx) file which can be
# used to a$(CC)ess all the files from a mission as a single entity.
#
# pnav2ybin Converts an Ashtech "PNAV" ascii file to a binary format
# which can be read by rbpnav.i
#
# tans2bin Converts a tansvector ASCII data file captured by the EAARL realtime
# software into a binary file which can be read by rbtans.i
#
# pospac2ybin Converts a pospac SBET data file produced by pospac
# software into a binary file which can be read by rbsbet.i
#
# fix-dos-crlf-ash.c  Removes CRLF pairs and replaces them with LF only.

# All programs to be installed
PROGS = efdb erange gga2bin mkidx pnav2ybin tans2bin fix-dos-crlf-ash \
	rdmars dmars2iex dmarscat2iex pospac2ybin

# Programs that require the math library (-lm)
NEEDSMATH = tans2bin dmars2iex

$(filter-out $(NEEDSMATH),$(PROGS)) : % : %.o
	$(CC) -o $@ $<

$(NEEDSMATH) : % : %.o
	$(CC) -lm -o $@ $<

all: $(PROGS)

rebuild: clean all

reinstall: rebuild install

clean:
	$(RM) *~ '#'* *.o core a.out $(PROGS)

$(bindir):
	mkdir $(bindir)

install: all $(bindir)
	install -c $(PROGS) $(bindir)/

uninstall:
	-cd $(bindir) && $(RM) $(PROGS)
