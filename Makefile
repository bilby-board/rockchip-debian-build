O=$(CURDIR)/out
B=$(CURDIR)/build

SCRIPTS_DIR=$(CURDIR)/scripts

RKFLASHTOOL_SRCDIR=$(CURDIR)/sources/tools/rkflashtool
RKDEVELOPTOOL_SRCDIR=$(CURDIR)/sources/tools/rkdeveloptool

RKDEVELOPTOOL_BUILDDIR=$(B)/rkdeveloptool

.PHONY: all clean build install rootfs

all: build install
clean:
	$(MAKE) -C $(RKFLASHTOOL_SRCDIR) clean
	rm -rf $(O) $(B)

build: build-rkflashtool build-rkdeveloptool rootfs
install: install-rkflashtool install-rkdeveloptool

# rootfs
#
rootfs:

%/bin/sh: ROOTFS=$(patsubst %/bin/sh,%,$@)
%/bin/sh: $(SCRIPTS_DIR)/mkrootfs.sh
%/bin/sh:
	BOARD=$(BOARD) SOC=$(SOC) $(SCRIPTS_DIR)/mkrootfs.sh $(ROOTFS)

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
