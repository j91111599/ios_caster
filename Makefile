ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard

ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
    PREFIX = /var/jb
else
    PREFIX = /
endif

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = YKCaster

YKCaster_FILES = main.m Capture.m Encoder.m WsClient.m
YKCaster_FRAMEWORKS = UIKit Foundation CoreMedia CoreVideo VideoToolbox ReplayKit
YKCaster_CFLAGS = -fobjc-arc
YKCaster_CODESIGN_FLAGS = -Sentitlements.plist
YKCaster_INSTALL_PATH = $(PREFIX)/Applications

include $(THEOS_MAKE_PATH)/application.mk

TWEAK_NAME = YKScreenHook
YKScreenHook_FILES = Tweak.xm Encoder.m WsClient.m
YKScreenHook_FRAMEWORKS = UIKit Foundation QuartzCore CoreVideo CoreMedia VideoToolbox
YKScreenHook_CFLAGS = -fobjc-arc -Wno-unused-function
YKScreenHook_CODESIGN_FLAGS = -Sentitlements.plist
YKScreenHook_INSTALL_PATH = $(PREFIX)/Library/MobileSubstrate/DynamicLibraries
YKScreenHook_FILTER = Bundles = com.apple.springboard

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard || true"
