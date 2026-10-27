// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 itsAllexB

// SplitViewEnabler 2.0.0
// Makes SpringBoard report iPad multitasking ("medusa") capabilities beyond Slide Over.
//
// Findings for iOS 12.5.x SpringBoard (3757.146):
//  * -[SBPlatformController init] computes _medusaCapabilities once from MobileGestalt:
//      MedusaFloatingLiveAppCapability (UCG5MkVahJxG1YULbbd5Bg) -> 1  Slide Over only
//      MedusaPinnedAppCapability       (ZYqko/XM5zD3XBfN5RmaXA) -> 2  + Split View (2 apps max)
//      MedusaOverlayAppCapability      (mG0AnH/Vy1veoqoLRAIgTA) -> 3  + Slide Over on top of Split View
//    (internal SBWorkspaceDefaults.medusaDeviceSimulation can override it).
//  * The ivar is written only in -init and read only by the -medusaCapabilities getter, so the
//    getter is the single choke point; every other SpringBoard gate (drop actions, pin gesture,
//    layout validation, SBApplicationInfo full-screen flag, SBMainWorkspace.isMedusaEnabled)
//    goes through the getter. No other MobileGestalt medusa reads exist in SpringBoard.
//  * Per-app gating (SBApplication -isMedusaCapable: launch storyboard, UIRequiresFullScreen,
//    iPad support) is left alone, so apps without multitasking support stay full screen.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

#define kSVEDomain CFSTR("com.itsallexb.splitviewenabler")
#define kSVENotification "com.itsallexb.splitviewenabler/prefschanged"

// 0 = stock (leave SpringBoard's value), 2 = Split View (2 apps), 3 = Split View + Slide Over
static BOOL gEnabled = YES;
static long long gMode = 3;

static void SVELoadPrefs(void) {
    CFPreferencesAppSynchronize(kSVEDomain);
    CFPropertyListRef en = CFPreferencesCopyAppValue(CFSTR("enabled"), kSVEDomain);
    CFPropertyListRef mo = CFPreferencesCopyAppValue(CFSTR("mode"), kSVEDomain);
    gEnabled = en ? [(__bridge id)en boolValue] : YES;
    long long mode = mo ? [(__bridge id)mo longLongValue] : 3;
    gMode = (mode == 0 || mode == 2 || mode == 3) ? mode : 3;
    if (en) CFRelease(en);
    if (mo) CFRelease(mo);
}

%group SVEHooks

%hook SBPlatformController
- (long long)medusaCapabilities {
    long long stock = %orig;
    // Only raise devices that already have Slide Over (1). Never lower a capability.
    if (gEnabled && gMode > stock && stock >= 1) return gMode;
    return stock;
}
%end

%end

static void SVEPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    SVELoadPrefs();
    dispatch_async(dispatch_get_main_queue(), ^{
        // Recompute SBMainWorkspace._medusaEnabled and post SBMedusaEnabledStateChangedNotification.
        Class ws = objc_getClass("SBMainWorkspace");
        SEL upd = sel_registerName("_updateMedusaEnablementAndNotify:");
        id shared = [ws respondsToSelector:@selector(sharedInstance)] ? [ws performSelector:@selector(sharedInstance)] : nil;
        if (shared && [shared respondsToSelector:upd]) {
            ((void (*)(id, SEL, BOOL))objc_msgSend)(shared, upd, YES);
        }
    });
}

%ctor {
    @autoreleasepool {
        Class cls = objc_getClass("SBPlatformController");
        if (!cls || ![cls instancesRespondToSelector:@selector(medusaCapabilities)]) {
            NSLog(@"[SplitViewEnabler] SBPlatformController -medusaCapabilities not found; not hooking");
            return;
        }
        SVELoadPrefs();
        %init(SVEHooks);
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, SVEPrefsChanged,
            CFSTR(kSVENotification), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}
