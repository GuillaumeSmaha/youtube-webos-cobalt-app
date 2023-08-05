SHELL=/bin/bash

.SECONDEXPANSION:

MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
CURRENT_DIR := $(dir $(MAKEFILE_PATH))

PACKAGE?=
PACKAGE_TARGET?=$(basename $(PACKAGE))-patched.ipk
PACKAGE_NAME?=
PACKAGE_NAME_OFFICIAL=youtube.leanback.v4
PACKAGE_NAME_TARGET=$(if $(PACKAGE_NAME),$(PACKAGE_NAME),$(PACKAGE_NAME_OFFICIAL))
PACKAGE_COBALT_VERSION?=23.lts.4
PACKAGE_SB_API_VERSION?=$(shell strings $(WORKDIR)/image/usr/palm/applications/$(PACKAGE_NAME_OFFICIAL)/cobalt | grep sb_api | jq -r '.sb_api_version' | grep -v null || strings $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_OFFICIAL)/cobalt | grep sb_api | jq -r '.sb_api_version' | grep -v null)
PACKAGE_VERSION?=$(shell jq -r '.version' < $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_OFFICIAL)/appinfo.json)
PACKAGE_IPK_BUILD=$(PACKAGE_NAME_TARGET)_$(PACKAGE_VERSION)_arm.ipk
OFFICAL_YOUTUBE_IPK?=ipks-official/2023-07-30-youtube.leanback.v4-1.1.7.ipk

WORKDIR?=workdir
WORKDIR_COBALT?=$(WORKDIR)/cobalt-$(BUILD_COBALT_VERSION)

BUILD_VERSION?=
BUILD_COBALT_PARALLEL?=
BUILD_COBALT_TYPE?=gold
BUILD_COBALT_VERSION=$(word 1, $(subst -, ,$(BUILD_VERSION)))
BUILD_COBALT_SB_API_VERSION=$(word 2, $(subst -, ,$(BUILD_VERSION)))
BUILD_COBALT_ARCHITECTURE?=arm-softfp
BUILD_COBALT_PLATFORM?=evergreen-$(BUILD_COBALT_ARCHITECTURE)
BUILD_COBALT_TARGET?=cobalt
BUILD_COBALT_YOUTUBE_APP_FILES_RULES=$(foreach file,$(WEBOS_YOUTUBE_APP_FILES),$(WORKDIR_COBALT)/cobalt/adblock/content/$(file))

WEBOS_YOUTUBE_APP_FILES?=index.html index.js adblockMain.js adblockMain.css


.PHONY: all
all: package ;

.PHONY: help
help:
	@echo "To patch your ipk, use:"
	@echo "  make PACKAGE=./my-tv-youtube-application.ipk"
	@echo ""
	@echo "It will create a file with the suffix \"patched\": ./my-tv-youtube-application-patched.ipk"
	@echo "--"
	@echo "If you want to keep the official YouTube application aside of the patched version, you can update the name of the package:"
	@echo "  make PACKAGE=./my-tv-youtube-application.ipk PACKAGE_NAME=youtube-free.leanback.v4"
	@echo ""

.PHONY: ares-install
ares-install:
	aresCmd=$$(command -v ares-install); \
	if [ "$$aresCmd" == "" ]; then \
		npmCmd=$$(command -v npm); \
		if [ "$$npmCmd" == "" ]; then \
			echo "\"npm\" is required to install ares-cli"; \
		fi; \
		npm install @webosose/ares-cli; \
		aresCmd=node_modules/.bin/ares-install; \
	fi; \
	$$aresCmd ./output/$(shell ls --sort=time output | head -n 1)

.PHONY: check-package
check-package:
	@test ! -z "$(PACKAGE)" || (echo "\"make PACKAGE=./my-tv-youtube-application.ipk\" is required" && echo "--" && echo "" && $(MAKE) help && exit 1)
	@test -f $(PACKAGE) || (cho "File \"$(PACKAGE)\" does not exist" && echo "--" && echo "" && exit 1)
	@echo ""

.PHONY: package
package: check-package clean-ipk $(PACKAGE_TARGET) ;

.PHONY: clean-ipk
clean-ipk:
	rm -fr $(WORKDIR)/cobalt $(WORKDIR)/unpacked_ipk $(WORKDIR)/package $(WORKDIR)/image $(WORKDIR)/ipk $(WORKDIR)/ipk-output

.PRECIOUS: $(WORKDIR)/image/usr/palm/applications/$(PACKAGE_NAME_OFFICIAL)/cobalt
$(WORKDIR)/image/usr/palm/applications/$(PACKAGE_NAME_OFFICIAL)/cobalt:
	mkdir -p $(WORKDIR)/unpacked_ipk $(WORKDIR)/package $(WORKDIR)/image
	# Extract ipk
	ar x --output $(WORKDIR)/unpacked_ipk $(PACKAGE)
	tar xvzpf $(WORKDIR)/unpacked_ipk/control.tar.gz -C $(WORKDIR)/unpacked_ipk
	tar xvzpf $(WORKDIR)/unpacked_ipk/data.tar.gz -C $(WORKDIR)/package
	if [ -f $(WORKDIR)/package/usr/palm/data/images/$(PACKAGE_NAME_OFFICIAL)/data.img ]; then \
		unsquashfs -f -d $(WORKDIR)/image $(WORKDIR)/package/usr/palm/data/images/$(PACKAGE_NAME_OFFICIAL)/data.img; \
	fi

.PRECIOUS: $(WORKDIR)/cobalt
$(WORKDIR)/cobalt:
	mkdir -p $@
	@! test -z $(PACKAGE_SB_API_VERSION) || (echo "" && echo "--" && echo "Cannot find SB_API_VERSION in IPK binary. You can try to specify it with: make PACKAGE_SB_API_VERSION=12" && exit 1)
	tar -xJvf cobalt-bin/$(PACKAGE_COBALT_VERSION)-$(PACKAGE_SB_API_VERSION).xz -C $@

.PRECIOUS: $(WORKDIR)/ipk/content/app/cobalt/content/web/adblock
$(WORKDIR)/ipk/content/app/cobalt/content/web/adblock:

	mkdir -p $(WORKDIR)/ipk
	cp -r $(WORKDIR)/package/usr/palm/applications/$(PACKAGE_NAME_OFFICIAL)/* $(WORKDIR)/ipk
	if [ -d $(WORKDIR)/image/usr/palm/applications/$(PACKAGE_NAME_OFFICIAL) ]; then \
		cp -r $(WORKDIR)/image/usr/palm/applications/$(PACKAGE_NAME_OFFICIAL)/* $(WORKDIR)/ipk; \
	fi

	rm -f $(WORKDIR)/ipk/drm.nfz
	sed -i 's/YouTube/YouTube Cobalt AdBlock/g' $(WORKDIR)/ipk/appinfo.json
	jq 'del(.fileSystemType)' < $(WORKDIR)/ipk/appinfo.json > $(WORKDIR)/ipk/appinfo2.json
	mv $(WORKDIR)/ipk/appinfo2.json $(WORKDIR)/ipk/appinfo.json

	cp assets/icon.png $(WORKDIR)/ipk/$$(jq -r '.icon' < $(WORKDIR)/ipk/appinfo.json)
	cp assets/mediumLargeIcon.png $(WORKDIR)/ipk/$$(jq -r '.mediumLargeIcon' < $(WORKDIR)/ipk/appinfo.json)
	cp assets/largeIcon.png $(WORKDIR)/ipk/$$(jq -r '.largeIcon' < $(WORKDIR)/ipk/appinfo.json)
	cp assets/extraLargeIcon.png $(WORKDIR)/ipk/$$(jq -r '.extraLargeIcon' < $(WORKDIR)/ipk/appinfo.json)
	cp assets/playIcon.png $(WORKDIR)/ipk/$$(jq -r '.playIcon' < $(WORKDIR)/ipk/appinfo.json)
	cp assets/imageForRecents.png $(WORKDIR)/ipk/$$(jq -r '.imageForRecents' < $(WORKDIR)/ipk/appinfo.json)

	echo " --evergreen_lite" >> $(WORKDIR)/ipk/switches

ifneq ("$(PACKAGE_NAME_TARGET)","$(PACKAGE_NAME_OFFICIAL)")
	grep -l -R "$(PACKAGE_NAME_OFFICIAL)" $(WORKDIR)/ipk | grep .json | xargs -n 1 sed -i "s/$(PACKAGE_NAME_OFFICIAL)/$(PACKAGE_NAME_TARGET)/g"
endif

	libcobalt=$$(find $(WORKDIR)/ipk -name libcobalt.so); \
	! test -z "$$libcobalt" || (echo "" && echo "--" && echo "File \"libcobalt.so\" is not present in your IPK. This patch is not compatible with your IPK version." && exit 1) && \
	cp $(WORKDIR)/cobalt/libcobalt.so $$libcobalt
	cp -r $(WORKDIR)/cobalt/content $(WORKDIR)/ipk/content/app/cobalt

.PHONY: ares-package
ares-package:
	@aresCmd=$$(command -v ares-package); \
	if [ "$$aresCmd" == "" ]; then \
		npmCmd=$$(command -v npm); \
		if [ "$$npmCmd" == "" ]; then \
			echo "\"npm\" is required to install ares-cli"; \
		fi; \
		npm install @webosose/ares-cli; \
		aresCmd=node_modules/.bin/ares-package; \
	fi; \
	$$aresCmd -v -c $(WORKDIR)/ipk; \
	$$aresCmd -v --outdir $(WORKDIR)/ipk-output $(WORKDIR)/ipk

.PHONY: ares-package-docker
ares-package-docker: docker-make.ares-package
	@echo ""

.PRECIOUS: $(PACKAGE_TARGET)
$(PACKAGE_TARGET): $(WORKDIR)/image/usr/palm/applications/$(PACKAGE_NAME_OFFICIAL)/cobalt $(WORKDIR)/cobalt $(WORKDIR)/ipk/content/app/cobalt/content/web/adblock ares-package-docker
	mv $(WORKDIR)/ipk-output/$(PACKAGE_IPK_BUILD) $@
	@echo "Package can be installed with:"
	@echo "  ares-install $(PACKAGE_TARGET)"
	@echo "  or"
	@echo "  $(MAKE) ares-install"



# Part to build youtube-webos
# Example of usage
# make cobalt-bin/23.lts.4-12/libcobalt.so:

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

# Part to build cobalt
# Example of usage
# make cobalt-bin/23.lts.4-12/libcobalt.so
# make cobalt-bin/23.lts.4-12-x64x11/cobalt

clean-$(WORKDIR)/cobalt-%:
	cd $(WORKDIR)/cobalt-$* && git checkout . && git clean -d -f

$(WORKDIR)/cobalt-%/:
	git clone --depth 1 --branch $* https://github.com/youtube/cobalt.git $@

.PRECIOUS: $(WORKDIR)/cobalt-%/.patched
$(WORKDIR)/cobalt-%/.patched:
	cd $(dir $@) && patch -p1 < $(CURRENT_DIR)/cobalt-patches/cobalt-$*.patch || (echo "Missing patch for version $*" && exit 1)
	touch $@

.PRECIOUS: $(WORKDIR)/cobalt-%/cobalt/adblock/content
$(WORKDIR)/cobalt-%/cobalt/adblock/content :
	mkdir -p $@

define webos_youtube_app_rule
youtube-webos/output/$(1):
	$(MAKE) docker-make.npm
	touch youtube-webos/output/$(1)

.PRECIOUS: $(WORKDIR)/cobalt-%/cobalt/adblock/content/$(1)
$(WORKDIR)/cobalt-%/cobalt/adblock/content/$(1): $(WORKDIR)/cobalt-%/cobalt/adblock/content youtube-webos/output/$(1)
	cp youtube-webos/output/$(1) $$(WORKDIR_COBALT)/cobalt/adblock/content/$(1)
endef
$(foreach file,$(WEBOS_YOUTUBE_APP_FILES),$(eval $(call webos_youtube_app_rule,$(file))))

cobalt-bin:
	mkdir cobalt-bin

.PRECIOUS: cobalt-bin/libcobalt-%/libcobalt.so
cobalt-bin/%/libcobalt.so: BUILD_VERSION=$*
cobalt-bin/%/libcobalt.so: cobalt-bin $$(WORKDIR_COBALT)/ $$(WORKDIR_COBALT)/.patched $$(BUILD_COBALT_YOUTUBE_APP_FILES_RULES)
	cd $(WORKDIR_COBALT) && \
	docker-compose run $(if $(BUILD_COBALT_PARALLEL),-e NINJA_PARALLEL=$(BUILD_COBALT_PARALLEL),) -e CONFIG="$(BUILD_COBALT_TYPE)" -e TARGET="$(BUILD_COBALT_TARGET)" -e SB_API_VERSION="$(BUILD_COBALT_SB_API_VERSION)" $(BUILD_COBALT_PLATFORM)
	mkdir -p $(dir $@)
	cp -r $(WORKDIR_COBALT)/out/$(BUILD_COBALT_PLATFORM)-sbversion-$(BUILD_COBALT_SB_API_VERSION)_$(BUILD_COBALT_TYPE)/content $(dir $@)
	if [ -f $(WORKDIR_COBALT)/out/$(BUILD_COBALT_PLATFORM)-sbversion-$(BUILD_COBALT_SB_API_VERSION)_$(BUILD_COBALT_TYPE)/cobalt ]; then \
		cp $(WORKDIR_COBALT)/out/$(BUILD_COBALT_PLATFORM)-sbversion-$(BUILD_COBALT_SB_API_VERSION)_$(BUILD_COBALT_TYPE)/cobalt $(dir $@); \
	fi
	if [ -f $(WORKDIR_COBALT)/out/$(BUILD_COBALT_PLATFORM)-sbversion-$(BUILD_COBALT_SB_API_VERSION)_$(BUILD_COBALT_TYPE)/lib/libcobalt.so ]; then \
		cp $(WORKDIR_COBALT)/out/$(BUILD_COBALT_PLATFORM)-sbversion-$(BUILD_COBALT_SB_API_VERSION)_$(BUILD_COBALT_TYPE)/lib/libcobalt.so $@; \
	fi
	if [ -f $(WORKDIR_COBALT)/out/$(BUILD_COBALT_PLATFORM)-sbversion-$(BUILD_COBALT_SB_API_VERSION)_$(BUILD_COBALT_TYPE)/libcobalt.so ]; then \
		cp $(WORKDIR_COBALT)/out/$(BUILD_COBALT_PLATFORM)-sbversion-$(BUILD_COBALT_SB_API_VERSION)_$(BUILD_COBALT_TYPE)/libcobalt.so $@; \
	fi

cobalt-bin/%.xz:
	XZ_OPT="-9" tar -C $(basename $@) -cJvf $@ .

cobalt-bin/%-x64x11/cobalt: BUILD_VERSION=$*
cobalt-bin/%-x64x11/cobalt: BUILD_COBALT_PLATFORM=linux-x64x11
cobalt-bin/%-x64x11/cobalt: cobalt-bin/libcobalt-%-linux-x64x11/libcobalt.so ;

.PHONY: FORCE
.FORCE: ;
