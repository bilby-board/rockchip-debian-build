#!/bin/sh

set -eux
WS="$(dirname "$0")"
O=$WS/out

ARCH=armhf
DISTRO=debian
DISTRO_VERSION=sid
DISTRO_URL=http://ftp.uk.debian.org/debian/

case "$ARCH" in
armhf) QEMU=/usr/bin/qemu-arm-static ;;
*)     QEMU= ;;
esac

ROOTFS="$O/rootfs/$DISTRO-$DISTRO_VERSION-$ARCH"

# inject qemu-*-static before `debootstrap`
#
if [ ! -x "$ROOTFS$QEMU" ]; then
	mkdir -p "$ROOTFS${QEMU%/*}"
	cp "$QEMU" "$ROOTFS$QEMU"
fi

# populate rootfs
#
if [ ! -x $ROOTFS/bin/sh ]; then
	debootstrap --arch $ARCH $DISTRO_VERSION "$ROOTFS" "$DISTRO_URL"
fi

du -sh "$ROOTFS"
