#import "MSPullToRefreshController.h"
#import "PurchaseStatsStore.h"

#define HEIGHT 71.f

@protocol PurchaseStatsViewDelegate;

@interface PurchaseStatsView: UIView <PurchaseStatsMSPullToRefreshDelegate>
@property (nonatomic, weak) id<PurchaseStatsViewDelegate> delegate;
- (void)scheduleFullViewLoad;
- (NSURL *)productURLAtLocation:(CGPoint)location;
- (void)addOrUpdateViewForProduct:(PurchaseStatsProduct *)product;
- (void)sortProductViews;
- (void)showProduct:(NSString *)productURL;
- (void)startRefreshAnimation;
- (void)stopRefreshAnimation:(BOOL)win;
@end

@protocol PurchaseStatsViewDelegate
- (void)purchaseStatsViewReady:(PurchaseStatsView *)view;
- (void)purchaseStatsViewRefreshed:(PurchaseStatsView *)view;
@end
