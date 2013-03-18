#import "PurchaseStatsSettings.h"

#define STORE_PLIST [[NSString stringWithFormat:@"~/Library/Preferences/%@.cache.plist", SETTINGS_DOMAIN] stringByExpandingTildeInPath]

@interface PurchaseStatsProduct: NSObject
@property (nonatomic, readonly) NSString *productURL;
@property (nonatomic, readonly) NSString *iconDataURL;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *incomeRate;
@property (nonatomic, readonly) NSString *delta;
@property (nonatomic, readonly) NSString *direction;
@property (nonatomic, readonly) NSString *totalSales;
@property (nonatomic, readonly) NSString *pendingEarnings;
@property (nonatomic) BOOL dirty;
@end

@protocol PurchaseStatsStoreDelegate;

@interface PurchaseStatsStore: NSObject
@property (nonatomic, weak) id<PurchaseStatsStoreDelegate> delegate;
@property (nonatomic, readonly) NSArray *allProducts;
@property (nonatomic, readonly) NSArray *visibleProducts;
- (void)setSettings:(PurchaseStatsSettings *)settings;
- (void)updateProductWithDictionary:(NSDictionary *)productDict;
- (void)save;
@end

@protocol PurchaseStatsStoreDelegate
- (void)purchaseStatsStore:(PurchaseStatsStore *)store updatedProduct:(PurchaseStatsProduct *)product;
@end
