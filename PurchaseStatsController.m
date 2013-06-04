#import "BBWeeAppController-Protocol.h"
#import "PurchaseStatsFetcher.h"
#import "PurchaseStatsView.h"

@interface PurchaseStatsController: NSObject <BBWeeAppController,
                                              PurchaseStatsViewDelegate,
                                              PurchaseStatsFetcherDelegate,
                                              PurchaseStatsStoreDelegate>
@property (nonatomic, readonly) UIView *view;
@end

@implementation PurchaseStatsController {
    PurchaseStatsView *_view;
    PurchaseStatsFetcher *_fetcher;
    PurchaseStatsStore *_store;
    NSString *_lastProductURL;
}

- (id)init {
    if ((self = [super init])) {
        _fetcher = [[PurchaseStatsFetcher alloc] init];
        _fetcher.delegate = self;
    }
    return self;
}

- (void)dealloc {
    [self unloadView];
}

- (void)loadPlaceholderView {
    _view = [[PurchaseStatsView alloc] initWithFrame:CGRectMake(0, 0, 0, HEIGHT)];
    _view.delegate = self;
}

- (void)loadFullView {
    [_view scheduleFullViewLoad];
}

- (void)unloadView {
    [_fetcher stop];
    [_fetcher cancelAutoFetchTimer];
    _fetcher.settings = nil;

    _store.delegate = nil;
    [_store save];
    _store = nil;

    _lastProductURL = [_view productURLAtLocation:CGPointZero].absoluteString;

    _view.delegate = nil;
    _view = nil;
}

- (float)viewHeight {
    return HEIGHT;
}

- (NSURL *)launchURLForTapLocation:(CGPoint)tapLocation {
    return [_view productURLAtLocation:tapLocation];
}

- (void)purchaseStatsViewReady:(PurchaseStatsView *)view {
    PurchaseStatsSettings *settings = [[PurchaseStatsSettings alloc] init];
    _store = [[PurchaseStatsStore alloc] init];
    _store.delegate = self;
    _store.settings = settings;
    _fetcher.settings = settings;

    for (PurchaseStatsProduct *product in _store.visibleProducts) {
        [view addOrUpdateViewForProduct:product];
    }
    [view sortProductViews];

    if (_lastProductURL) {
        [view showProduct:_lastProductURL];
    }

    if (settings.autoRefresh) {
        [_fetcher autoFetch];
    }
}

- (void)purchaseStatsViewRefreshed:(PurchaseStatsView *)view {
    [_fetcher fetch];
}

- (void)purchaseStatsFetcherStarted:(PurchaseStatsFetcher *)fetcher {
    [_view startRefreshAnimation];
}

- (void)purchaseStatsFetcherFinished:(PurchaseStatsFetcher *)fetcher {
    [_view stopRefreshAnimation:YES];
}

- (void)purchaseStatsFetcher:(PurchaseStatsFetcher *)fetcher failed:(id)reason {
    [_view stopRefreshAnimation:NO];
}

- (void)purchaseStatsFetcher:(PurchaseStatsFetcher *)fetcher gotProductDictionary:(NSDictionary *)productDict {
    [_store updateProductWithDictionary:productDict];
}

- (void)purchaseStatsStore:(PurchaseStatsStore *)store updatedProduct:(PurchaseStatsProduct *)product {
    [_view addOrUpdateViewForProduct:product];
    [_view sortProductViews];
}

@end
