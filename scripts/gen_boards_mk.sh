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

gen_board_kernel() {
	local soc= arch=
	local builddir= BUILDDIR= MAKEARGS=
	local image_file=
	local make_args=
	local cross_compile= cross32_compile=

	soc=${SOC:-$(guess_soc $id)}
	arch=${ARCH:-$(guess_arch $soc)}

	builddir="\$(B)/linux/$id"
	BUILDDIR="KERNEL_${ID}_BUILDDIR"
	MAKEARGS="KERNEL_${ID}_MAKE_ARGS"

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

	make_args="-C \$(LINUX_SRCDIR) O=\$($BUILDDIR)"
	make_args="$make_args ARCH=$arch${cross_compile:+ CROSS_COMPILE=$cross_compile}${cross32_compile:+ CROSS32_COMPILE=$cross32_compile}"

	cat <<EOT
$BUILDDIR = $builddir
$MAKEARGS = $make_args

\$($BUILDDIR)/.config: \$(LINUX_SRCDIR)/Makefile
\$($BUILDDIR)/.config: \$(SCRIPTS_DIR)/gen_boards_mk.sh
\$($BUILDDIR)/.config:
	@mkdir -p \$(@D)
	if [ -s \$@ ]; then \\
		\$(MAKE) \$($MAKEARGS) oldconfig; \\
	elif [ -s \$(BOARDS_CONFIG_DIR)/$id/defconfig ]; then \\
		cp \$(BOARDS_CONFIG_DIR)/$id/defconfig $@; \\
		\$(MAKE) \$($MAKEARGS) oldconfig; \\
	${LINUX_CONFIG:+elif [ -s \$(LINUX_SRCDIR)/arch/$arch/configs/${LINUX_CONFIG}_defconfig ]; then \\
		\$(MAKE) \$($MAKEARGS) ${LINUX_CONFIG}_defconfig; \\
	}else \\
		\$(MAKE) \$($MAKEARGS) defconfig; \\
	fi

\$($BUILDDIR)/$image_file: \$($BUILDDIR)/.config
	\$(MAKE) \$($MAKEARGS)

.PHONY: kernel-$id kernel-$id-cmd kernel-$id-savedefconfig
.PHONY: kernel-$id-menucconfig

kernel-$id: \$($BUILDDIR)/$image_file

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

gen_board_variant() {
	local VARIANT="$(varify "${1:-}")" variant="${1:-}"
	local r=$id${variant:+-$variant}
	local R=$ID${VARIANT:+_$VARIANT}
	local soc= arch=

	soc=${SOC:-$(guess_soc $id)}
	arch=${ARCH:-$(guess_arch $soc $r)}

	cat <<-EOT
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

# backward compatibility
LINUX_DEFCONFIG=

for id in $BOARDS; do
	cat <<-EOT
	# $id
	#
	EOT

	# reset
	ID= ARCH=
	DISTRO= DISTRO_VERSION=
	VARIANTS= ROOTFS=
	LINUX_CONFIG=

	SOC=$(guess_soc "$id")
	BOARD="$id"

	# load
	. "$config_dir/$id.conf"

	: ${ID:=$(varify "$id")}
	# backward compatibility
	: ${LINUX_CONFIG:=${LINUX_DEFCONFIG:-}}

	gen_board_kernel

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
