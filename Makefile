O=$(CURDIR)/out

RKFLASHTOOL_SRCDIR=$(CURDIR)/sources/tools/rkflashtool

all: build install
clean:
	$(MAKE) -C $(RKFLASHTOOL_SRCDIR) clean
	rm -rf $(O)

build: build-rkflashtool
install: install-rkflashtool

# mkflashtool
#
build-rkflashtool:
	@$(MAKE) -C $(RKFLASHTOOL_SRCDIR) PREFIX= all
install-rkflashtool: $(O)
	@$(MAKE) -C $(RKFLASHTOOL_SRCDIR) PREFIX= DESTDIR=$(O) all install

$(O):
	mkdir $@
