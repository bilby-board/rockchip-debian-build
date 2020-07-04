O=$(CURDIR)/out
B=$(CURDIR)/build
S=$(CURDIR)/sources

ROOTFS_DIR=$(B)/rootfs
SCRIPTS_DIR=$(CURDIR)/scripts
BOARDS_CONFIG_DIR=$(CURDIR)/conf

LINUX_SRCDIR=$(S)/linux/linux-rockchip
UBOOT_SRCDIR=$(S)/u-boot/u-boot-rockchip

GEN_BOARDS_MK_SH = $(SCRIPTS_DIR)/gen_boards_mk.sh

.PHONY: all

# tools
#
RKFLASHTOOL_SRCDIR=$(S)/tools/rkflashtool
RKDEVELOPTOOL_SRCDIR=$(S)/tools/rkdeveloptool

RKDEVELOPTOOL_BUILDDIR=$(B)/rkdeveloptool

TOOLS=rkflashtool rkdeveloptool

# entrypoints
#
.PHONY: all clean tools build install rootfs kernel uboot

all: tools kernel uboot
clean:
	$(MAKE) -C $(RKFLASHTOOL_SRCDIR) clean
	rm -rf $(O) $(B)

tools: $(patsubst %, $(O)/bin/%, $(TOOLS))

build: tools kernel rootfs
install:

# boards
#
-include $(B)/boards.mk

# linux
#
kernel: $(BOARDS_KERNEL)
uboot: $(BOARDS_UBOOT)

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

$(B)/boards.mk: $(GEN_BOARDS_MK_SH) $(BOARDS_CONFIG)
	@mkdir -p $(@D)
	$< $(BOARDS_CONFIG_DIR) > $@~
	mv $@~ $@
