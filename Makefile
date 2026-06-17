ARCHS := arm64  # arm64e
# 默认 SDK 与最低系统版本：适配 iOS 15.x（含 15.6）；CI 可通过 make SDK_VERSION=x.x 覆盖
SDKVERSION ?= 15.6
TARGET_IOS ?= 15.0
TARGET := iphone:clang:$(SDKVERSION):$(TARGET_IOS)
ifdef SDK_VERSION
SDKVERSION := $(SDK_VERSION)
TARGET := iphone:clang:$(SDKVERSION):$(TARGET_IOS)
endif
INSTALL_TARGET_PROCESSES := TrollMemo
ENT_PLIST := $(PWD)/supports/entitlements.plist
LAUNCHD_PLIST := $(PWD)/layout/Library/LaunchDaemons/ch.better.hudservices.plist
THEOS_MAKE_PATH = $(THEOS)/makefiles
TWEAK_NAME = TrollMemo
INSTALL_PATH = /Applications/TrollMemo.app

include $(THEOS)/makefiles/common.mk

APP_VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist 2>/dev/null || echo 1.0)
APPLICATION_NAME := TrollMemo

TrollMemo_USE_MODULES := 0

TrollMemo_FILES += $(wildcard sources/*.mm sources/*.m)
TrollMemo_FILES += $(wildcard sources/KIF/*.mm sources/KIF/*.m)
TrollMemo_FILES += $(wildcard sources/*.swift)
TrollMemo_FILES += $(wildcard sources/SPLarkController/*.swift)
TrollMemo_FILES += $(wildcard sources/SnapshotSafeView/*.swift)

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
TrollMemo_FILES += libroot/dyn.c
TrollMemo_LIBRARIES += roothide
endif

# App Intents will be built from Xcode.
# TrollMemo_FILES += $(wildcard sources/Intents/*.swift)

TrollMemo_CFLAGS += -fobjc-arc
TrollMemo_CFLAGS += -Iheaders
TrollMemo_CFLAGS += -Isources
TrollMemo_CFLAGS += -Isources/KIF
TrollMemo_CFLAGS += -Isupports
TrollMemo_CFLAGS += -include supports/hudapp-prefix.pch
MainApplication.mm_CCFLAGS += -std=c++14

TrollMemo_SWIFT_BRIDGING_HEADER += supports/hudapp-bridging-header.h

TrollMemo_LDFLAGS += -F$(PWD)/libraries

TrollMemo_FRAMEWORKS += CoreGraphics CoreServices QuartzCore IOKit UIKit
TrollMemo_PRIVATE_FRAMEWORKS += BackBoardServices GraphicsServices SpringBoardServices
TrollMemo_CODESIGN_FLAGS += -Ssupports/entitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

SUBPROJECTS += prefs
ifneq ($(FINALPACKAGE),1)
SUBPROJECTS += memory_pressure
endif

include $(THEOS_MAKE_PATH)/aggregate.mk

pre-build:
	@test -d $(THEOS)/.theos/_/Applications/TrollMemo.app || mkdir -p $(THEOS)/.theos/_/Applications/TrollMemo.app
	@test -f /usr/local/bin/lzma || (echo "Using gzip compression"; $(MAKE) gzip-config)
	@test -d $(THEOS_STAGING_DIR)$(INSTALL_PATH) || mkdir -p $(THEOS_STAGING_DIR)$(INSTALL_PATH)

gzip-config:
	@echo 'THEOS_PLATFORM_DPKG_DEB_COMPRESSION = gzip' >> $(THEOS_MAKE_PATH)/package/deb.mk

before-all::
	$(ECHO_NOTHING)defaults write $(LAUNCHD_PLIST) ProgramArguments -array "$(THEOS_PACKAGE_INSTALL_PREFIX)/Applications/TrollMemo.app/TrollMemo" "-hud" || true$(ECHO_END)
	$(ECHO_NOTHING)plutil -convert xml1 $(LAUNCHD_PLIST)$(ECHO_END)
	$(ECHO_NOTHING)chmod 0644 $(LAUNCHD_PLIST)$(ECHO_END)

before-package::
	$(ECHO_NOTHING)mv -f $(THEOS_STAGING_DIR)/usr/local/bin/memory_pressure $(THEOS_STAGING_DIR)/Applications/TrollMemo.app || true$(ECHO_END)
	$(ECHO_NOTHING)rmdir $(THEOS_STAGING_DIR)/usr/local/bin $(THEOS_STAGING_DIR)/usr/local $(THEOS_STAGING_DIR)/usr || true$(ECHO_END)

after-package::
	$(ECHO_NOTHING)mkdir -p packages $(THEOS_STAGING_DIR)/Payload$(ECHO_END)
	$(ECHO_NOTHING)cp -rp $(THEOS_STAGING_DIR)$(THEOS_PACKAGE_INSTALL_PREFIX)/Applications/TrollMemo.app $(THEOS_STAGING_DIR)/Payload$(ECHO_END)
	$(ECHO_NOTHING)defaults delete $(THEOS_STAGING_DIR)/Payload/TrollMemo.app/Info.plist CFBundleIconName || true$(ECHO_END)
	$(ECHO_NOTHING)defaults write $(THEOS_STAGING_DIR)/Payload/TrollMemo.app/Info.plist CFBundleVersion -string $(shell openssl rand -hex 4)$(ECHO_END)
	$(ECHO_NOTHING)plutil -convert xml1 $(THEOS_STAGING_DIR)/Payload/TrollMemo.app/Info.plist$(ECHO_END)
	$(ECHO_NOTHING)chmod 0644 $(THEOS_STAGING_DIR)/Payload/TrollMemo.app/Info.plist$(ECHO_END)
	$(ECHO_NOTHING)cd $(THEOS_STAGING_DIR); zip -qr TrollMemo_$(APP_VERSION).tipa Payload; cd -;$(ECHO_END)
	$(ECHO_NOTHING)mv $(THEOS_STAGING_DIR)/TrollMemo_$(APP_VERSION).tipa packages/TrollMemo_$(APP_VERSION).tipa$(ECHO_END)

THEOS_PLATFORM_DPKG_DEB_COMPRESSION = gzip
