ARCHS := arm64 arm64e
TARGET := iphone:clang:16.5:14.0
INSTALL_TARGET_PROCESSES := Preferences

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME += TrollMemoPrefs

TrollMemoPrefs_FILES += TSPrefsRootListController.m

ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
TrollMemoPrefs_FILES += ../libroot/dyn.c
TrollMemoPrefs_LIBRARIES += roothide
endif

TrollMemoPrefs_CFLAGS += -fobjc-arc
TrollMemoPrefs_CFLAGS += -I../supports/

TrollMemoPrefs_FRAMEWORKS += UIKit
TrollMemoPrefs_PRIVATE_FRAMEWORKS += Preferences
TrollMemoPrefs_INSTALL_PATH += /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
