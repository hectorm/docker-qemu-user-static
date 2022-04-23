##################################################
## "build" stage
##################################################

FROM docker.io/debian:11 AS build

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		build-essential \
		ca-certificates \
		file \
		git \
		meson \
		ninja-build \
		pkgconf \
		python3 \
	&& rm -rf /var/lib/apt/lists/*

# Setup cross-compilation
ARG CROSS_PREFIX=
ARG DPKG_ARCH=
ENV DPKG_PKGS='libglib2.0-dev'
RUN if [ -n "${DPKG_ARCH?}" ]; then \
		dpkg --add-architecture "${DPKG_ARCH:?}" \
		&& apt-get update \
		&& apt-get install -y crossbuild-essential-"${DPKG_ARCH:?}" \
		&& DPKG_PKGS=$(printf "%s:${DPKG_ARCH:?}\n" ${DPKG_PKGS:?}); \
	else \
		apt-get update; \
	fi \
	&& apt-get install -y --no-install-recommends ${DPKG_PKGS:?} \
	&& rm -rf /var/lib/apt/lists/*

# Build QEMU
ARG QEMU_TREEISH=v7.0.0
ARG QEMU_REMOTE=https://gitlab.com/qemu-project/qemu.git
RUN mkdir /tmp/qemu/
WORKDIR /tmp/qemu/
RUN git clone "${QEMU_REMOTE:?}" ./
RUN git checkout "${QEMU_TREEISH:?}"
RUN git submodule update --init --recursive
# Revert until a workaround is found:
# https://bugs.launchpad.net/qemu/+bug/1880332
RUN git revert -n de0b1bae6461f67243282555475f88b2384a1eb9
RUN mkdir /tmp/qemu/build/
WORKDIR /tmp/qemu/build/
RUN ../configure \
		--static --cross-prefix="${CROSS_PREFIX?}" \
		--enable-user --enable-werror --enable-stack-protector \
		--disable-system --disable-modules --disable-tools --disable-guest-agent --disable-debug-info --disable-docs \
		--target-list='x86_64-linux-user aarch64-linux-user arm-linux-user ppc64le-linux-user s390x-linux-user riscv64-linux-user'
RUN make -j"$(nproc)"
RUN for f in ./*-linux-user/qemu-*; do mv "${f:?}" "${f:?}"-static; done
RUN for f in ./*-linux-user/qemu-*-static; do "${CROSS_PREFIX?}"strip -s "${f:?}"; file "${f:?}"; done
RUN for f in ./*-linux-user/qemu-*-static; do test -z "$(readelf -x .interp "${f:?}" 2>/dev/null)"; done
# Ignore already registered entries
RUN sed -ri 's;( > /proc/sys/fs/binfmt_misc/register)$;\1 ||:;' ./scripts/qemu-binfmt-conf.sh

##################################################
## "main" stage
##################################################

FROM docker.io/alpine:3 AS main

COPY --from=build --chown=root:root /tmp/qemu/build/*-linux-user/qemu-*-static /usr/bin/
COPY --from=build --chown=root:root /tmp/qemu/scripts/qemu-binfmt-conf.sh /usr/bin/
COPY --chown=root:root ./scripts/bin/ /usr/bin/

ENTRYPOINT ["/usr/bin/qemu-binfmt-register.sh"]
