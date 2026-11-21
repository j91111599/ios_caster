ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = YKCaster

YKCaster_FILES = main.m Capture.m Encoder.m WsClient.m
YKCaster_FRAMEWORKS = UIKit Foundation CoreMedia CoreVideo VideoToolbox ReplayKit QuartzCore
YKCaster_CFLAGS = -fobjc-arc
YKCaster_CODESIGN_FLAGS = -Sentitlements.plist
YKCaster_INSTALL_PATH = $(THEOS_PACKAGE_INSTALL_PREFIX)/Applications

include $(THEOS_MAKE_PATH)/application.mk

# ── Tweak 目标暂时禁用：先用 App(ReplayKit) 跑通链路，再单独修 Tweak.xm ──
# TWEAK_NAME = YKScreenHook
# YKScreenHook_FILES = Tweak.xm Encoder.m WsClient.m
# YKScreenHook_FRAMEWORKS = UIKit Foundation QuartzCore CoreVideo CoreMedia VideoToolbox
# YKScreenHook_CFLAGS = -fobjc-arc -Wno-unused-function
# YKScreenHook_CODESIGN_FLAGS = -Sentitlements.plist
# YKScreenHook_INSTALL_PATH = $(THEOS_PACKAGE_INSTALL_PREFIX)/Library/MobileSubstrate/DynamicLibraries
# YKScreenHook_FILTER = Bundles = com.apple.springboard
# include $(THEOS_MAKE_PATH)/tweak.mk
