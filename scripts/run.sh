#!/bin/sh

set -eu

# we are $WS/scripts/run.sh
SCRIPTS_DIR="$(dirname "$0")"
WS="$(cd "$SCRIPTS_DIR/.." && pwd)"

# are we at a rootfs to chroot into?
#
find_rootfs() {
	local root="$1" dir="${2:-$PWD}" d=

	if [ "$root" = "$dir" ]; then
		:
	elif [ -e "$dir/etc/passwd" ]; then
		echo "$dir"
	else
		find_rootfs "$root" "$(cd "$dir/.." && pwd)"
	fi
}

ROOTFS="$(find_rootfs "$WS")"

if [ -d "$ROOTFS" ]; then
	# run inside chroot
	exec "$SCRIPTS_DIR/chroot.sh" "$ROOTFS" "$@"
fi

# not chrooted
[ $# -gt 0 ] || set -- /bin/bash

exec "$@"
