#import "PurchaseStatsSettings.h"

#define PRODUCTS_URL @"https://cydia.saurik.com/connect/products/"

@protocol PurchaseStatsFetcherDelegate;

@interface PurchaseStatsFetcher: NSObject <UIWebViewDelegate>
@property (nonatomic, weak) id<PurchaseStatsFetcherDelegate> delegate;
- (void)setSettings:(PurchaseStatsSettings *)settings;
- (void)fetch;
- (void)autoFetch;
- (void)cancelAutoFetchTimer;
- (void)stop;
@end

@protocol PurchaseStatsFetcherDelegate
- (void)purchaseStatsFetcherStarted:(PurchaseStatsFetcher *)fetcher;
- (void)purchaseStatsFetcherFinished:(PurchaseStatsFetcher *)fetcher;
- (void)purchaseStatsFetcher:(PurchaseStatsFetcher *)fetcher gotProductDictionary:(NSDictionary *)d;
- (void)purchaseStatsFetcher:(PurchaseStatsFetcher *)fetcher failed:(id)reason;
@end
