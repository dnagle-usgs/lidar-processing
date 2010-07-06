# You'll need both of these:
#    make.darwin
#    make.solaris

# include make.$(OSTYPE)

# programs that we expect to be invoked by the user are put in NST
# programs that are only invoked by other programs  are put in CST

SRC = ./Source
DST = ./bin
NST = /usr/local/p
# CST = /usr/local/p/cambot

%.o:	$(SRC)/%.c
	$(CC) -c $(CFLAGS) $<

###########################

all:                             \
	$(DST)                         \
	$(DST)/fixup                   \
	$(DST)/makecam                 \
	$(DST)/makecir                 \

#install:                         \
#	$(NST)/fixup                   \
#	$(NST)/makecam                 \
#	$(NST)/makecir                 \

###########################

$(DST):
	@ echo making $(DST)
	@ mkdir $(DST)

#$(CST):
#	@ echo making $(CST)
#	@ mkdir $(CST)

#######


$(DST)/fixup:	$(SRC)/fixup.pl
	cp -p	$(SRC)/fixup.pl $@
	@ chmod ugo+x $@

$(DST)/makecam:	$(SRC)/makecam.pl
	cp -p	$(SRC)/makecam.pl $@
	@ chmod ugo+x $@

$(DST)/makecir:	$(SRC)/makecir.pl
	cp -p	$(SRC)/makecir.pl $@
	@ chmod ugo+x $@

###########################

$(NST)/fixup:	$(DST)/fixup
	cp -p	$(DST)/fixup $@

$(NST)/makecam:	$(DST)/makecam
	cp -p	$(DST)/makecam $@

$(NST)/makecir:	$(DST)/makecir
	cp -p	$(DST)/makecir $@

