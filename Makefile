# language: Makefile, target: Theos — build rootful + rootless + roothide
TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e

TWEAK_NAME = ClaudeGuard
ClaudeGuard_FILES = Tweak.xm
ClaudeGuard_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function
ClaudeGuard_FRAMEWORKS = UIKit Foundation CFNetwork StoreKit
ClaudeGuard_PRIVATE_FRAMEWORKS = FrontBoard

INSTALL_TARGET_PROCESSES = Claude

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk

# Nhánh roothide dùng filter plist riêng để tránh xung đột path
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
ClaudeGuard_FILES = Tweak.xm
endif

after-install::
	install.exec "killall -9 Claude 2>/dev/null || true"
