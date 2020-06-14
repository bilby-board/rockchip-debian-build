O=$(CURDIR)/out
B=$(CURDIR)/build

RKFLASHTOOL_SRCDIR=$(CURDIR)/sources/tools/rkflashtool
RKDEVELOPTOOL_SRCDIR=$(CURDIR)/sources/tools/rkdeveloptool

RKDEVELOPTOOL_BUILDDIR=$(B)/rkdeveloptool

all: build install
clean:
	$(MAKE) -C $(RKFLASHTOOL_SRCDIR) clean
	rm -rf $(O) $(B)

build: build-rkflashtool build-rkdeveloptool
install: install-rkflashtool install-rkdeveloptool

# mkflashtool
#
build-rkflashtool:
	@$(MAKE) -C $(RKFLASHTOOL_SRCDIR) PREFIX= all
install-rkflashtool: $(O)
	@$(MAKE) -C $(RKFLASHTOOL_SRCDIR) PREFIX= DESTDIR=$(O) all install

# mkdeveloptool
#
$(RKDEVELOPTOOL_SRCDIR)/configure:
	cd $(@D); autoreconf -ivf

$(RKDEVELOPTOOL_BUILDDIR)/Makefile: $(RKDEVELOPTOOL_SRCDIR)/configure
	mkdir -p $(@D)
	cd $(@D); $^ --prefix=

build-rkdeveloptool: $(RKDEVELOPTOOL_BUILDDIR)/Makefile
	$(MAKE) -C $(^D)

install-rkdeveloptool: $(RKDEVELOPTOOL_BUILDDIR)/Makefile $(O)
	$(MAKE) -C $(^D) DESTDIR=$(O) install

$(O):
	mkdir -p $@
