export TARGET = iphone:clang:14.0:13.0
export ARCHS = arm64 arm64e
export GO_EASY_ON_ME = 1

INSTALL_TARGET_PROCESSES = LiênQuân

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = orthora
orthora_FILES = src/main.mm src/MachOUnity.mm src/IL2CPPDump.mm src/ESPHook.mm src/MetalRenderer.mm src/TouchHandler.mm
orthora_CFLAGS = -fobjc-arc -std=c++20 -Iinclude
orthora_LDFLAGS = -lobjc -framework UIKit -framework Metal -framework MetalKit -framework QuartzCore -framework CoreGraphics

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 LiênQuân" || true
