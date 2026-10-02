#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>

static NSString *const kYusufSpooferPreferencesDomain = @"com.yusufspoofer";
static NSString *const kYusufSpooferReloadNotification = @"com.yusufspoofer/prefsChanged";

@interface YusufSpooferListController : PSListController
@end

@implementation YusufSpooferListController

- (id)specifiers {
    if (_specifiers == nil) {
        NSMutableArray *specs = [NSMutableArray array];

        PSSpecifier *enabled = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
                                                            target:self
                                                               set:@selector(setPreferenceValue:forSpecifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSSwitchCell
                                                              edit:nil];
        [enabled setProperty:@YES forKey:@"default"]; 
        [enabled setProperty:kYusufSpooferPreferencesDomain forKey:@"defaults"];
        [enabled setProperty:@"Enabled" forKey:@"key"];
        [specs addObject:enabled];

        PSSpecifier *mode = [PSSpecifier preferenceSpecifierNamed:@"Mode"
                                                            target:self
                                                               set:@selector(setPreferenceValue:forSpecifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSLinkListCell
                                                              edit:nil];
        [mode setProperty:kYusufSpooferPreferencesDomain forKey:@"defaults"];
        [mode setProperty:@"Mode" forKey:@"key"];
        [mode setProperty:@[@"appstore", @"all", @"selected"] forKey:@"values"];
        [mode setProperty:@[@"App Store", @"All", @"Selected"] forKey:@"titles"];
        [mode setProperty:@"appstore" forKey:@"default"];
        [specs addObject:mode];

        PSSpecifier *major = [PSSpecifier preferenceSpecifierNamed:@"Major"
                                                            target:self
                                                               set:@selector(setPreferenceValue:forSpecifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSTextFieldCell
                                                              edit:nil];
        [major setProperty:@"Major" forKey:@"key"];
        [major setProperty:kYusufSpooferPreferencesDomain forKey:@"defaults"];
        [major setProperty:@(17) forKey:@"default"];
        [specs addObject:major];

        PSSpecifier *minor = [PSSpecifier preferenceSpecifierNamed:@"Minor"
                                                            target:self
                                                               set:@selector(setPreferenceValue:forSpecifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSTextFieldCell
                                                              edit:nil];
        [minor setProperty:@"Minor" forKey:@"key"];
        [minor setProperty:kYusufSpooferPreferencesDomain forKey:@"defaults"];
        [minor setProperty:@(7) forKey:@"default"];
        [specs addObject:minor];

        PSSpecifier *patch = [PSSpecifier preferenceSpecifierNamed:@"Patch"
                                                            target:self
                                                               set:@selector(setPreferenceValue:forSpecifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSTextFieldCell
                                                              edit:nil];
        [patch setProperty:@"Patch" forKey:@"key"];
        [patch setProperty:kYusufSpooferPreferencesDomain forKey:@"defaults"];
        [patch setProperty:@(0) forKey:@"default"];
        [specs addObject:patch];

        PSSpecifier *build = [PSSpecifier preferenceSpecifierNamed:@"Build"
                                                            target:self
                                                               set:@selector(setPreferenceValue:forSpecifier:)
                                                               get:@selector(readPreferenceValue:)
                                                            detail:nil
                                                              cell:PSTextFieldCell
                                                              edit:nil];
        [build setProperty:@"Build" forKey:@"key"];
        [build setProperty:kYusufSpooferPreferencesDomain forKey:@"defaults"];
        [build setProperty:@"" forKey:@"default"];
        [specs addObject:build];

        PSSpecifier *save = [PSSpecifier preferenceSpecifierNamed:@"Confirm"
                                                            target:self
                                                               set:nil
                                                               get:nil
                                                            detail:nil
                                                              cell:PSButtonCell
                                                              edit:nil];
        [save setProperty:@selector(applySpoof) forKey:@"action"];
        [specs addObject:save];

        _specifiers = specs;
    }
    return _specifiers;
}

- (void)applySpoof {
    CFPreferencesAppSynchronize((CFStringRef)kYusufSpooferPreferencesDomain);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kYusufSpooferReloadNotification,
                                         NULL, NULL,
                                         TRUE);
    system("killall -9 SpringBoard");
    [self.navigationController popViewControllerAnimated:YES];
}

@end
