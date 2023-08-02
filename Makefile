COBALT_BUILD_TYPE?=gold
COBALT_SB_API_VERSION?=$(shell strings $(WORKDIR)/image/usr/palm/applications/$(PACKAGE_NAME_OFFICIAL)/cobalt | grep sb_api | jq -r '.sb_api_version' | grep -v null)
COBALT_ARCHITECTURE?=arm-softfp
COBALT_PLATFORM?=evergreen-$(COBALT_ARCHITECTURE)
COBALT_TARGET?=cobalt
COBALT_PARALLEL?=

PACKAGE_NAME?=
PACKAGE_NAME_OFFICIAL=youtube.leanback.v4
PACKAGE_NAME_TARGET=$(if $(PACKAGE_NAME),$(PACKAGE_NAME),$(PACKAGE_NAME_OFFICIAL))
OFFICAL_YOUTUBE_IPK?=ipks-official/2023-07-30-youtube.leanback.v4-1.1.7.ipk

WORKDIR?=workdir

SHELL=/bin/bash

.PHONY: all
all: npm-docker clean-ipk ipk-unpack cobalt-build ipk-update ares-package
	@echo ""

.PHONY: cobalt
cobalt: npm cobalt-build
	@echo ""

.PHONY: cobalt-clean
cobalt-clean:
	(cd cobalt ; git checkout . ; git clean -d -f)

.PHONY: cobalt-patches
cobalt-patches: cobalt-patches/*.patch
	@for file in $^ ; do \
		[ -f ./cobalt/.$$file ] && echo "Already applied "$$file || (echo "Apply patch "$$file ; ( cd cobalt ; patch -p1 < ../$$file ; mkdir -p $$(dirname .$$file) ; touch .$$file )) ; \
	done

.PHONY: cobalt-build
cobalt-build: cobalt-patches
	@echo "Current IPK is using SB API version "$(COBALT_SB_API_VERSION)
	@if [ "$(COBALT_SB_API_VERSION)" == "" ]; then \
		echo "  Cannot find automatically SBAPI for the IPK $(OFFICAL_YOUTUBE_IPK)"; \
		echo "  Try to manually define SBAPI version with:"; \
		echo "    make COBALT_SB_API_VERSION=xyz"; \
		exit 1; \
	fi
	@echo "  Build Cobalt using SB API version "$(COBALT_SB_API_VERSION)
	cd cobalt && \
	docker-compose run $(if $(COBALT_PARALLEL),-e NINJA_PARALLEL=$(COBALT_PARALLEL),) -e CONFIG="$(COBALT_BUILD_TYPE)" -e TARGET="$(COBALT_TARGET)" -e SB_API_VERSION="$(COBALT_SB_API_VERSION)" $(COBALT_PLATFORM)

.PHONY: cobalt-build-test
cobalt-build-test: COBALT_PLATFORM=linux-x64x11
cobalt-build-test: cobalt-build
	@echo "Done"


.PHONY: docker-make.%
docker-make.%:
	docker run --rm -ti -u $$(id -u):$$(id -g) -v $$PWD:/app -w /app node:18 make $*

.PHONY: npm
npm:
	( \
		cd youtube-webos && \
		npm install && \
		npm run build -- --env production --optimization-minimize \
	)

.PHONY: npm-docker
npm-docker: docker-make.npm
	@echo ""

.PHONY: clean-ipk
clean-ipk:
	rm -fr ipk

.PHONY: ipk-unpack
ipk-unpack: clean-ipk
	mkdir -p $(WORKDIR)/unpacked_ipk $(WORKDIR)/package $(WORKDIR)/image
	ar x --output $(WORKDIR)/unpacked_ipk $(OFFICAL_YOUTUBE_IPK)
	tar xvzpf $(WORKDIR)/unpacked_ipk/control.tar.gz -C $(WORKDIR)/unpacked_ipk
	tar xvzpf $(WORKDIR)/unpacked_ipk/data.tar.gz -C $(WORKDIR)/package
	unsquashfs -f -d $(WORKDIR)/image $(WORKDIR)/package/usr/palm/data/images/$(PACKAGE_NAME_OFFICIAL)/data.img

.PHONY: ipk-update
ipk-update:
ifneq ("$(PACKAGE_NAME_TARGET)","$(PACKAGE_NAME_OFFICIAL)")
	find ipk -type d -name 'youtube.leanback.v4' | xargs -n1 rename "s/$(PACKAGE_NAME_OFFICIAL)/$(PACKAGE_NAME_TARGET)/"
	grep -l -R "youtube.leanback.v4" ipk | grep .json | xargs -n 1 sed -i "s/$(PACKAGE_NAME_OFFICIAL)/$(PACKAGE_NAME_TARGET)/g"
endif
	sed -i 's/YouTube/YouTube Cobalt AdBlock/g' $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json
	jq 'del(.fileSystemType)' < $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json >  $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo2.json
	mv $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo2.json $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json
	cp assets/icon.png $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/$$(jq -r '.icon' < $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json)
	cp assets/mediumLargeIcon.png $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/$$(jq -r '.mediumLargeIcon' < $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json)
	cp assets/largeIcon.png $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/$$(jq -r '.largeIcon' < $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json)
	cp assets/extraLargeIcon.png $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/$$(jq -r '.extraLargeIcon' < $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json)
	cp assets/playIcon.png $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/$$(jq -r '.playIcon' < $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json)
	cp assets/imageForRecents.png $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/$$(jq -r '.imageForRecents' < $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json)
	if [ -f cobalt/out/$(COBALT_PLATFORM)-sbversion-$(COBALT_SB_API_VERSION)_$(COBALT_BUILD_TYPE)/lib/libcobalt.so ]; then \
		cp cobalt/out/$(COBALT_PLATFORM)-sbversion-$(COBALT_SB_API_VERSION)_$(COBALT_BUILD_TYPE)/lib/libcobalt.so $(WORKDIR)/image/usr/palm/applications/$(PACKAGE_NAME_TARGET)/content/app/cobalt/lib/libcobalt.so; \
	fi
	if [ -f cobalt/out/$(COBALT_PLATFORM-sbversion-$(COBALT_SB_API_VERSION))_$(COBALT_BUILD_TYPE)/libcobalt.so ]; then \
		cp cobalt/out/$(COBALT_PLATFORM)-sbversion-$(COBALT_SB_API_VERSION)_$(COBALT_BUILD_TYPE)/libcobalt.so $(WORKDIR)/image/usr/palm/applications/$(PACKAGE_NAME_TARGET)/content/app/cobalt/lib/libcobalt.so; \
	fi
	cp -r cobalt/out/$(COBALT_PLATFORM)-sbversion-$(COBALT_SB_API_VERSION)_$(COBALT_BUILD_TYPE)/content/web/adblock/ $(WORKDIR)/image/usr/palm/applications/$(PACKAGE_NAME_TARGET)/content/app/cobalt/content/web/
	echo " --evergreen_lite" >> $(WORKDIR)/image/usr/palm/applications/$(PACKAGE_NAME_TARGET)/switches
	cp -r $(WORKDIR)/image/usr/palm/applications/$(PACKAGE_NAME_TARGET) $(WORKDIR)/package/usr/palm/applications
	rm -fr $(WORKDIR)/package/usr/palm/data
	rm -f $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/drm.nfz
	cp -r $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_TARGET) $(WORKDIR)/ipk

.PHONY: ares-package
ares-package:
	aresCmd=$$(command -v ares-package); \
	if [ "$$aresCmd" == "" ]; then \
		npm install @webosose/ares-cli; \
		aresCmd=node_modules/.bin/ares-package; \
	fi; \
	$$aresCmd -v -c $(WORKDIR)/ipk; \
	$$aresCmd -v --outdir ./output $(WORKDIR)/ipk

.PHONY: ares-package-docker
ares-package-docker: docker-make.ares-package
	@echo ""

.PHONY: ares-install
ares-install:
	aresCmd=$$(command -v ares-install); \
	if [ "$$aresCmd" == "" ]; then \
		npm install @webosose/ares-cli; \
		aresCmd=node_modules/.bin/ares-install; \
	fi; \
	$$aresCmd ./output/$(shell ls --sort=time output | head -n 1)

.PHONY: ares-install-docker
ares-install-docker: docker-make.ares-install

.PHONY: package
package: clean-ipk ipk-unpack ipk-update ares-package-docker
	@echo "Package can be installed with:"
	@echo "  ares-install ./output/<file>.ipk"
	@echo "  or"
	@echo "  make ares-install"
	@echo "  or"
	@echo "  make ares-install-docker"
