##################################################
## "build" stage
##################################################

FROM docker.io/debian:12 AS build

ARG CROSS_PREFIX=
ARG CROSS_DPKG_ARCH=

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& { [ -z "${CROSS_DPKG_ARCH?}" ] || dpkg --add-architecture "${CROSS_DPKG_ARCH:?}"; } \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		build-essential \
		ca-certificates \
		file \
		git \
		libcap2-bin \
		make \
		meson \
		ninja-build \
		pkgconf \
		python3 \
		python3-venv \
		${CROSS_DPKG_ARCH:+crossbuild-essential-"${CROSS_DPKG_ARCH:?}"} \
		libglib2.0-dev"${CROSS_DPKG_ARCH:+:"${CROSS_DPKG_ARCH:?}"}" \
	&& rm -rf /var/lib/apt/lists/*

# Build QEMU
ARG QEMU_TREEISH=v8.1.2
ARG QEMU_REMOTE=https://gitlab.com/qemu-project/qemu.git
RUN mkdir /tmp/qemu/
WORKDIR /tmp/qemu/
RUN git clone "${QEMU_REMOTE:?}" ./
RUN git checkout "${QEMU_TREEISH:?}"
RUN git submodule update --init --recursive
RUN mkdir /tmp/qemu/build/
WORKDIR /tmp/qemu/build/
RUN ../configure \
		--static --cross-prefix="${CROSS_PREFIX?}" \
		--enable-user --enable-werror --enable-stack-protector \
		--disable-system --disable-modules --disable-tools --disable-guest-agent --disable-debug-info --disable-docs \
		--target-list='x86_64-linux-user aarch64-linux-user arm-linux-user ppc64le-linux-user s390x-linux-user riscv64-linux-user'
RUN make -j"$(nproc)"
RUN set -eu; mkdir ./bin/; \
	for f in ./*-linux-user/qemu-*; do \
		in=$(readlink -f "${f:?}"); \
		out=./bin/"$(basename "${in:?}")"-static; \
		"${CROSS_PREFIX?}"strip -s "${in:?}"; \
		setcap cap_net_bind_service=+ep "${in:?}"; \
		test -z "$(readelf -x .interp "${in:?}" 2>/dev/null)"; \
		mv "${in:?}" "${out:?}"; file "${out:?}"; \
	done
# Ignore already registered entries
RUN sed -ri 's;( > /proc/sys/fs/binfmt_misc/register)$;\1 ||:;' ./scripts/qemu-binfmt-conf.sh

##################################################
## "main" stage
##################################################

FROM --platform=${TARGETPLATFORM:-linux/amd64} docker.io/busybox:latest AS main

COPY --from=build --chown=root:root /tmp/qemu/build/bin/* /usr/bin/
COPY --from=build --chown=root:root /tmp/qemu/scripts/qemu-binfmt-conf.sh /usr/bin/
COPY --chown=root:root ./scripts/bin/ /usr/bin/

ENTRYPOINT ["/usr/bin/qemu-binfmt-register.sh"]
