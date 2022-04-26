#!/usr/bin/make -f

SHELL := /bin/sh
.SHELLFLAGS := -euc

DOCKER := $(shell command -v docker 2>/dev/null)
GIT := $(shell command -v git 2>/dev/null)

DISTDIR := ./dist
DOCKERFILE := ./Dockerfile

IMAGE_REGISTRY := docker.io
IMAGE_NAMESPACE := hectorm
IMAGE_PROJECT := qemu-user-static
IMAGE_NAME := $(IMAGE_REGISTRY)/$(IMAGE_NAMESPACE)/$(IMAGE_PROJECT)
IMAGE_GIT_TAG := $(shell '$(GIT)' tag -l --contains HEAD 2>/dev/null)
IMAGE_GIT_SHA := $(shell '$(GIT)' rev-parse HEAD 2>/dev/null)
IMAGE_VERSION := $(if $(IMAGE_GIT_TAG),$(IMAGE_GIT_TAG),$(if $(IMAGE_GIT_SHA),$(IMAGE_GIT_SHA),nil))

IMAGE_BUILD_OPTS :=

IMAGE_NATIVE_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).tzst
IMAGE_AMD64_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).amd64.tzst
IMAGE_ARM64V8_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).arm64v8.tzst
IMAGE_ARM32V7_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).arm32v7.tzst
IMAGE_ARM32V6_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).arm32v6.tzst
IMAGE_PPC64LE_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).ppc64le.tzst
IMAGE_S390X_TARBALL := $(DISTDIR)/$(IMAGE_PROJECT).s390x.tzst

export DOCKER_BUILDKIT := 1
export BUILDKIT_PROGRESS := plain

##################################################
## "all" target
##################################################

.PHONY: all
all: save-native-image

##################################################
## "build-*" targets
##################################################

.PHONY: build-native-image
build-native-image:
	'$(DOCKER)' build $(IMAGE_BUILD_OPTS) \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)' \
		--tag '$(IMAGE_NAME):latest' \
		--file '$(DOCKERFILE)' ./

.PHONY: build-cross-images
build-cross-images: build-amd64-image build-arm64v8-image build-arm32v7-image build-arm32v6-image build-ppc64le-image build-s390x-image

.PHONY: build-amd64-image
build-amd64-image:
	'$(DOCKER)' build $(IMAGE_BUILD_OPTS) \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-amd64' \
		--tag '$(IMAGE_NAME):latest-amd64' \
		--build-arg CROSS_PREFIX=x86_64-linux-gnu- \
		--build-arg DPKG_ARCH=amd64 \
		--file '$(DOCKERFILE)' ./

.PHONY: build-arm64v8-image
build-arm64v8-image:
	'$(DOCKER)' build $(IMAGE_BUILD_OPTS) \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8' \
		--tag '$(IMAGE_NAME):latest-arm64v8' \
		--build-arg CROSS_PREFIX=aarch64-linux-gnu- \
		--build-arg DPKG_ARCH=arm64 \
		--file '$(DOCKERFILE)' ./

.PHONY: build-arm32v7-image
build-arm32v7-image:
	'$(DOCKER)' build $(IMAGE_BUILD_OPTS) \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v7' \
		--tag '$(IMAGE_NAME):latest-arm32v7' \
		--build-arg CROSS_PREFIX=arm-linux-gnueabihf- \
		--build-arg DPKG_ARCH=armhf \
		--file '$(DOCKERFILE)' ./

.PHONY: build-arm32v6-image
build-arm32v6-image:
	'$(DOCKER)' build $(IMAGE_BUILD_OPTS) \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v6' \
		--tag '$(IMAGE_NAME):latest-arm32v6' \
		--build-arg CROSS_PREFIX=arm-linux-gnueabi- \
		--build-arg DPKG_ARCH=armel \
		--file '$(DOCKERFILE)' ./

.PHONY: build-ppc64le-image
build-ppc64le-image:
	'$(DOCKER)' build $(IMAGE_BUILD_OPTS) \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-ppc64le' \
		--tag '$(IMAGE_NAME):latest-ppc64le' \
		--build-arg CROSS_PREFIX=powerpc64le-linux-gnu- \
		--build-arg DPKG_ARCH=ppc64el \
		--file '$(DOCKERFILE)' ./

.PHONY: build-s390x-image
build-s390x-image:
	'$(DOCKER)' build $(IMAGE_BUILD_OPTS) \
		--tag '$(IMAGE_NAME):$(IMAGE_VERSION)-s390x' \
		--tag '$(IMAGE_NAME):latest-s390x' \
		--build-arg CROSS_PREFIX=s390x-linux-gnu- \
		--build-arg DPKG_ARCH=s390x \
		--file '$(DOCKERFILE)' ./

##################################################
## "save-*" targets
##################################################

define save_image
	'$(DOCKER)' save '$(1)' | zstd -T0 > '$(2)'
endef

.PHONY: save-native-image
save-native-image: $(IMAGE_NATIVE_TARBALL)

$(IMAGE_NATIVE_TARBALL): build-native-image
	mkdir -p '$(DISTDIR)'
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION),$@)

.PHONY: save-cross-images
save-cross-images: save-amd64-image save-arm64v8-image save-arm32v7-image save-arm32v6-image save-ppc64le-image save-s390x-image

.PHONY: save-amd64-image
save-amd64-image: $(IMAGE_AMD64_TARBALL)

$(IMAGE_AMD64_TARBALL): build-amd64-image
	mkdir -p '$(DISTDIR)'
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-amd64,$@)

.PHONY: save-arm64v8-image
save-arm64v8-image: $(IMAGE_ARM64V8_TARBALL)

$(IMAGE_ARM64V8_TARBALL): build-arm64v8-image
	mkdir -p '$(DISTDIR)'
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8,$@)

.PHONY: save-arm32v7-image
save-arm32v7-image: $(IMAGE_ARM32V7_TARBALL)

$(IMAGE_ARM32V7_TARBALL): build-arm32v7-image
	mkdir -p '$(DISTDIR)'
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v7,$@)

.PHONY: save-arm32v6-image
save-arm32v6-image: $(IMAGE_ARM32V6_TARBALL)

$(IMAGE_ARM32V6_TARBALL): build-arm32v6-image
	mkdir -p '$(DISTDIR)'
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v6,$@)

.PHONY: save-ppc64le-image
save-ppc64le-image: $(IMAGE_PPC64LE_TARBALL)

$(IMAGE_PPC64LE_TARBALL): build-ppc64le-image
	mkdir -p '$(DISTDIR)'
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-ppc64le,$@)

.PHONY: save-s390x-image
save-s390x-image: $(IMAGE_S390X_TARBALL)

$(IMAGE_S390X_TARBALL): build-s390x-image
	mkdir -p '$(DISTDIR)'
	$(call save_image,$(IMAGE_NAME):$(IMAGE_VERSION)-s390x,$@)

##################################################
## "load-*" targets
##################################################

define load_image
	zstd -dc '$(1)' | '$(DOCKER)' load
endef

define tag_image
	'$(DOCKER)' tag '$(1)' '$(2)'
endef

.PHONY: load-native-image
load-native-image:
	$(call load_image,$(IMAGE_NATIVE_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION),$(IMAGE_NAME):latest)

.PHONY: load-cross-images
load-cross-images: load-amd64-image load-arm64v8-image load-arm32v7-image load-arm32v6-image load-ppc64le-image load-s390x-image

.PHONY: load-amd64-image
load-amd64-image:
	$(call load_image,$(IMAGE_AMD64_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-amd64,$(IMAGE_NAME):latest-amd64)

.PHONY: load-arm64v8-image
load-arm64v8-image:
	$(call load_image,$(IMAGE_ARM64V8_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8,$(IMAGE_NAME):latest-arm64v8)

.PHONY: load-arm32v7-image
load-arm32v7-image:
	$(call load_image,$(IMAGE_ARM32V7_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v7,$(IMAGE_NAME):latest-arm32v7)

.PHONY: load-arm32v6-image
load-arm32v6-image:
	$(call load_image,$(IMAGE_ARM32V6_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v6,$(IMAGE_NAME):latest-arm32v6)

.PHONY: load-ppc64le-image
load-ppc64le-image:
	$(call load_image,$(IMAGE_PPC64LE_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-ppc64le,$(IMAGE_NAME):latest-ppc64le)

.PHONY: load-s390x-image
load-s390x-image:
	$(call load_image,$(IMAGE_S390X_TARBALL))
	$(call tag_image,$(IMAGE_NAME):$(IMAGE_VERSION)-s390x,$(IMAGE_NAME):latest-s390x)

##################################################
## "push-*" targets
##################################################

define push_image
	'$(DOCKER)' push '$(1)'
endef

define push_cross_manifest
	'$(DOCKER)' manifest create --amend '$(1)' '$(2)-amd64' '$(2)-arm64v8' '$(2)-arm32v7' '$(2)-arm32v6' '$(2)-ppc64le' '$(2)-s390x'
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-amd64' --os linux --arch amd64
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-arm64v8' --os linux --arch arm64 --variant v8
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-arm32v7' --os linux --arch arm --variant v7
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-arm32v6' --os linux --arch arm --variant v6
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-ppc64le' --os linux --arch ppc64le
	'$(DOCKER)' manifest annotate '$(1)' '$(2)-s390x' --os linux --arch s390x
	'$(DOCKER)' manifest push --purge '$(1)'
endef

.PHONY: push-native-image
push-native-image:
	@printf '%s\n' 'Unimplemented'

.PHONY: push-cross-images
push-cross-images: push-amd64-image push-arm64v8-image push-arm32v7-image push-arm32v6-image push-ppc64le-image push-s390x-image

.PHONY: push-amd64-image
push-amd64-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-amd64)
	$(call push_image,$(IMAGE_NAME):latest-amd64)

.PHONY: push-arm64v8-image
push-arm64v8-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm64v8)
	$(call push_image,$(IMAGE_NAME):latest-arm64v8)

.PHONY: push-arm32v7-image
push-arm32v7-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v7)
	$(call push_image,$(IMAGE_NAME):latest-arm32v7)

.PHONY: push-arm32v6-image
push-arm32v6-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-arm32v6)
	$(call push_image,$(IMAGE_NAME):latest-arm32v6)

.PHONY: push-ppc64le-image
push-ppc64le-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-ppc64le)
	$(call push_image,$(IMAGE_NAME):latest-ppc64le)

.PHONY: push-s390x-image
push-s390x-image:
	$(call push_image,$(IMAGE_NAME):$(IMAGE_VERSION)-s390x)
	$(call push_image,$(IMAGE_NAME):latest-s390x)

push-cross-manifest:
	$(call push_cross_manifest,$(IMAGE_NAME):$(IMAGE_VERSION),$(IMAGE_NAME):$(IMAGE_VERSION))
	$(call push_cross_manifest,$(IMAGE_NAME):latest,$(IMAGE_NAME):latest)

##################################################
## "version" target
##################################################

.PHONY: version
version:
	@LATEST_IMAGE_VERSION=$$('$(GIT)' describe --abbrev=0 2>/dev/null || printf 'v0'); \
	if printf '%s' "$${LATEST_IMAGE_VERSION:?}" | grep -q '^v[0-9]\{1,\}$$'; then \
		NEW_IMAGE_VERSION=$$(awk -v v="$${LATEST_IMAGE_VERSION:?}" 'BEGIN {printf("v%.0f", substr(v,2)+1)}'); \
		'$(GIT)' commit --allow-empty -m "$${NEW_IMAGE_VERSION:?}"; \
		'$(GIT)' tag -a "$${NEW_IMAGE_VERSION:?}" -m "$${NEW_IMAGE_VERSION:?}"; \
	else \
		>&2 printf 'Malformed version string: %s\n' "$${LATEST_IMAGE_VERSION:?}"; \
		exit 1; \
	fi

##################################################
## "clean" target
##################################################

.PHONY: clean
clean:
	rm -f '$(IMAGE_NATIVE_TARBALL)'
	rm -f '$(IMAGE_AMD64_TARBALL)'
	rm -f '$(IMAGE_ARM64V8_TARBALL)' '$(IMAGE_ARM32V7_TARBALL)' '$(IMAGE_ARM32V6_TARBALL)'
	rm -f '$(IMAGE_PPC64LE_TARBALL)' '$(IMAGE_S390X_TARBALL)'
	if [ -d '$(DISTDIR)' ] && [ -z "$$(ls -A '$(DISTDIR)')" ]; then rmdir '$(DISTDIR)'; fi
