TARGET := iphone:clang:latest:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME := rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := YusufSpoofer
YusufSpoofer_FILES := Tweak.x
YusufSpoofer_FRAMEWORKS := Foundation UIKit
YusufSpoofer_CFLAGS := -fobjc-arc -Wall -Wextra
YusufSpoofer_PLIST := YusufSpoofer.plist

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += YusufSpooferPrefs
YusufSpooferPrefs_FILES := YusufSpooferPrefs.mm
YusufSpooferPrefs_FRAMEWORKS := UIKit Preferences
YusufSpooferPrefs_INSTALL_PATH := /Library/PreferenceBundles
YusufSpooferPrefs_BUNDLE_NAME := YusufSpooferPrefs

include $(THEOS_MAKE_PATH)/bundle.mk

after-stage::
	@mkdir -p "$(THEOS_STAGING_DIR)/DEBIAN"
	@chmod 755 "$(THEOS_STAGING_DIR)/DEBIAN"
	@find "$(THEOS_STAGING_DIR)" -type d -exec chmod 755 '{}' +
	@find "$(THEOS_STAGING_DIR)" -type f -exec chmod 644 '{}' +
	@find "$(THEOS_STAGING_DIR)" -type f -name 'YusufSpoofer.dylib' -exec chmod 755 '{}' +

before-package::
	@find "$(THEOS_STAGING_DIR)" -type d -exec chmod 755 '{}' +
	@find "$(THEOS_STAGING_DIR)" -type f -exec chmod 644 '{}' +
	@find "$(THEOS_STAGING_DIR)" -type f -name 'YusufSpoofer.dylib' -exec chmod 755 '{}' +
	@chmod 755 "$(THEOS_STAGING_DIR)/DEBIAN"
	@chmod 644 "$(THEOS_STAGING_DIR)/DEBIAN/control"

after-install::
	@echo "YusufSpoofer installed. Toggle respring to apply the spoofed version."