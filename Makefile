COBALT_BUILD_TYPE?=gold
COBALT_SB_API_VERSION?=12
COBALT_ARCHITECTURE?=arm-softfp
COBALT_PLATFORM?=evergreen-$(COBALT_ARCHITECTURE)-sbversion-$(COBALT_SB_API_VERSION)
COBALT_TARGET?=cobalt

PACKAGE_NAME?=
PACKAGE_NAME_OFFICIAL=youtube.leanback.v4
PACKAGE_NAME_TARGET=$(if $(PACKAGE_NAME),$(PACKAGE_NAME),$(PACKAGE_NAME_OFFICIAL))
OFFICAL_YOUTUBE_IPK?=ipks-official/2023-07-30-youtube.leanback.v4.ipk

SHELL?=/bin/bash

.PHONY: all
all: ipk-unpack cobalt-build package
	@echo ""

.PHONY: cobalt
cobalt: npm cobalt-build
	@echo ""

.PHONY: cobalt-clean
cobalt-clean:
	(cd cobalt ; git checkout . ; git clean -d -f)

.PHONY: npm
npm:
	( \
		cd youtube-webos && \
		npm install && \
		npm run build -- --env production --optimization-minimize \
	)

.PHONY: npm-docker
npm-docker:
	docker run --rm -ti -u $$(id -u):$$(id -g) -v $$PWD:/app -w /app node:18 make npm

.PHONY: cobalt-patches
cobalt-patches: cobalt-patches/*.patch
	@for file in $^ ; do \
		[ -f ./cobalt/.$$file ] && echo "Already applied "$$file || (echo "Apply patch "$$file ; ( cd cobalt ; patch -p1 < ../$$file ; mkdir -p $$(dirname .$$file) ; touch .$$file )) ; \
	done

.PHONY: cobalt-build
cobalt-build: cobalt-patches npm-docker
	cd cobalt && \
	docker-compose run -e NINJA_PARALLEL=8 -e CONFIG="$(COBALT_BUILD_TYPE)" -e TARGET="$(COBALT_TARGET)" -e SB_API_VERSION="$(COBALT_SB_API_VERSION)" $(COBALT_PLATFORM)

.PHONY: cobalt-build-test
cobalt-build-test: COBALT_PLATFORM=linux-x64x11
cobalt-build-test: cobalt-build
	@echo "Done"


.PHONY: clean-ipk
clean-ipk:
	rm -fr ipk

.PHONY: ipk-unpack
ipk-unpack: clean-ipk
	mkdir -p ipk/unpacked_ipk ipk/package ipk/image
	ar x --output ipk/unpacked_ipk $(OFFICAL_YOUTUBE_IPK)
	tar xvzpf ipk/unpacked_ipk/control.tar.gz -C ipk/unpacked_ipk
	tar xvzpf ipk/unpacked_ipk/data.tar.gz -C ipk/package
	unsquashfs -f -d ipk/image ipk/package/usr/palm/data/images/$(PACKAGE_NAME_OFFICIAL)/data.img
	ipkOfficialVersion=$$(strings ipk/image/usr/palm/applications/$(PACKAGE_NAME_OFFICIAL)/cobalt | grep sb_api | jq -r '.sb_api_version'); \
	if [ "$(COBALT_SB_API_VERSION)" != "$$ipkOfficialVersion" ]; then \
		echo "Incompatible SB API version:"; \
		echo "  Current build is using "$(COBALT_SB_API_VERSION); \
		echo "  Official IPK package is using "$$ipkOfficialVersion; \
		exit 1; \
	fi

.PHONY: ipk-update
ipk-update:
ifneq ("$(PACKAGE_NAME_TARGET)","$(PACKAGE_NAME_OFFICIAL)")
	find ipk -type d -name 'youtube.leanback.v4' | xargs -n1 rename "s/$(PACKAGE_NAME_OFFICIAL)/$(PACKAGE_NAME_TARGET)/"
	grep -l -R "youtube.leanback.v4" ipk | grep .json | xargs -n 1 sed -i "s/$(PACKAGE_NAME_OFFICIAL)/$(PACKAGE_NAME_TARGET)/g"
endif
	sed -i 's/YouTube/YouTube Cobalt AdBlock/g' ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json
	jq 'del(.fileSystemType)' < ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json >  ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo2.json
	mv ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo2.json ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json
	cp assets/icon.png ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/$$(jq -r '.icon' < ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json)
	cp assets/mediumLargeIcon.png ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/$$(jq -r '.mediumLargeIcon' < ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json)
	cp assets/largeIcon.png ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/$$(jq -r '.largeIcon' < ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json)
	cp assets/extraLargeIcon.png ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/$$(jq -r '.extraLargeIcon' < ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json)
	cp assets/playIcon.png ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/$$(jq -r '.playIcon' < ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json)
	cp assets/imageForRecents.png ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/$$(jq -r '.imageForRecents' < ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/appinfo.json)
	if [ -f cobalt/out/$(COBALT_PLATFORM)_$(COBALT_BUILD_TYPE)/lib/libcobalt.so ]; then \
		cp cobalt/out/$(COBALT_PLATFORM)_$(COBALT_BUILD_TYPE)/lib/libcobalt.so ipk/image/usr/palm/applications/$(PACKAGE_NAME_TARGET)/content/app/cobalt/lib/libcobalt.so; \
	fi
	if [ -f cobalt/out/$(COBALT_PLATFORM)_$(COBALT_BUILD_TYPE)/libcobalt.so ]; then \
		cp cobalt/out/$(COBALT_PLATFORM)_$(COBALT_BUILD_TYPE)/libcobalt.so ipk/image/usr/palm/applications/$(PACKAGE_NAME_TARGET)/content/app/cobalt/lib/libcobalt.so; \
	fi
	cp -r cobalt/out/$(COBALT_PLATFORM)_$(COBALT_BUILD_TYPE)/content/web/adblock/ ipk/image/usr/palm/applications/$(PACKAGE_NAME_TARGET)/content/app/cobalt/content/web/
	echo " --evergreen_lite" >> ipk/image/usr/palm/applications/$(PACKAGE_NAME_TARGET)/switches

.PHONY: package
package: ipk-update
	cp -r ipk/image/usr/palm/applications/$(PACKAGE_NAME_TARGET) ipk/package/usr/palm/applications
	rm -fr ipk/package/usr/palm/data
	rm -f ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET)/drm.nfz
	cp -r ipk/package/usr/palm/applications/$(PACKAGE_NAME_TARGET) ipk/ipk
	ares-package -v -c ipk/ipk
	ares-package -v --outdir ./output ipk/ipk
	echo "Package can be installed with:"
	echo "  ares-install ./output/<file>.ipk"
