#!/bin/sh

set -eu

config_dir="${1:-$(cd "$(dirname "$0")/../conf" && pwd)}"

BOARDS_CONFIG="$(ls -1 "$config_dir"/*.conf | sort -V)"
BOARDS="$(ls -1 "$config_dir"/*.conf | sort -V | sed -e 's|.*/\([^/]\+\)\.conf$|\1|')"

if [ -z "$BOARDS" ]; then
	echo "$config_dir: no board config found" >&2
	exit 1
fi

set_list() {
	local k="$1" v=
	shift

	if [ $# -gt 1 ]; then
		v="$(echo "$*" | tr ' ' '|' | sed -e 's/|$/\n/' -e 's|^|\\\n\t|' -e 's/|/ \\\n\t/g')"
	else
		v="${1:-}"
	fi

	echo "$k =${v:+ $v}"
}

board_config_fullname() {
	local dir="$1" x=
	shift

	for x; do
		echo "$dir/$x.conf"
	done
}

varify() {
	echo "$*" | tr 'a-z -' 'A-Z__'
}

guess_soc() {
	case "$1" in
	*rk3399*) echo "rk3399" ;;
	*rk3288*) echo "rk3288" ;;
	esac
}

guess_arch() {
	case "${2:-}" in
	*armhf*) echo "armhf" ;;
	*armel*) echo "armel" ;;
	*arm64*) echo "arm64" ;;
	*)
		case "$1" in
		rk3399)
			echo "arm64" ;;
		rk3288)
			echo "armhf" ;;
		esac
		;;
	esac
}

guess_loadaddr() {
	case "${1:-}" in
	rk3288|rk3399) echo 0x02000000 ;;
	esac
}

guess_entrypoint() {
	# use loadaddr
	echo ""
}

gen_board_kernel() {
	local soc= arch=
	local builddir= BUILDDIR= MAKEARGS= LOADADDR= ENTRYPOINT=
	local image_file=
	local cross_compile= cross32_compile=
	local uimage_loadaddre= uimage_entrypoint=

	soc=${SOC:-$(guess_soc $id)}
	arch=${ARCH:-$(guess_arch $soc)}

	builddir="\$(B)/linux/$id"
	BUILDDIR="KERNEL_${ID}_BUILDDIR"
	MAKEARGS="KERNEL_${ID}_MAKE_ARGS"
	LOADADDR="UIMAGE_${ID}_LOADADDR"
	ENTRYPOINT="UIMAGE_${ID}_ENTRYPOINT"

	case "$arch" in
	arm64)
		cross_compile=aarch64-linux-gnu-
		cross32_compile=arm-linux-gnueabihf-
		;;
	armhf)
		cross_compile=arm-linux-gnueabihf-
		arch=arm
		;;
	armel)
		cross_compile=arm-linux-gnueabi-
		arch=arm
		;;
	esac

	image_file=arch/$arch/boot/Image
	uimage_loadaddr=${UIMAGE_LOADADDR:-$(guess_loadaddr $soc)}
	uimage_entrypoint=${UIMAGE_ENTRYPOINT:-$(guess_entrypoint $soc $uimage_loadaddr)}

	cat <<EOT
#
# $id (linux)
#
$BUILDDIR = $builddir
$LOADADDR = ${uimage_loadaddr:-}
$ENTRYPOINT = ${uimage_entrypoint:-\$($LOADADDR)}

$MAKEARGS = -C \$(LINUX_SRCDIR) O=\$($BUILDDIR) ARCH=$arch${cross_compile:+ CROSS_COMPILE=$cross_compile}${cross32_compile:+ CROSS32_COMPILE=$cross32_compile}

\$($BUILDDIR)/.config: \$(LINUX_SRCDIR)/Makefile \$(GEN_BOARDS_MK_SH)
	@mkdir -p \$(@D)
	if [ -s \$@ ]; then \\
		\$(MAKE) \$($MAKEARGS) oldconfig; \\
	elif [ -s \$(BOARDS_CONFIG_DIR)/$id/defconfig ]; then \\
		cp \$(BOARDS_CONFIG_DIR)/$id/defconfig \$@; \\
		\$(MAKE) \$($MAKEARGS) olddefconfig; \\
	${LINUX_CONFIG:+elif [ -s \$(LINUX_SRCDIR)/arch/$arch/configs/${LINUX_CONFIG}_defconfig ]; then \\
		\$(MAKE) \$($MAKEARGS) ${LINUX_CONFIG}_defconfig; \\
	}else \\
		\$(MAKE) \$($MAKEARGS) defconfig; \\
	fi

\$($BUILDDIR)/$image_file: \$($BUILDDIR)/.config \$(GEN_BOARDS_MK_SH)
	\$(MAKE) \$($MAKEARGS) \$(@F)

\$($BUILDDIR)/uImage: \$($BUILDDIR)/$image_file \$(GEN_BOARDS_MK_SH)
	\$(MKIMAGE) -A $arch -O linux -C \$(UIMAGE_COMP) -T kernel -a \$($LOADADDR) -e \$($ENTRYPOINT) -n $id -d \$< \$@

.PHONY: kernel-$id kernel-$id-cmd kernel-$id-savedefconfig
.PHONY: kernel-$id-menucconfig

kernel-$id: \$($BUILDDIR)/uImage

kernel-$id-cmd: \$($BUILDDIR)/.config
	\$(MAKE) \$($MAKEARGS) \$(CMD)

kernel-$id-savedefconfig: \$($BUILDDIR)/.config
	\$(MAKE) \$($MAKEARGS) savedefconfig${LINUX_CONFIG:+
	cp \$($BUILDDIR)/defconfig \$(LINUX_SRCDIR)/arch/$arch/configs/${LINUX_CONFIG}_defconfig}
	@mkdir -p \$(BOARDS_CONFIG_DIR)/$id
	mv \$($BUILDDIR)/defconfig \$(BOARDS_CONFIG_DIR)/$id/defconfig

kernel-$id-menuconfig: \$($BUILDDIR)/.config
	\$(MAKE) \$($MAKEARGS) menuconfig

EOT

	BOARDS_KERNEL="${BOARDS_KERNEL:+$BOARDS_KERNEL }kernel-$id"
}

gen_board_uboot() {
	local soc= arch=
	local builddir= BUILDDIR=
	local makeargs= MAKEARGS=
	local TFA= TFA_BUILDDIR=
	local cross_compile= m0_cross_compile=

	soc=${SOC:-$(guess_soc $id)}
	arch=${ARCH:-$(guess_arch $soc)}

	builddir="\$(B)/u-boot/$id"
	BUILDDIR="UBOOT_${ID}_BUILDDIR"
	MAKEARGS="UBOOT_${ID}_MAKEARGS"
	TFA_BUILDDIR="TFA_${ID}_BUILDDIR"

	case "$arch" in
	arm64)
		cross_compile=aarch64-linux-gnu-
		arch=arm
		;;
	armhf)
		cross_compile=arm-linux-gnueabihf-
		arch=arm
		;;
	armel)
		cross_compile=arm-linux-gnueabi-
		arch=arm
		;;
	esac

	m0_cross_compile=arm-linux-gnueabi-

	makeargs="ARCH=$arch${cross_compile:+ CROSS_COMPILE=$cross_compile}"

	case "$soc" in
	rk3399)
		TFA="\$($TFA_BUILDDIR)/release/bl31/bl31.elf"
		makeargs="$makeargs BL31=$TFA"
		;;
	esac

	cat <<EOT
#
# $id (u-boot)
#
$BUILDDIR = $builddir
${TFA:+$TFA_BUILDDIR = \$(ARM_TRUSTED_FIRMWARE_SRCDIR)/build/$soc
}$MAKEARGS = -C \$(UBOOT_SRCDIR) O=\$($BUILDDIR) $makeargs

EOT

	if [ -n "$TFA" ]; then
	cat <<EOT
$TFA: \$(ARM_TRUSTED_FIRMWARE_SRCDIR)/Makefile
	\$(MAKE) -C \$(<D) ${cross_compile:+ CROSS_COMPILE=$cross_compile}${m0_cross_compile:+ M0_CROSS_COMPILE=$m0_cross_compile} PLAT=$soc

EOT
	fi

cat <<EOT
\$($BUILDDIR)/.config: \$(UBOOT_SRCDIR)/Makefile \$(GEN_BOARDS_MK_SH)
	@mkdir -p \$(@D)
	if [ -s \$@ ]; then \\
		\$(MAKE) \$($MAKEARGS) oldconfig; \\
	elif [ -s \$(BOARDS_CONFIG_DIR)/$id/uboot.defconfig ]; then \\
		cp \$(BOARDS_CONFIG_DIR)/$id/uboot.defconfig \$@; \\
		\$(MAKE) \$($MAKEARGS) olddefconfig; \\
	elif [ -s \$(UBOOT_SRCDIR)/configs/${UBOOT_CONFIG}_defconfig ]; then \\
		\$(MAKE) \$($MAKEARGS) ${UBOOT_CONFIG}_defconfig; \\
	else \\
		\$(MAKE) \$($MAKEARGS) defconfig; \\
	fi

.PHONY: uboot-$id uboot-$id-savedefconfig uboot-$id-menuconfig

uboot-$id: \$($BUILDDIR)/.config${TFA:+ $TFA}
	\$(MAKE) \$($MAKEARGS)

uboot-$id-savedefconfig: \$($BUILDDIR)/.config
	\$(MAKE) \$($MAKEARGS) savedefconfig
	cp \$($BUILDDIR)/defconfig \$(UBOOT_SRCDIR)/configs/${UBOOT_CONFIG}_defconfig
	@mkdir -p \$(BOARDS_CONFIG_DIR)/$id
	mv \$($BUILDDIR)/defconfig \$(BOARDS_CONFIG_DIR)/$id/uboot.defconfig

uboot-$id-menuconfig: \$($BUILDDIR)/.config
	\$(MAKE) \$($MAKEARGS) menuconfig

EOT

	BOARDS_UBOOT="${BOARDS_UBOOT:+$BOARDS_UBOOT }uboot-$id"
}

gen_board_variant() {
	local VARIANT="$(varify "${1:-}")" variant="${1:-}"
	local r=$id${variant:+-$variant}
	local R=$ID${VARIANT:+_$VARIANT}
	local soc= arch=

	soc=${SOC:-$(guess_soc $id)}
	arch=${ARCH:-$(guess_arch $soc $r)}

	cat <<-EOT
	#
	# $id (rootfs)
	#
	ROOTFS_$R = \$(ROOTFS_DIR)/$r

	.PHONY: rootfs-$r
	rootfs-$r: \$(ROOTFS_$R)/bin/sh

	\$(ROOTFS_$R)/bin/sh: BOARD=${BOARD:-$id}
	\$(ROOTFS_$R)/bin/sh: SOC=$soc
	\$(ROOTFS_$R)/bin/sh: ARCH=$arch

	EOT

	BOARDS_ROOTFS="${BOARDS_ROOTFS:+$BOARDS_ROOTFS }rootfs-$r"
}

# global lists
BOARDS_ROOTFS=
BOARDS_KERNEL=
BOARDS_UBOOT=

# backward compatibility
LINUX_DEFCONFIG=

for id in $BOARDS; do
	# reset
	ID= ARCH=
	DISTRO= DISTRO_VERSION=
	VARIANTS= ROOTFS=
	LINUX_CONFIG= UBOOT_CONFIG=
	UIMAGE_LOADADDR= UIMAGE_ENTRYPOINT=

	SOC=$(guess_soc "$id")
	BOARD="$id"


	# load
	. "$config_dir/$id.conf"

	: ${ID:=$(varify "$id")}
	: ${UBOOT_CONFIG:=$id}
	# backward compatibility
	: ${LINUX_CONFIG:=${LINUX_DEFCONFIG:-}}

	gen_board_kernel
	gen_board_uboot

	if [ -n "$VARIANTS" ]; then
		for v in $VARIANTS; do
			gen_board_variant "$v"
		done
	else
		gen_board_variant
	fi
done

cat <<EOT
# boards
#
EOT
set_list BOARDS_CONFIG_DIR $config_dir
set_list BOARDS_CONFIG $(board_config_fullname '$(BOARDS_CONFIG_DIR)' $BOARDS)
set_list BOARDS $BOARDS
set_list BOARDS_ROOTFS $BOARDS_ROOTFS
set_list BOARDS_KERNEL $BOARDS_KERNEL
set_list BOARDS_UBOOT $BOARDS_UBOOT
