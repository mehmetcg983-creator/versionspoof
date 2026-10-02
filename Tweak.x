#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>
#import <math.h>

static CFStringRef const kYFSPreferencesDomain = CFSTR("com.yusufspoofer");
static NSString *const kYFSReloadNotification = @"com.yusufspoofer/prefsChanged";
static NSString *const kYFSAppStoreBundleID = @"com.apple.AppStore";

@interface YFSConfiguration : NSObject
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL debug;
@property (nonatomic) NSInteger major;
@property (nonatomic) NSInteger minor;
@property (nonatomic) NSInteger patch;
@property (nonatomic, copy) NSString *build;
@property (nonatomic, copy) NSString *mode;
@property (nonatomic, copy) NSArray<NSString *> *selectedBundleIDs;
@end

@implementation YFSConfiguration
@end

static NSLock *gYFSConfigurationLock;
static YFSConfiguration *gYFSConfiguration;

static NSString *YFSVersionString(YFSConfiguration *configuration) {
    return [NSString stringWithFormat:@"%ld.%ld.%ld",
            (long)configuration.major, (long)configuration.minor, (long)configuration.patch];
}

static BOOL YFSReadInteger(NSDictionary *preferences, NSString *key, NSInteger *result) {
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

static YFSConfiguration *YFSReadConfiguration(void) {
    CFPreferencesAppSynchronize(kYFSPreferencesDomain);
    CFDictionaryRef copiedPreferences = CFPreferencesCopyMultiple(
        NULL, kYFSPreferencesDomain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    NSDictionary *preferences = copiedPreferences ? CFBridgingRelease(copiedPreferences) : @{};

    YFSConfiguration *configuration = [YFSConfiguration new];
    configuration.enabled = YES;
    configuration.debug = NO;
    configuration.major = 17;
    configuration.minor = 7;
    configuration.patch = 0;
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
    BOOL validVersion = YFSReadInteger(preferences, @"Major", &major) && major > 0 &&
                        YFSReadInteger(preferences, @"Minor", &minor) &&
                        YFSReadInteger(preferences, @"Patch", &patch);
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

static void YFSReloadConfiguration(void) {
    YFSConfiguration *configuration = YFSReadConfiguration();
    [gYFSConfigurationLock lock];
    gYFSConfiguration = configuration;
    [gYFSConfigurationLock unlock];
}

static YFSConfiguration *YFSCurrentConfiguration(void) {
    [gYFSConfigurationLock lock];
    YFSConfiguration *configuration = gYFSConfiguration;
    [gYFSConfigurationLock unlock];
    return configuration;
}

static NSString *YFSCurrentBundleID(void) {
    return [NSBundle mainBundle].bundleIdentifier ?: @"";
}

static BOOL YFSIsApplicationProcess(void) {
    NSString *bundleID = YFSCurrentBundleID();
    NSString *processName = [NSProcessInfo processInfo].processName;
    if (bundleID.length == 0 || [bundleID isEqualToString:@"com.apple.springboard"] ||
        [processName isEqualToString:@"SpringBoard"] || [processName isEqualToString:@"launchd"]) {
        return NO;
    }

    NSString *extension = [NSBundle mainBundle].bundleURL.pathExtension.lowercaseString;
    return [extension isEqualToString:@"app"] || [extension isEqualToString:@"appex"];
}

static BOOL YFSShouldSpoof(YFSConfiguration **currentConfiguration) {
    YFSConfiguration *configuration = YFSCurrentConfiguration();
    if (currentConfiguration) {
        *currentConfiguration = configuration;
    }
    if (!configuration.enabled) {
        return NO;
    }

    NSString *bundleID = YFSCurrentBundleID();
    if ([configuration.mode isEqualToString:@"all"]) {
        return YES;
    }
    if ([configuration.mode isEqualToString:@"selected"]) {
        return [configuration.selectedBundleIDs containsObject:bundleID];
    }
    return [bundleID isEqualToString:kYFSAppStoreBundleID];
}

static void YFSLog(NSString *hook, NSString *realValue, NSString *spoofedValue,
                  YFSConfiguration *configuration) {
    if (!configuration.debug) {
        return;
    }
    NSLog(@"[YusufSpoofer] process=%@ bundle=%@ hook=%@ real=%@ spoof=%@",
          [NSProcessInfo processInfo].processName, YFSCurrentBundleID(), hook,
          realValue ?: @"(null)", spoofedValue ?: @"(null)");
}

static NSString *YFSFormattedOperatingSystemVersionString(YFSConfiguration *configuration) {
    NSString *version = YFSVersionString(configuration);
    if (configuration.build.length > 0) {
        return [NSString stringWithFormat:@"Version %@ (Build %@)", version, configuration.build];
    }
    return [NSString stringWithFormat:@"Version %@", version];
}

%group YFSVersionHooks

%hook UIDevice
- (NSString *)systemVersion {
    YFSConfiguration *configuration = nil;
    if (!YFSShouldSpoof(&configuration)) {
        return %orig;
    }
    NSString *realVersion = %orig;
    NSString *spoofedVersion = YFSVersionString(configuration);
    YFSLog(@"UIDevice.systemVersion", realVersion, spoofedVersion, configuration);
    return spoofedVersion;
}
%end

%hook NSProcessInfo
- (NSOperatingSystemVersion)operatingSystemVersion {
    YFSConfiguration *configuration = nil;
    if (!YFSShouldSpoof(&configuration)) {
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
    YFSLog(@"NSProcessInfo.operatingSystemVersion", realString,
           YFSVersionString(configuration), configuration);
    return spoofedVersion;
}

- (NSString *)operatingSystemVersionString {
    YFSConfiguration *configuration = nil;
    if (!YFSShouldSpoof(&configuration)) {
        return %orig;
    }
    NSString *realVersion = %orig;
    NSString *spoofedVersion = YFSFormattedOperatingSystemVersionString(configuration);
    YFSLog(@"NSProcessInfo.operatingSystemVersionString", realVersion,
           spoofedVersion, configuration);
    return spoofedVersion;
}

- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version {
    YFSConfiguration *configuration = nil;
    if (!YFSShouldSpoof(&configuration)) {
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
    YFSLog(@"NSProcessInfo.isOperatingSystemAtLeastVersion:",
           [NSString stringWithFormat:@"%d", realResult],
           [NSString stringWithFormat:@"%d", spoofedResult], configuration);
    return spoofedResult;
}
%end

%end

%ctor {
    @autoreleasepool {
        if (!YFSIsApplicationProcess()) {
            return;
        }

        gYFSConfigurationLock = [NSLock new];
        YFSReloadConfiguration();

        YFSConfiguration *configuration = YFSCurrentConfiguration();
        if (configuration.debug) {
            NSOperatingSystemVersion realVersion = [NSProcessInfo processInfo].operatingSystemVersion;
            NSString *realString = [NSString stringWithFormat:@"%ld.%ld.%ld",
                                    (long)realVersion.majorVersion, (long)realVersion.minorVersion,
                                    (long)realVersion.patchVersion];
            NSLog(@"[YusufSpoofer] injected process=%@ bundle=%@ real=%@ spoof=%@ mode=%@",
                  [NSProcessInfo processInfo].processName, YFSCurrentBundleID(), realString,
                  YFSVersionString(configuration), configuration.mode);
        }

        int notificationToken = 0;
        notify_register_dispatch(kYFSReloadNotification.UTF8String, &notificationToken,
                                 dispatch_get_global_queue(QOS_CLASS_UTILITY, 0),
                                 ^(int token) {
            (void)token;
            YFSReloadConfiguration();
            YFSConfiguration *reloaded = YFSCurrentConfiguration();
            if (reloaded.debug) {
                NSLog(@"[YusufSpoofer] preferences reloaded process=%@ mode=%@ spoof=%@",
                      [NSProcessInfo processInfo].processName, reloaded.mode,
                      YFSVersionString(reloaded));
            }
        });

        %init(YFSVersionHooks);
    }
}