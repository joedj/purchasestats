#import "PurchaseStatsSettings.h"

@implementation PurchaseStatsSettings {
    NSDictionary *_dictionary;
}

- (id)init {
    if ((self = [super init])) {
        _dictionary = [[NSDictionary alloc] initWithContentsOfFile:[[NSString stringWithFormat:@"~/Library/Preferences/%@.plist", SETTINGS_DOMAIN] stringByExpandingTildeInPath]];
    }
    return self;
}

- (NSString *)username {
    return _dictionary[SETTINGS_KEY_USERNAME];
}

- (NSString *)password {
    return _dictionary[SETTINGS_KEY_PASSWORD];
}

- (BOOL)autoRefresh {
    return [_dictionary[SETTINGS_KEY_AUTOREFRESH] boolValue];
}

- (BOOL)isConfigured {
    return self.username.length && self.password.length;
}

- (BOOL)isProductVisible:(NSString *)productURL {
    return [(_dictionary[productURL] ?: @YES) boolValue];
}

@end
