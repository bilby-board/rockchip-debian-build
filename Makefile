O=$(CURDIR)/out
B=$(CURDIR)/build

ROOTFS_DIR=$(B)/rootfs
SCRIPTS_DIR=$(CURDIR)/scripts
BOARDS_CONFIG_DIR=$(CURDIR)/conf

.PHONY: all

# tools
#
RKFLASHTOOL_SRCDIR=$(CURDIR)/sources/tools/rkflashtool
RKDEVELOPTOOL_SRCDIR=$(CURDIR)/sources/tools/rkdeveloptool

RKDEVELOPTOOL_BUILDDIR=$(B)/rkdeveloptool

TOOLS=rkflashtool rkdeveloptool

# entrypoints
#
.PHONY: all clean tools build install rootfs

all: tools
clean:
	$(MAKE) -C $(RKFLASHTOOL_SRCDIR) clean
	rm -rf $(O) $(B)

tools: $(patsubst %, $(O)/bin/%, $(TOOLS))

build: rootfs
install:

# boards
#
-include $(B)/boards.mk

# rootfs
#
rootfs: $(BOARDS_ROOTFS)

%/bin/sh: ROOTFS=$(patsubst %/bin/sh,%,$@)
%/bin/sh: $(SCRIPTS_DIR)/mkrootfs.sh
%/bin/sh:
	BOARD=$(BOARD) SOC=$(SOC) ARCH=$(ARCH) $(SCRIPTS_DIR)/mkrootfs.sh $(ROOTFS)

# mkflashtool
#
$(O)/bin/rkflashtool: $(O)
	@$(MAKE) -C $(RKFLASHTOOL_SRCDIR) PREFIX= DESTDIR=$(O) all install

# mkdeveloptool
#
$(RKDEVELOPTOOL_SRCDIR)/configure:
	cd $(@D); autoreconf -ivf

$(RKDEVELOPTOOL_BUILDDIR)/Makefile: $(RKDEVELOPTOOL_SRCDIR)/configure
	@mkdir -p $(@D)
	cd $(@D); $^ --prefix=

$(O)/bin/rkdeveloptool: $(RKDEVELOPTOOL_BUILDDIR)/Makefile $(O)
	@$(MAKE) -C $(^D) DESTDIR=$(O) install

# misc
#
$(O):
	mkdir -p $@

$(B)/boards.mk: $(SCRIPTS_DIR)/gen_boards_mk.sh $(BOARDS_CONFIG)
	@mkdir -p $(@D)
	$< $(BOARDS_CONFIG_DIR) > $@~
	mv $@~ $@
