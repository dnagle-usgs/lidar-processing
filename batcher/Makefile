# Batch processing Makefile
#

# push the directory to the same leval as lidar-processing
BIN = ../../bin

#var:
#	@ echo
#	@ echo "make batch    setup the system for batch processing"
#	@ echo

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
	@echo "WARNINGd
	@echo 
endif

$(BIN)/setup_batch: setup_batch.pl
	install -m uog+rx  $< $@


scripts:
	$(BIN)/setup_batch 		\
	/etc/init.d/batcher 	\

batch: 									\
		$(BIN)/setup_batch
		$(BIN)/setup_batch

all:	scripts
