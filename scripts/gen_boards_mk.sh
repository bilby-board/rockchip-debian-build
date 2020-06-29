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
	case "$2" in
	*armhf*) echo "armhf" ;;
	*armel*) echo "armel" ;;
	*)
		case "$1" in
		rk3399|rk3288)
			echo "armhf" ;;
		esac
		;;
	esac
}

gen_board_variant() {
	local VARIANT="$(varify "${1:-}")" variant="${1:-}"
	local r=$id${variant:+-$variant}
	local R=$ID${VARIANT:+_$VARIANT}
	local soc= arch=

	soc=${SOC:-$(guess_soc $id)}
	arch=${ARCH:-$(guess_arch $soc $r)}

	cat <<-EOT
	ROOTFS_$R=\$(ROOTFS_DIR)/$r

	.PHONY: rootfs-$r
	rootfs-$r: \$(ROOTFS_$R)/bin/sh

	\$(ROOTFS_$R)/bin/sh: BOARD=${BOARD:-$id} SOC=$soc ARCH=$arch

	EOT

	BOARDS_ROOTFS="${BOARDS_ROOTFS:+$BOARDS_ROOTFS }rootfs-$r"

}

BOARDS_ROOTFS=

for id in $BOARDS; do
	cat <<-EOT
	# $id
	#
	EOT

	# reset
	ID= BOARD=
	SOC= ARCH=
	DISTRO= DISTRO_VERSION=
	VARIANTS= ROOTFS=

	# load
	. "$config_dir/$id.conf"

	[ -n "$ID" ] || ID=$(varify "$id")

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
