ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = YKCaster

YKCaster_FILES = main.m Capture.m Encoder.m WsClient.m
YKCaster_FRAMEWORKS = UIKit Foundation CoreMedia CoreVideo VideoToolbox ReplayKit QuartzCore
YKCaster_CFLAGS = -fobjc-arc
YKCaster_CODESIGN_FLAGS = -Sentitlements.plist
YKCaster_INSTALL_PATH = /Applications

include $(THEOS_MAKE_PATH)/application.mk

# 确保 Info.plist 进包（Theos 有时不会自动拷）
after-stage::
	@echo ">>> 注入 Info.plist"
	@mkdir -p $(THEOS_STAGING_DIR)/Applications/YKCaster.app
	@cp $(THEOS_PROJECT_DIR)/YKCaster/Info.plist $(THEOS_STAGING_DIR)/Applications/YKCaster.app/Info.plist
	@ls -l $(THEOS_STAGING_DIR)/Applications/YKCaster.app/
