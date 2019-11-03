#!/bin/sh

# Script based on:
# https://github.com/multiarch/qemu-user-static

set -eu

QEMU_BIN_DIR=${QEMU_BIN_DIR:-/usr/bin}

if [ ! -d /proc/sys/fs/binfmt_misc ]; then
	echo 'No binfmt support in the kernel.'
	echo '  Try: "/sbin/modprobe binfmt_misc" from the host'
	exit 1
fi

if [ ! -f /proc/sys/fs/binfmt_misc/register ]; then
	mount binfmt_misc -t binfmt_misc /proc/sys/fs/binfmt_misc
fi

if [ "${1-}" = '--reset' ]; then
	shift
	find /proc/sys/fs/binfmt_misc -type f -name 'qemu-*' -exec sh -c 'echo -1 > "$1"' _ '{}' ';'
fi

exec "${QEMU_BIN_DIR:?}"/qemu-binfmt-conf.sh --qemu-path "${QEMU_BIN_DIR:?}" --qemu-suffix '-static' "$@"
