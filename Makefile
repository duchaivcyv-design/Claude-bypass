ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Claude

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ClaudeGuard
ClaudeGuard_FILES = Tweak.xm
ClaudeGuard_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
ClaudeGuard_FRAMEWORKS = UIKit Foundation CFNetwork
ClaudeGuard_PRIVATE_FRAMEWORKS = FrontBoard

include $(THEOS_MAKE_PATH)/tweak.mk
