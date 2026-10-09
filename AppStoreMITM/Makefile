TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e

TWEAK_NAME = AppStoreMITM
AppStoreMITM_FILES = Tweak.xm
AppStoreMITM_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
AppStoreMITM_FRAMEWORKS = UIKit Foundation CFNetwork

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
