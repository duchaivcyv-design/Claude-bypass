# language: Makefile, target: Theos — ClaudeGuard tweak
# Build được: rootful + rootless + roothide

TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e

TWEAK_NAME = ClaudeGuard
ClaudeGuard_FILES = Tweak.xm
ClaudeGuard_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable
ClaudeGuard_FRAMEWORKS = UIKit Foundation CFNetwork StoreKit

INSTALL_TARGET_PROCESSES = Claude

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

# Kill Claude sau khi cài (chỉ chạy khi cài qua Sileo/Filza, không ảnh hưởng CI build)
after-install::
	install.exec "killall -9 Claude 2>/dev/null || true"
