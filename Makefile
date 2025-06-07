ARCHS := arm64  # arm64e
TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES := TrollMemo
ENT_PLIST := $(PWD)/supports/entitlements.plist
LAUNCHD_PLIST := $(PWD)/layout/Library/LaunchDaemons/ch.xxtou.hudservices.plist

include $(THEOS)/makefiles/common.mk

GIT_TAG_SHORT := $(shell git describe --tags --always --abbrev=0)
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
TrollMemo_CFLAGS += -include supports/hudapp-prefix.pch
MainApplication.mm_CCFLAGS += -std=c++14

TrollMemo_SWIFT_BRIDGING_HEADER += supports/hudapp-bridging-header.h

TrollMemo_LDFLAGS += -Flibraries

TrollMemo_FRAMEWORKS += CoreGraphics CoreServices QuartzCore IOKit UIKit
TrollMemo_PRIVATE_FRAMEWORKS += BackBoardServices GraphicsServices SpringBoardServices
TrollMemo_CODESIGN_FLAGS += -Ssupports/entitlements.plist

include $(THEOS_MAKE_PATH)/application.mk

SUBPROJECTS += prefs
ifneq ($(FINALPACKAGE),1)
SUBPROJECTS += memory_pressure
endif

include $(THEOS_MAKE_PATH)/aggregate.mk

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
	$(ECHO_NOTHING)cd $(THEOS_STAGING_DIR); zip -qr TrollMemo_${GIT_TAG_SHORT}.tipa Payload; cd -;$(ECHO_END)
	$(ECHO_NOTHING)mv $(THEOS_STAGING_DIR)/TrollMemo_${GIT_TAG_SHORT}.tipa packages/TrollMemo_${GIT_TAG_SHORT}.tipa$(ECHO_END)
