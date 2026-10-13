IMAGE_NAME ?= xiaoai-airplay1-toolchain:dev

.PHONY: build build-shairport package

build:
	docker build -t $(IMAGE_NAME) $(CURDIR)

build-shairport:
	bash $(CURDIR)/build-shairport.sh

package: build-shairport
	bash $(CURDIR)/package-release.sh
