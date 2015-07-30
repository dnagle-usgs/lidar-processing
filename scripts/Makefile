SHELL = /bin/sh
INSTALL = /usr/bin/install

prefix = ../..
bindir = $(prefix)/bin

ROOTPATH = $(shell pwd)

message:
	@echo "make install           to install copies of all scripts"

DST_BARE = \
	check_to_archive \
	comment \
	eaarl_md5sum \
	hgr \
	idx_tiles_summarize \
	iex_ascii2pbd \
	mk_opsconf \
	mkcamlist \
	mkeidx \
	mktrajfiles \
	showdays \
	test_checksum \
	vncpl \
	wrsync \

DST_AWK = \
	clean \
	htdp \

DST_PL = \
	ascii_rename \
	check_for_tlds \
	check_mission \
	geotiffer \
	get_location \
	make_html_tiles \
	make_xml_metadata \
	pnav2gm \
	pnav2kml \
	shapefile_filter \
	show_doc \
	xyz2track \

DST_PY = \
	initialize_cir \

DST_ALL = $(DST_BARE) $(DST_AWK) $(DST_PL) $(DST_PY)

SRC_BARE = $(DST_BARE)
SRC_AWK = $(addsuffix .awk,$(DST_AWK))
SRC_PL = $(addsuffix .pl,$(DST_PL))
SRC_PY = $(addsuffix .py,$(DST_PY))

SRC_ALL = $(SRC_BARE) $(SRC_AWK) $(SRC_PL) $(SRC_PY)

SYMLINKS = \\\#

$(bindir):
	mkdir $(bindir)

install: $(bindir) $(bindir)/\# $(addprefix $(bindir)/,$(DST_ALL))

$(addprefix $(bindir)/,$(DST_BARE)): $(bindir)/%: %
	$(INSTALL) $< $@

$(addprefix $(bindir)/,$(DST_AWK)): $(bindir)/%: %.awk
	$(INSTALL) $< $@

$(addprefix $(bindir)/,$(DST_PL)): $(bindir)/%: %.pl
	$(INSTALL) $< $@

$(addprefix $(bindir)/,$(DST_PY)): $(bindir)/%: %.py
	$(INSTALL) $< $@

$(bindir)/\#: $(bindir)/comment
	ln -sf comment $@

clean:

uninstall:
	-cd $(bindir) && $(RM) $(DST_ALL) $(SRC_ALL) $(SYMLINKS)
