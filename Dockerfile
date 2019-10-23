##################################################
## "build" stage
##################################################

FROM docker.io/debian:buster AS build

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		autoconf \
		automake \
		bison \
		build-essential \
		ca-certificates \
		file \
		flex \
		git \
		pkgconf \
		python3

# Clone QEMU
ARG QEMU_TREEISH=v4.1.0
ARG QEMU_REMOTE=https://github.com/qemu/qemu.git
RUN mkdir /tmp/qemu/
WORKDIR /tmp/qemu/
RUN git clone "${QEMU_REMOTE:?}" ./
RUN git checkout "${QEMU_TREEISH:?}"
RUN git submodule update --init --recursive

# Setup cross-compilation
ARG CROSS_PREFIX=
ARG DPKG_ARCH=
ENV DPKG_PKGS='libglib2.0-dev'
RUN if [ -n "${DPKG_ARCH?}" ]; then \
		dpkg --add-architecture "${DPKG_ARCH:?}"; apt-get update; \
		apt-get install -y crossbuild-essential-"${DPKG_ARCH:?}"; \
		DPKG_PKGS=$(printf "%s:${DPKG_ARCH:?}\n" ${DPKG_PKGS:?}); \
	fi; apt-get install -y --no-install-recommends ${DPKG_PKGS:?}

# Build QEMU
RUN mkdir /tmp/qemu/build/
WORKDIR /tmp/qemu/build/
RUN ../configure \
		--static --cross-prefix="${CROSS_PREFIX?}" --enable-linux-user \
		--disable-system --disable-modules --disable-tools --disable-guest-agent --disable-debug-info --disable-docs \
		--target-list='x86_64-linux-user i386-linux-user aarch64-linux-user arm-linux-user riscv64-linux-user' \
		--extra-cflags='-D_FORTIFY_SOURCE=2 -fstack-protector-all' \
		--extra-ldflags='-Wl,-z,now -Wl,-z,relro'
RUN make -j"$(nproc)"
RUN for b in ./*-linux-user/qemu-*; do "${CROSS_PREFIX?}"strip -s "$b"; file "$b"; done
RUN for b in ./*-linux-user/qemu-*; do file -b "$b" | grep -q 'statically linked'; done

##################################################
## "qemu-user-static" stage
##################################################

FROM scratch AS qemu-user-static

COPY --from=build /tmp/qemu/build/x86_64-linux-user/qemu-x86_64 /usr/bin/qemu-x86_64-static
COPY --from=build /tmp/qemu/build/i386-linux-user/qemu-i386 /usr/bin/qemu-i386-static
COPY --from=build /tmp/qemu/build/aarch64-linux-user/qemu-aarch64 /usr/bin/qemu-aarch64-static
COPY --from=build /tmp/qemu/build/arm-linux-user/qemu-arm /usr/bin/qemu-arm-static
COPY --from=build /tmp/qemu/build/riscv64-linux-user/qemu-riscv64 /usr/bin/qemu-riscv64-static