ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = YKCaster

YKCaster_FILES = main.m Capture.m Encoder.m WsClient.m YLog.m
YKCaster_FRAMEWORKS = UIKit Foundation CoreMedia CoreVideo VideoToolbox ReplayKit QuartzCore
YKCaster_CFLAGS = -fobjc-arc
YKCaster_CODESIGN_FLAGS = -Sentitlements.plist
YKCaster_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk

TWEAK_NAME = YKScreenHook

YKScreenHook_FILES = Tweak.xm Encoder.m WsClient.m YLog.m
YKScreenHook_FRAMEWORKS = UIKit Foundation QuartzCore CoreVideo CoreMedia VideoToolbox
YKScreenHook_CFLAGS = -fobjc-arc -Wno-unused-function -Wno-unused-variable
YKScreenHook_CODESIGN_FLAGS = -Sentitlements.plist
YKScreenHook_INSTALL_PATH = $(THEOS_PACKAGE_INSTALL_PREFIX)/Library/MobileSubstrate/DynamicLibraries
YKScreenHook_FILTER = Bundles = com.apple.springboard

include $(THEOS_MAKE_PATH)/tweak.mk

after-stage::
	@mkdir -p $(THEOS_STAGING_DIR)/Applications/YKCaster.app
	@cp $(THEOS_PROJECT_DIR)/YKCaster/Info.plist $(THEOS_STAGING_DIR)/Applications/YKCaster.app/Info.plist
