#define SETTINGS_DOMAIN @"net.joedj.purchasestats"
#define SETTINGS_KEY_USERNAME @"username"
#define SETTINGS_KEY_PASSWORD @"password"
#define SETTINGS_KEY_AUTOREFRESH @"autoRefresh"
#define SETTINGS_KEY_AUTH_PROVIDER @"authProvider"

typedef enum {
    PurchaseStatsAuthProviderGoogle, PurchaseStatsAuthProviderFacebook
} PurchaseStatsAuthProvider;

@interface PurchaseStatsSettings: NSObject
@property (nonatomic, readonly) BOOL isConfigured;
@property (nonatomic, readonly) NSString *username;
@property (nonatomic, readonly) NSString *password;
@property (nonatomic, readonly) BOOL autoRefresh;
@property (nonatomic, readonly) PurchaseStatsAuthProvider authProvider;
- (BOOL)isProductVisible:(NSString *)productURL;
@end
