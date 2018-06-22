SHELL = /bin/sh
INSTALL = /usr/bin/install

prefix = ../..
bindir = $(prefix)/bin

ROOTPATH = $(shell pwd)

message:
	@echo "make install           to install copies of all scripts"

# A list of all scripts to install. Leave the file extension off.
SCRIPTS = \
	ascii_rename \
	check_mission \
	check_to_archive \
	clean \
	comment \
	eaarl_md5sum \
	geotiffer \
	get_location \
	hgr \
	htdp \
	idx_tiles_summarize \
	iex_ascii2pbd \
	initialize_cir \
	make_html_tiles \
	make_xml_metadata \
	mk_opsconf \
	mkeidx \
	mktrajfiles \
	mvbu \
	pnav2gm \
	pnav2kml \
	shapefile_filter \
	show_doc \
	showdays \
	test_checksum \
	vncpl \
	wrsync \
	xyz2track \

# Symlinks. Each is handled by a special rule, but they are added to this list
# to make uninstall easier.
# This should contain #, but it seems impossible to add it to the list without
# causing escaping issues.
SYMLINKS = cpbu

# Things that used to be installed, but aren't any longer. This makes sure they
# get removed by uninstall.
HISTORICAL = \
	ascii_rename.pl \
	check_for_tlds.pl \
	check_mission.pl \
	clean.awk \
	geotiffer.pl \
	get_location.pl \
	htdp.awk \
	initialize_cir.py \
	make_html_tiles.pl \
	make_xml_metadata.pl \
	mvbu.pl \
	pnav2gm.pl \
	pnav2kml.pl \
	shapefile_filter.pl \
	show_doc.pl \
	xyz2track.pl \

$(bindir):
	mkdir $(bindir)

install: $(bindir) $(addprefix $(bindir)/,$(SCRIPTS) $(SYMLINKS) \#)

$(bindir)/%: %.awk
	$(INSTALL) $< $@

$(bindir)/%: %.pl
	$(INSTALL) $< $@

$(bindir)/%: %.py
	$(INSTALL) $< $@

$(bindir)/\\\#: $(bindir)/comment
	ln -sf comment '$(bindir)/#'

$(bindir)/cpbu: $(bindir)/mvbu
	ln -sf mvbu $(bindir)/cpbu

$(bindir)/%: %
	$(INSTALL) $< $@

clean:

uninstall:
	-cd $(bindir) && $(RM) $(SCRIPTS) $(HISTORICAL) '#' $(SYMLINKS)
