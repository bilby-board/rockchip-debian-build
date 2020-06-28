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

# rootfs' root
#
ROOT=

find_root() {
	local d="$1"
	if [ -z "$d" -o "$d" = "/" ]; then
		false
	elif [ -x "$d/bin/sh" ]; then
		echo "$d"
	else
		find_root "$(cd "$d/.." && pwd)"
	fi
}

if [ $# -gt 0 -a -d "${1:-}" ]; then
	root="$1"
	shift
else
	root="$PWD"
fi

ROOT="$(find_root "$root")"
[ -n "$ROOT" ] || die "$root: invalid directory"

# CWD inside chroot
#
if [ "${PWD#$ROOT/}" != "$PWD" ]; then
	cwd="${PWD#$ROOT}"
else
	cwd=
fi

# CMD
#
[ $# -gt 0 ] || set -- /bin/sh

cat >&2 <<-EOT
# ROOT: $ROOT
# PWD:  ${cwd:-/}
# CMD:  $* ($#)
#
EOT

# prepare for chroot
#
try_unmount() {
	# get out of the way
	cd /

	# TODO: check if anyone is still inside

	# and unmount everything
	while grep -q " $ROOT/" /proc/mounts; do
		grep " $ROOT/" /proc/mounts | cut -d' ' -f2 | sort | tac | while read x; do
			umount "$x"
		done
	done
}

want_mount() {
	local x=
	for x; do
		if ! grep -q " $ROOT/$x " /proc/mounts; then
			mount --bind "/$x" "$ROOT/$x"
		fi
	done
}

trap try_unmount EXIT

want_mount dev dev/pts proc sys tmp

if [ -x "$ROOT/usr/bin/env" ]; then
	exec chroot "$ROOT" /usr/bin/env -i ${cwd:+-C "$cwd"} TERM=${TERM:-xterm} "$@"
elif [ -n "$cwd" ]; then
	exec chroot "$ROOT" /bin/sh <<-EOT
	set -eu
	cd '$cwd'
	exec <&2
	exec $*
	EOT
else
	exec chroot "$ROOT" "$@"
fi
