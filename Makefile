ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = YKCaster

YKCaster_FILES = main.m Capture.m DisplayCapture.m Encoder.m WsClient.m YLog.m
YKCaster_FRAMEWORKS = UIKit Foundation CoreMedia CoreVideo VideoToolbox QuartzCore IOSurface
YKCaster_CFLAGS = -fobjc-arc
YKCaster_CODESIGN_FLAGS = -Sentitlements.plist
YKCaster_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk

LIBRARY_NAME = YKScreenHook

YKScreenHook_FILES = ScreenHook.m DisplayCapture.m Encoder.m WsClient.m YLog.m
YKScreenHook_FRAMEWORKS = UIKit Foundation QuartzCore CoreVideo CoreMedia VideoToolbox
YKScreenHook_CFLAGS = -fobjc-arc -Wno-unused-function -Wno-unused-variable
YKScreenHook_CODESIGN_FLAGS = -Sentitlements.plist
YKScreenHook_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/library.mk

# App 的 Info.plist 与 dylib 的 Filter plist 都要手动放进 staging
after-stage::
	@mkdir -p "$(THEOS_STAGING_DIR)/Applications/YKCaster.app"
	@cp "$(THEOS_PROJECT_DIR)/YKCaster/Info.plist" "$(THEOS_STAGING_DIR)/Applications/YKCaster.app/Info.plist"
	@mkdir -p "$(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries"
	@cp "$(THEOS_PROJECT_DIR)/YKScreenHook.plist" "$(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/YKScreenHook.plist"
	@ls -l "$(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/" || true
