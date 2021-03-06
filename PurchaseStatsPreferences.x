#import <Preferences/Preferences.h>

#import "PurchaseStatsStore.h"

@interface PurchaseStatsProductCell: PSControlTableCell
@end

@interface PurchaseStatsSettingsController: PSListController
@end

@implementation PurchaseStatsSettingsController

- (NSArray *)specifiers {
    NSMutableArray *specs = (NSMutableArray *)self->_specifiers;
    if (!specs) {
        specs = [[NSMutableArray alloc] init];

        PSSpecifier *autoRefresh = [PSSpecifier preferenceSpecifierNamed:@"Refresh Automatically" target:self
            set:@selector(setPreferenceValue:specifier:)
            get:@selector(readPreferenceValue:)
            detail:nil cell:PSSwitchCell edit:nil];
        [autoRefresh setProperty:SETTINGS_DOMAIN forKey:@"defaults"];
        [autoRefresh setProperty:SETTINGS_KEY_AUTOREFRESH forKey:@"key"];
        [specs addObject:autoRefresh];

        [specs addObject:PSSpecifier.emptyGroupSpecifier];

        PSSpecifier *authProvider = [PSSpecifier preferenceSpecifierNamed:@"Auth Provider" target:self
                set:@selector(setPreferenceValue:specifier:)
                get:@selector(readPreferenceValue:)
                detail:PSListItemsController.class cell:PSLinkListCell edit:nil];
        [authProvider setProperty:SETTINGS_DOMAIN forKey:@"defaults"];
        [authProvider setProperty:SETTINGS_KEY_AUTH_PROVIDER forKey:@"key"];
        [authProvider setProperty:@"Google" forKey:@"default"];
        NSArray *authProviderValues = @[@"Google", @"Facebook"];
        [authProvider setValues:authProviderValues titles:authProviderValues];
        [specs addObject:authProvider];

        PSSpecifier *username = [PSSpecifier preferenceSpecifierNamed:@"Username" target:self
                set:@selector(setPreferenceValue:specifier:)
                get:@selector(readPreferenceValue:)
                detail:nil cell:PSEditTextCell edit:nil];
        [username setKeyboardType:UIKeyboardTypeEmailAddress autoCaps:UITextAutocapitalizationTypeNone autoCorrection:UITextAutocorrectionTypeDefault];
        [username setProperty:SETTINGS_DOMAIN forKey:@"defaults"];
        [username setProperty:SETTINGS_KEY_USERNAME forKey:@"key"];
        [username setProperty:@"username" forKey:@"prompt"];
        [specs addObject:username];

        PSSpecifier *password = [PSSpecifier preferenceSpecifierNamed:@"Password" target:self
                set:@selector(setPreferenceValue:specifier:)
                get:@selector(readPreferenceValue:)
                detail:nil cell:PSSecureEditTextCell edit:nil];
        [password setProperty:SETTINGS_DOMAIN forKey:@"defaults"];
        [password setProperty:SETTINGS_KEY_PASSWORD forKey:@"key"];
        [password setProperty:@"password" forKey:@"prompt"];
        [specs addObject:password];

        PurchaseStatsStore *store = [[PurchaseStatsStore alloc] init];
        NSMutableArray *products = [NSMutableArray arrayWithArray:store.allProducts];
        [products sortUsingComparator:^(PurchaseStatsProduct *p1, PurchaseStatsProduct *p2) {
            return [p1.name localizedCaseInsensitiveCompare:p2.name];
        }];
        if (products.count) {
            [specs addObject:PSSpecifier.emptyGroupSpecifier];
            for (PurchaseStatsProduct *product in products) {
                PSSpecifier *productSpecifier = [PSSpecifier preferenceSpecifierNamed:product.name target:self
                        set:@selector(setPreferenceValue:specifier:)
                        get:@selector(readPreferenceValue:)
                        detail:nil cell:PSSwitchCell edit:nil];
                [productSpecifier setProperty:SETTINGS_DOMAIN forKey:@"defaults"];
                [productSpecifier setProperty:product.productURL forKey:@"key"];
                [productSpecifier setProperty:@YES forKey:@"default"];
                if (%c(PurchaseStatsProductCell)) {
                    [productSpecifier setProperty:%c(PurchaseStatsProductCell) forKey:@"cellClass"];
                }
                UIImage *icon = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:product.iconDataURL]]];
                if (icon) {
                    [productSpecifier setProperty:icon forKey:@"iconImage"];
                }
                [specs addObject:productSpecifier];
            }
        }

        self->_specifiers = specs;
    }
    return self->_specifiers;
}

@end

static UITableViewCell *setupProductCell(UITableViewCell *self) {
    self.textLabel.adjustsFontSizeToFitWidth = YES;
    return self;
}

%group PSSwitchTableCell // iOS6
%subclass PurchaseStatsProductCell: PSSwitchTableCell
- (id)initWithStyle:(int)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
    return setupProductCell(%orig(style, nil, specifier));
}
%end
%end

%group PSControlTableCell // iOS5
%subclass PurchaseStatsProductCell: PSControlTableCell
- (id)initWithStyle:(int)style reuseIdentifier:(NSString *)identifier specifier:(PSSpecifier *)specifier {
    return setupProductCell(%orig(style, nil, specifier));
}
%end
%end

%ctor {
    if (%c(PSSwitchTableCell)) {
        %init(PSSwitchTableCell);
    } else if (%c(PSControlTableCell)) {
        %init(PSControlTableCell);
    }
}
