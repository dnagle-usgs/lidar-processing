# Batch processing Makefile
#

BIN = ../bin

var:
	@ echo
	@ echo "make batch    setup the system for batch processing"
	@ echo

ifeq (${USER}, root)
/etc/init.d/batcher:  initd-batcher.sh
	install -m uog+rx  $< $@
	@echo
	@echo "You may need to manually run:"
	@echo "   ln -s /etc/init.d/batcher /etc/rc2.d/S99batcher"
else
/etc/init.d/batcher:  initd-batcher.sh
	@echo
	@echo "WARNING: need root priviledges!!"
	@echo "   to install $@"
	@echo "WARNING"
	@echo 
endif

../bin/setup_batch: setup_batch.pl
	install -m uog+rx  $< $@


scripts:
	../bin/setup_batch 		\
	/etc/init.d/batcher 	\

batch: 									\
		../bin/setup_batch
		../bin/setup_batch

all:	scripts
