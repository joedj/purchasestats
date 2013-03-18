#define SETTINGS_DOMAIN @"net.joedj.purchasestats"
#define SETTINGS_KEY_USERNAME @"username"
#define SETTINGS_KEY_PASSWORD @"password"
#define SETTINGS_KEY_AUTOREFRESH @"autoRefresh"

@interface PurchaseStatsSettings: NSObject
@property (nonatomic, readonly) BOOL isConfigured;
@property (nonatomic, readonly) NSString *username;
@property (nonatomic, readonly) NSString *password;
@property (nonatomic, readonly) BOOL autoRefresh;
- (BOOL)isProductVisible:(NSString *)productURL;
@end
