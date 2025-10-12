##################################################
## "build" stage
##################################################

FROM --platform=${BUILDPLATFORM} docker.io/debian:sid-slim AS build

# Arguments
ARG CROSS_PREFIX=
ARG MESON_CPU_FAMILY=
ARG MESON_CPU=

# Environment
ENV BUILDDIR=/tmp/build
ENV SYSROOT=/tmp/sysroot
ENV PKG_CONFIG=/usr/bin/pkg-config
ENV PKG_CONFIG_SYSROOT_DIR=${SYSROOT}
ENV PKG_CONFIG_LIBDIR=${SYSROOT}/lib/pkgconfig:${SYSROOT}/share/pkgconfig
ENV PKG_CONFIG_PATH=${PKG_CONFIG_LIBDIR}

# Install system packages
RUN export DEBIAN_FRONTEND=noninteractive \
	&& CROSS_DPKG_SUFFIX=$(printenv CROSS_PREFIX | tr '_' '-') \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		build-essential \
		ca-certificates \
		curl \
		file \
		git \
		libcap2-bin \
		make \
		meson \
		ninja-build \
		pkgconf \
		python3 \
		python3-packaging \
		python3-venv \
		${CROSS_DPKG_SUFFIX:+ \
			binutils-"${CROSS_DPKG_SUFFIX%-}" \
			cpp-"${CROSS_DPKG_SUFFIX%-}" \
			g++-"${CROSS_DPKG_SUFFIX%-}" \
			gcc-"${CROSS_DPKG_SUFFIX%-}" \
		} \
	&& rm -rf /var/lib/apt/lists/*

# Create Meson cross-file
COPY <<-EOF ${SYSROOT}/cross.ini
	[host_machine]
	system = 'linux'
	cpu_family = '${MESON_CPU_FAMILY}'
	cpu = '${MESON_CPU}'
	endian = 'little'

	[properties]
	c_args = []
	c_link_args = []

	[binaries]
	c = '${CROSS_PREFIX}gcc'
	cpp = '${CROSS_PREFIX}g++'
	ar = '${CROSS_PREFIX}ar'
	ld = '${CROSS_PREFIX}ld'
	nm = '${CROSS_PREFIX}nm'
	ranlib = '${CROSS_PREFIX}ranlib'
	strip = '${CROSS_PREFIX}strip'
	objcopy = '${CROSS_PREFIX}objcopy'
	objdump = '${CROSS_PREFIX}objdump'
EOF

# Build libffi
ARG LIBFFI_TREEISH=v3.4.8
ARG LIBFFI_REMOTE=https://github.com/libffi/libffi.git
WORKDIR ${BUILDDIR}/libffi/
RUN git clone "${LIBFFI_REMOTE:?}" ./ \
	&& git checkout "${LIBFFI_TREEISH:?}" \
	&& git submodule update --init --recursive
# Apply Meson build system patch ( https://github.com/libffi/libffi/pull/746 )
RUN curl -sSfL "${LIBFFI_REMOTE%.git}/compare/${LIBFFI_TREEISH:?}...xclaesse:libffi:41fc1ec.patch" | git apply -v
RUN meson setup ./build/ \
	--prefix="${SYSROOT:?}" \
	--libdir="${SYSROOT:?}"/lib \
	${CROSS_PREFIX:+--cross-file="${SYSROOT:?}"/cross.ini} \
	--buildtype=release \
	--default-library=static \
	-D doc=false \
	-D tests=false
RUN ninja -C ./build/ install
RUN pkg-config --static --exists --print-errors libffi

# Build glib
ARG GLIB_TREEISH=2.86.0
ARG GLIB_REMOTE=https://gitlab.gnome.org/GNOME/glib.git
WORKDIR ${BUILDDIR}/glib/
RUN git clone "${GLIB_REMOTE:?}" ./ \
	&& git checkout "${GLIB_TREEISH:?}" \
	&& git submodule update --init --recursive
RUN meson setup ./build/ \
		--prefix="${SYSROOT:?}" \
		--libdir="${SYSROOT:?}"/lib \
		${CROSS_PREFIX:+--cross-file="${SYSROOT:?}"/cross.ini} \
		--buildtype=release \
		--default-library=static \
		--force-fallback-for=gvdb,zlib \
		-D man-pages=disabled \
		-D documentation=false \
		-D tests=false \
		-D nls=disabled \
		-D selinux=disabled \
		-D xattr=false \
		-D libmount=disabled \
		-D glib_assert=false \
		-D glib_checks=false
RUN ninja -C ./build/ install
RUN pkg-config --static --exists --print-errors glib-2.0

# Build QEMU
ARG QEMU_TREEISH=v10.1.1
ARG QEMU_REMOTE=https://gitlab.com/qemu-project/qemu.git
WORKDIR ${BUILDDIR}/qemu/
RUN git clone "${QEMU_REMOTE:?}" ./ \
	&& git checkout "${QEMU_TREEISH:?}" \
	&& git submodule update --init --recursive
# Temporary revert to fix https://gitlab.com/qemu-project/qemu/-/issues/1913
RUN git revert -n aec338d63bc28f1f13d5e64c561d7f1dd0e4b07e
WORKDIR ${BUILDDIR}/qemu/build/
RUN ../configure \
		--static --cross-prefix="${CROSS_PREFIX?}" \
		--enable-user --enable-werror --enable-stack-protector \
		--disable-system --disable-modules --disable-tools --disable-guest-agent --disable-debug-info --disable-docs \
		--target-list='x86_64-linux-user aarch64-linux-user arm-linux-user riscv64-linux-user ppc64le-linux-user s390x-linux-user'
RUN make -j"$(nproc)"
RUN set -eu; mkdir ./bin/; \
	for f in ./qemu-x86_64 ./qemu-aarch64 ./qemu-arm ./qemu-riscv64 ./qemu-ppc64le ./qemu-s390x; do \
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

FROM docker.io/busybox:latest AS main

COPY --from=build --chown=root:root /tmp/build/qemu/build/bin/* /usr/bin/
COPY --from=build --chown=root:root /tmp/build/qemu/build/scripts/qemu-binfmt-conf.sh /usr/bin/
COPY --chown=root:root ./scripts/bin/ /usr/bin/

ENTRYPOINT ["/usr/bin/qemu-binfmt-register.sh"]
