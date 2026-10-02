#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>
#import <math.h>

static CFStringRef const kKVSPreferencesDomain = CFSTR("com.kanka.versionspoofer");
static NSString *const kKVSReloadNotification = @"com.kanka.versionspoofer/prefsChanged";
static NSString *const kKVSAppStoreBundleID = @"com.apple.AppStore";

@interface KVSConfiguration : NSObject
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL debug;
@property (nonatomic) NSInteger major;
@property (nonatomic) NSInteger minor;
@property (nonatomic) NSInteger patch;
@property (nonatomic, copy) NSString *build;
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, copy) NSArray<NSString *> *selectedBundleIDs;
@end

@implementation KVSConfiguration
@end

static NSLock *gKVSConfigurationLock;
static KVSConfiguration *gKVSConfiguration;

static NSString *KVSVersionString(KVSConfiguration *configuration) {
    return [NSString stringWithFormat:@"%ld.%ld.%ld",
            (long)configuration.major, (long)configuration.minor, (long)configuration.patch];
}

static BOOL KVSReadInteger(NSDictionary *preferences, NSString *key, NSInteger *result) {
    id value = preferences[key];
    if (![value isKindOfClass:[NSNumber class]] ||
        CFGetTypeID((__bridge CFTypeRef)value) == CFBooleanGetTypeID()) {
        return NO;
    }

    double number = [value doubleValue];
    if (!isfinite(number) || floor(number) != number || number < 0 || number > 9999) {
        return NO;
    }

    *result = (NSInteger)number;
    return YES;
}

static KVSConfiguration *KVSReadConfiguration(void) {
    CFPreferencesAppSynchronize(kKVSPreferencesDomain);
    CFDictionaryRef copiedPreferences = CFPreferencesCopyMultiple(
        NULL, kKVSPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    NSDictionary *preferences = copiedPreferences ? CFBridgingRelease(copiedPreferences) : @{};

    KVSConfiguration *configuration = [KVSConfiguration new];
    configuration.enabled = YES;
    configuration.debug = NO;
    configuration.major = 16;
    configuration.minor = 7;
    configuration.patch = 16;
    configuration.build = @"";
    configuration.mode = @"appstore";
    configuration.selectedBundleIDs = @[];

    id enabled = preferences[@"Enabled"];
    if ([enabled isKindOfClass:[NSNumber class]]) {
        configuration.enabled = [enabled boolValue];
    }
    id debug = preferences[@"Debug"];
    if ([debug isKindOfClass:[NSNumber class]]) {
        configuration.debug = [debug boolValue];
    }

    NSInteger major = 0;
    NSInteger minor = 0;
    NSInteger patch = 0;
    BOOL validVersion = KVSReadInteger(preferences, @"Major", &major) && major > 0 &&
                        KVSReadInteger(preferences, @"Minor", &minor) &&
                        KVSReadInteger(preferences, @"Patch", &patch);
    if (validVersion) {
        configuration.major = major;
        configuration.minor = minor;
        configuration.patch = patch;
    }

    id mode = preferences[@"Mode"];
    if ([mode isKindOfClass:[NSString class]] &&
        [@[@"appstore", @"all", @"selected"] containsObject:mode]) {
        configuration.mode = mode;
    }

    id build = preferences[@"Build"];
    if ([build isKindOfClass:[NSString class]] && [build length] <= 64 &&
        [build rangeOfString:@"^[A-Za-z0-9.-]*$" options:NSRegularExpressionSearch].location != NSNotFound) {
        configuration.build = build;
    }

    id selectedBundleIDs = preferences[@"SelectedBundleIDs"];
    if ([selectedBundleIDs isKindOfClass:[NSArray class]]) {
        NSMutableArray<NSString *> *validBundleIDs = [NSMutableArray array];
        for (id bundleID in selectedBundleIDs) {
            if ([bundleID isKindOfClass:[NSString class]] && [bundleID length] > 0) {
                [validBundleIDs addObject:bundleID];
            }
        }
        configuration.selectedBundleIDs = [validBundleIDs copy];
    }

    return configuration;
}

static void KVSReloadConfiguration(void) {
    KVSConfiguration *configuration = KVSReadConfiguration();
    [gKVSConfigurationLock lock];
    gKVSConfiguration = configuration;
    [gKVSConfigurationLock unlock];
}

static KVSConfiguration *KVSCurrentConfiguration(void) {
    [gKVSConfigurationLock lock];
    KVSConfiguration *configuration = gKVSConfiguration;
    [gKVSConfigurationLock unlock];
    return configuration;
}

static NSString *KVSCurrentBundleID(void) {
    return [NSBundle mainBundle].bundleIdentifier ?: @"";
}

static BOOL KVSIsApplicationProcess(void) {
    NSString *bundleID = KVSCurrentBundleID();
    NSString *processName = [NSProcessInfo processInfo].processName;
    if (bundleID.length == 0 || [bundleID isEqualToString:@"com.apple.springboard"] ||
        [processName isEqualToString:@"SpringBoard"] || [processName isEqualToString:@"launchd"]) {
        return NO;
    }

    NSString *extension = [NSBundle mainBundle].bundleURL.pathExtension.lowercaseString;
    return [extension isEqualToString:@"app"] || [extension isEqualToString:@"appex"];
}

static BOOL KVSShouldSpoof(KVSConfiguration **currentConfiguration) {
    KVSConfiguration *configuration = KVSCurrentConfiguration();
    if (currentConfiguration) {
        *currentConfiguration = configuration;
    }
    if (!configuration.enabled) {
        return NO;
    }

    NSString *bundleID = KVSCurrentBundleID();
    if ([configuration.mode isEqualToString:@"all"]) {
        return YES;
    }
    if ([configuration.mode isEqualToString:@"selected"]) {
        return [configuration.selectedBundleIDs containsObject:bundleID];
    }
    return [bundleID isEqualToString:kKVSAppStoreBundleID];
}

static void KVSLog(NSString *hook, NSString *realValue, NSString *spoofedValue,
                   KVSConfiguration *configuration) {
    if (!configuration.debug) {
        return;
    }
    NSLog(@"[KankaVersionSpoofer] process=%@ bundle=%@ hook=%@ real=%@ spoof=%@",
          [NSProcessInfo processInfo].processName, KVSCurrentBundleID(), hook,
          realValue ?: @"(null)", spoofedValue ?: @"(null)");
}

static NSString *KVSFormattedOperatingSystemVersionString(KVSConfiguration *configuration) {
    NSString *version = KVSVersionString(configuration);
    if (configuration.build.length > 0) {
        return [NSString stringWithFormat:@"Version %@ (Build %@)", version, configuration.build];
    }
    return [NSString stringWithFormat:@"Version %@", version];
}

%group KVSVersionHooks

%hook UIDevice
- (NSString *)systemVersion {
    KVSConfiguration *configuration = nil;
    if (!KVSShouldSpoof(&configuration)) {
        return %orig;
    }
    NSString *realVersion = %orig;
    NSString *spoofedVersion = KVSVersionString(configuration);
    KVSLog(@"UIDevice.systemVersion", realVersion, spoofedVersion, configuration);
    return spoofedVersion;
}
%end

%hook NSProcessInfo
- (NSOperatingSystemVersion)operatingSystemVersion {
    KVSConfiguration *configuration = nil;
    if (!KVSShouldSpoof(&configuration)) {
        return %orig;
    }
    NSOperatingSystemVersion realVersion = %orig;
    NSOperatingSystemVersion spoofedVersion = {
        .majorVersion = configuration.major,
        .minorVersion = configuration.minor,
        .patchVersion = configuration.patch
    };
    NSString *realString = [NSString stringWithFormat:@"%ld.%ld.%ld",
                            (long)realVersion.majorVersion, (long)realVersion.minorVersion,
                            (long)realVersion.patchVersion];
    KVSLog(@"NSProcessInfo.operatingSystemVersion", realString,
           KVSVersionString(configuration), configuration);
    return spoofedVersion;
}

- (NSString *)operatingSystemVersionString {
    KVSConfiguration *configuration = nil;
    if (!KVSShouldSpoof(&configuration)) {
        return %orig;
    }
    NSString *realVersion = %orig;
    NSString *spoofedVersion = KVSFormattedOperatingSystemVersionString(configuration);
    KVSLog(@"NSProcessInfo.operatingSystemVersionString", realVersion,
           spoofedVersion, configuration);
    return spoofedVersion;
}

- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version {
    KVSConfiguration *configuration = nil;
    if (!KVSShouldSpoof(&configuration)) {
        return %orig;
    }

    BOOL realResult = %orig;
    NSOperatingSystemVersion spoofedVersion = {
        .majorVersion = configuration.major,
        .minorVersion = configuration.minor,
        .patchVersion = configuration.patch
    };
    BOOL spoofedResult = spoofedVersion.majorVersion > version.majorVersion ||
        (spoofedVersion.majorVersion == version.majorVersion &&
         spoofedVersion.minorVersion > version.minorVersion) ||
        (spoofedVersion.majorVersion == version.majorVersion &&
         spoofedVersion.minorVersion == version.minorVersion &&
         spoofedVersion.patchVersion >= version.patchVersion);
    KVSLog(@"NSProcessInfo.isOperatingSystemAtLeastVersion:",
           [NSString stringWithFormat:@"%d", realResult],
           [NSString stringWithFormat:@"%d", spoofedResult], configuration);
    return spoofedResult;
}
%end

%end

%ctor {
    @autoreleasepool {
        if (!KVSIsApplicationProcess()) {
            return;
        }

        gKVSConfigurationLock = [NSLock new];
        KVSReloadConfiguration();

        KVSConfiguration *configuration = KVSCurrentConfiguration();
        if (configuration.debug) {
            NSOperatingSystemVersion realVersion = [NSProcessInfo processInfo].operatingSystemVersion;
            NSString *realString = [NSString stringWithFormat:@"%ld.%ld.%ld",
                                    (long)realVersion.majorVersion, (long)realVersion.minorVersion,
                                    (long)realVersion.patchVersion];
            NSLog(@"[KankaVersionSpoofer] injected process=%@ bundle=%@ real=%@ spoof=%@ mode=%@",
                  [NSProcessInfo processInfo].processName, KVSCurrentBundleID(), realString,
                  KVSVersionString(configuration), configuration.mode);
        }

        int notificationToken = 0;
        notify_register_dispatch(kKVSReloadNotification.UTF8String, &notificationToken,
                                 dispatch_get_global_queue(QOS_CLASS_UTILITY, 0),
                                 ^(int token) {
            (void)token;
            KVSReloadConfiguration();
            KVSConfiguration *reloaded = KVSCurrentConfiguration();
            if (reloaded.debug) {
                NSLog(@"[KankaVersionSpoofer] preferences reloaded process=%@ mode=%@ spoof=%@",
                      [NSProcessInfo processInfo].processName, reloaded.mode,
                      KVSVersionString(reloaded));
            }
        });

        %init(KVSVersionHooks);
    }
}