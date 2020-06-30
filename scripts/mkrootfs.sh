#!/bin/sh

set -eu

arg0="$(basename "$0")"

die() {
	if [ $# -gt 0 ]; then
		echo "F/$arg0:$*"
	else
		sed -e "s|^|F/$arg0:||"
	fi >&2
	exit 1
}

# variable overrides
#
# * SOC
# * ARCH
# * DISTRO
# * DISTRO_VERSION
# * DISTRO_URL
#
# private variables
#
# * ROOTFS_ID
# * soc
# * arch
# * distro
# * distro_version
# * distro_url

mkrootfs_debootstrap() {
	local soc="$1" arch="$2" distro="$3" version="$4" rootfs="$5"
	local url=

	case "$distro" in
	debian)
		url=http://ftp.uk.debian.org/debian/
		;;
	esac

	debootstrap --arch "$arch" "$version" "$rootfs" "$url"
}

# arguments are rootfs directories
#
for d; do
	[ -d "$d" ] || mkdir -p "$d"

	ROOTFS_ID="$(cd "$d" && echo "${PWD##*/}")"
	[ -n "$ROOTFS_ID" ] || die "$d: Invalid directory"

	# SoC
	#
	case "${SOC:-}" in
	rk3288|rk3399)
		soc=$SOC
		;;
	"")
		case "$ROOTFS_ID" in
		*rk3399*)
			soc=rk3399
			;;
		*rk3288*)
			soc=rk3288
			;;
		*)
			soc=unknown
			;;
		esac
		;;
	*)
		die "$SOC: SoC not supported"
		;;
	esac

	# ARCH
	case "${ARCH:-}" in
	armel|armhf|arm64)
		arch=$ARCH
		;;
	"")
		case "$ROOTFS_ID" in
		*arm64*)
			arch=arm64
			;;
		*armel*)
			arch=armel
			;;
		*)
			case "$soc" in
			rk3399)
				arch=arm64
				;;
			rk3288)
				arch=armhf
				;;
			esac
			;;
		esac
		;;
	*)
		die "$ARCH: architecture not supported"
		;;
	esac

	# QEMU
	case "$arch" in
	armel|armhf)
		qemu=/usr/bin/qemu-arm-static
		;;
	arm64)
		qemu=/usr/bin/qemu-aarch64-static
		;;
	*)
		qemu=
		;;
	esac

	# DISTRO
	#
	case "${DISTRO_VERSION:-}" in
	sid)
		distro=debian
		distro_version=sid
		;;
	"")
		case "${DISTRO:-}" in
		debian)
			distro_version=sid
			;;
		"")
			distro=debian
			distro_version=sid
			;;
		*)
			die "$DISTRO: distribution not identified ($ROOTFS_ID)"
			;;
		esac
		;;
	*)
		die "$DISTRO_VERSION: \$DISTRO_VERSION not supported"
		;;
	esac

	# user mode emulator (binfmt_misc) must be injected first
	#
	if [ -n "$qemu" -a ! -x "$d$qemu" ]; then
		mkdir -p "$d${qemu%/*}"
		cp "$qemu" "$d${qemu%/*}"
	fi

	# populate rootfs
	if [ ! -x "$d/bin/sh" ]; then

		cat >&2 <<-EOT
		# $ROOTFS_ID ($d)
		# DISTRO: $distro $distro_version
		# ARCH: $arch ($soc)
		#
		EOT
		case "$distro" in
		debian)
			mkrootfs_debootstrap "$soc" "$arch" "$distro" "$distro_version" "$d"
			;;
		esac
	fi

	du -sh "$d"
done
