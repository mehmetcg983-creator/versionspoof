TARGET := iphone:clang:latest:15.0
ARCHS := arm64
THEOS_PACKAGE_SCHEME := rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := KankaVersionSpoofer
KankaVersionSpoofer_FILES := Tweak.x
KankaVersionSpoofer_FRAMEWORKS := Foundation UIKit
KankaVersionSpoofer_CFLAGS := -fobjc-arc -Wall -Wextra
KankaVersionSpoofer_PLIST := KankaVersionSpoofer.plist

include $(THEOS_MAKE_PATH)/tweak.mk

after-stage::
	@mkdir -p "$(THEOS_STAGING_DIR)/DEBIAN"
	@chmod 755 "$(THEOS_STAGING_DIR)/DEBIAN"
	@find "$(THEOS_STAGING_DIR)" -type d -exec chmod 755 '{}' +
	@find "$(THEOS_STAGING_DIR)" -type f -exec chmod 644 '{}' +
	@find "$(THEOS_STAGING_DIR)" -type f -name 'KankaVersionSpoofer.dylib' -exec chmod 755 '{}' +

before-package::
	@find "$(THEOS_STAGING_DIR)" -type d -exec chmod 755 '{}' +
	@find "$(THEOS_STAGING_DIR)" -type f -exec chmod 644 '{}' +
	@find "$(THEOS_STAGING_DIR)" -type f -name 'KankaVersionSpoofer.dylib' -exec chmod 755 '{}' +
	@chmod 755 "$(THEOS_STAGING_DIR)/DEBIAN"
	@chmod 644 "$(THEOS_STAGING_DIR)/DEBIAN/control"

after-install::
	@echo "KankaVersionSpoofer installed. Terminate and relaunch App Store to load it."