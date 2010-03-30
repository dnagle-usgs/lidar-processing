SHELL = /bin/sh

prefix = ..
bindir = $(prefix)/bin

ROOTPATH = $(shell pwd)

message:
	@echo "make install           to install copies of all scripts"
	@echo "make install-linked    to install links to scripts here"

SCRIPTS = ascii_rename.pl check_for_tlds.pl checksys check_to_archive \
	clean.awk comment eaarl_md5sum geotiffer.pl get_location.pl htdp.awk \
	idx_tiles_summarize iex_ascii2pbd initialize_cir.py \
	make_html_tiles.pl makeweb make_xml_metadata.pl mkcamlist mkeidx \
	mk_opsconf mktrajfiles pnav2gm.pl pnav2kml.pl pto_cir.pl \
	shapefile_filter.pl showdays show_doc.pl test_checksum vncpl \
	whatsnew.pl wrsync xyz2track.pl

$(bindir):
	mkdir $(bindir)

install: $(bindir)
	@for script in $(SCRIPTS); do \
		echo install -c $(ROOTPATH)/$$script $(bindir)/$$script; \
		install -c $(ROOTPATH)/$$script $(bindir)/$$script; \
	done

install-linked: $(bindir)
	@for script in $(SCRIPTS); do \
		echo ln -s $(ROOTPATH)/$$script $(bindir)/$$script; \
		ln -s $(ROOTPATH)/$$script $(bindir)/$$script; \
	done

clean:

uninstall:
	-cd $(bindir) && $(RM) $(SCRIPTS)
