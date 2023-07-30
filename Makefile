COBALT_BUILD_TYPE?=gold
COBALT_SB_API_VERSION?=12
COBALT_PLATFORM?=evergreen-arm-softfp-sbversion-$(COBALT_SB_API_VERSION)
COBALT_TARGET?=cobalt

PACKAGE_NAME?=
PACKAGE_NAME_OFFICIAL=youtube.leanback.v4
PACKAGE_NAME_END=$(if $(PACKAGE_NAME),$(PACKAGE_NAME),$(PACKAGE_NAME_OFFICIAL))
YOUTUBE_IPK?=ipks/2022-12-01-youtube.leanback.v4.ipk

SHELL?=/bin/bash

.PHONY: all
all: ipk-unpack cobalt-build package
	@echo ""

.PHONY: cobalt
cobalt: npm python cobalt-build
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
	ar x --output ipk/unpacked_ipk $(YOUTUBE_IPK)
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
ifneq ("$(PACKAGE_NAME_END)","$(PACKAGE_NAME_OFFICIAL)")
	find ipk -type d -name 'youtube.leanback.v4' | xargs -n1 rename "s/$(PACKAGE_NAME_OFFICIAL)/$(PACKAGE_NAME_END)/"
	grep -l -R "youtube.leanback.v4" ipk | grep .json | xargs -n 1 sed -i "s/$(PACKAGE_NAME_OFFICIAL)/$(PACKAGE_NAME_END)/g"
endif
	sed -i 's/YouTube/YouTube Cobalt AdBlock/g' ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/appinfo.json
	jq 'del(.fileSystemType)' < ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/appinfo.json >  ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/appinfo2.json
	mv ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/appinfo2.json ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/appinfo.json
	cp assets/icon.png ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/$$(jq -r '.icon' < ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/appinfo.json)
	cp assets/mediumLargeIcon.png ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/$$(jq -r '.mediumLargeIcon' < ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/appinfo.json)
	cp assets/largeIcon.png ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/$$(jq -r '.largeIcon' < ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/appinfo.json)
	cp assets/extraLargeIcon.png ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/$$(jq -r '.extraLargeIcon' < ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/appinfo.json)
	cp assets/playIcon.png ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/$$(jq -r '.playIcon' < ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/appinfo.json)
	cp assets/imageForRecents.png ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/$$(jq -r '.imageForRecents' < ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/appinfo.json)
	cp cobalt/out/$(COBALT_PLATFORM)_$(COBALT_BUILD_TYPE)/lib/libcobalt.so ipk/image/usr/palm/applications/$(PACKAGE_NAME_END)/content/app/cobalt/lib/libcobalt.so
	cp -r cobalt/out/$(COBALT_PLATFORM)_$(COBALT_BUILD_TYPE)/content/web/adblock/ ipk/image/usr/palm/applications/$(PACKAGE_NAME_END)/content/app/cobalt/content/web/
	echo "--disable_updater_module" >> ipk/image/usr/palm/applications/$(PACKAGE_NAME_END)/switches

.PHONY: package
package: ipk-update
	cp -r ipk/image/usr/palm/applications/$(PACKAGE_NAME_END) ipk/package/usr/palm/applications
	rm -fr ipk/package/usr/palm/data
	rm -f ipk/package/usr/palm/applications/$(PACKAGE_NAME_END)/drm.nfz
	cp -r ipk/package/usr/palm/applications/$(PACKAGE_NAME_END) ipk/ipk
	ares-package -v -c ipk/ipk
	ares-package -v --outdir ./output ipk/ipk
	echo "Package can be installed with:"
	echo "  ares-install ./output/<file>.ipk"
