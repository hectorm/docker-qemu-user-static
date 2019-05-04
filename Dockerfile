##################################################
## "build" stage
##################################################

FROM debian:sid AS build

ARG TARGET_ARCH=
RUN TARGET_ARCH="${TARGET_ARCH:-$(dpkg --print-architecture)}" \
	&& dpkg --add-architecture "${TARGET_ARCH}" && apt-get update \
	&& apt-get install -y --no-install-recommends qemu-user-static:"${TARGET_ARCH}"

##################################################
## "qemu-user-static" stage
##################################################

FROM scratch AS qemu-user-static

COPY --from=build /usr/bin/qemu-*-static /usr/bin/
