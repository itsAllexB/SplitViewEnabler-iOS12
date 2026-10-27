# SPDX-License-Identifier: GPL-3.0-or-later
TARGET := iphone:clang:14.5:12.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = SplitViewEnablerPrefs
SplitViewEnablerPrefs_FILES = SVERootListController.m
SplitViewEnablerPrefs_FRAMEWORKS = UIKit
SplitViewEnablerPrefs_PRIVATE_FRAMEWORKS = Preferences
SplitViewEnablerPrefs_INSTALL_PATH = /Library/PreferenceBundles
SplitViewEnablerPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk
