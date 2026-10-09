# language: Makefile, target: Theos — ClaudeGuard tweak
TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e

TWEAK_NAME = ClaudeGuard
ClaudeGuard_FILES = Tweak.xm
ClaudeGuard_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable
ClaudeGuard_FRAMEWORKS = UIKit Foundation CFNetwork StoreKit

# Gắn entitlements
ClaudeGuard_CODESIGN_FLAGS = -SEntitlements.plist

INSTALL_TARGET_PROCESSES = Claude

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Claude 2>/dev/null || true"
