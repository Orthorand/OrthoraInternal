export TARGET = iphone:clang:14.0:13.0
export ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = patchlq
patchlq_FILES = main.m AppDelegate.m ViewController.m Patcher.m
patchlq_CFLAGS = -fobjc-arc -O2 -I.
patchlq_CODESIGN_FLAGS = -Sentitlements.plist
patchlq_INSTALL_PATH = /Applications/patchlq.app

include $(THEOS_MAKE_PATH)/application.mk

after-stage::
	@# Copy tools
	cp ../../tools/insert_dylib $(THEOS_STAGING_DIR)/Applications/patchlq.app/
	cp ../../tools/unzip $(THEOS_STAGING_DIR)/Applications/patchlq.app/
	chmod +x $(THEOS_STAGING_DIR)/Applications/patchlq.app/insert_dylib
	chmod +x $(THEOS_STAGING_DIR)/Applications/patchlq.app/unzip
	@# Copy dylib zip
	mkdir -p $(THEOS_STAGING_DIR)/Applications/patchlq.app/dylibs
	for region in kgvn kgtw kgth; do \
		cp ../../dylibs/$$region.zip $(THEOS_STAGING_DIR)/Applications/patchlq.app/dylibs/; \
	done
