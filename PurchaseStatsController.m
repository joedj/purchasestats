#import "BBWeeAppController-Protocol.h"
#import "MSPullToRefreshController.h"
#import "PurchaseStatsFetcher.h"
#import "PurchaseStatsSettings.h"
#import "PurchaseStatsStore.h"

#define HEIGHT 71.f

#define BACKGROUND_X_INSET 2.f
#define BACKGROUND_Y_INSET 0.f

#define ICON_X_PADDING 2.f
#define ICON_X (BACKGROUND_X_INSET + ICON_X_PADDING)
#define ICON_Y 5.f
#define ICON_SIZE 60.f

#define LABEL_X_PADDING 2.f
#define LABEL_Y_PADDING 2.f
#define LABEL_X (ICON_X + ICON_SIZE + ICON_X_PADDING + LABEL_X_PADDING)
#define LABEL_WIDTH(parent_width) ((parent_width) - LABEL_X - BACKGROUND_X_INSET)
#define LABEL_HEIGHT ((HEIGHT - (LABEL_Y_PADDING * 2.f)) / 3.f)

@interface PurchaseStatsProductView: UIView
@property (nonatomic, readonly) PurchaseStatsProduct *product;
@end

@implementation PurchaseStatsProductView {
    UIImageView *_imageView;
    UILabel *_label1;
    UILabel *_label2;
    UILabel *_label3;
}

- (void)updateWithProduct:(PurchaseStatsProduct *)product {
    _product = product;
    _label1.text = product.name;
    NSString *delta = @"";
    if (product.direction.length && product.delta.length) {
        delta = [NSString stringWithFormat:@" (%@%@)", product.direction, product.delta];
    }
    _label2.text = [NSString stringWithFormat:@"%@%@", product.incomeRate, delta];
    _label2.textColor = [product.direction isEqualToString:@"+"] ? [UIColor greenColor] : [UIColor redColor];
    _label3.text = [NSString stringWithFormat:@"Sales: %@ Pending: %@", product.totalSales ?: @"?", product.pendingEarnings ?: @"?"];
    _imageView.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:product.iconDataURL]]];
}

- (void)_addLabel:(UILabel *)label {
    label.textAlignment = UITextAlignmentCenter;
    label.adjustsFontSizeToFitWidth = YES;
    label.textColor = UIColor.whiteColor;
    label.backgroundColor = UIColor.clearColor;
    [self addSubview:label];
}

- (id)initWithProduct:(PurchaseStatsProduct *)product width:(CGFloat)width {
    if ((self = [super initWithFrame:(CGRect){CGPointZero, {width, HEIGHT}}])) {

        UIView *background = [[UIView alloc] initWithFrame:CGRectInset(self.bounds, BACKGROUND_X_INSET, BACKGROUND_Y_INSET)];
        background.backgroundColor = UIColor.blackColor;
        background.opaque = NO;
        background.alpha = .3f;
        background.layer.cornerRadius = 5.f;
        background.layer.borderColor = background.backgroundColor.CGColor;
        background.layer.borderWidth = 1.f;
        [self addSubview:background];

        _imageView = [[UIImageView alloc] initWithFrame:(CGRect){{ICON_X, ICON_Y}, {ICON_SIZE, ICON_SIZE}}];
        [self addSubview:_imageView];

        _label1 = [[UILabel alloc] initWithFrame:(CGRect){{LABEL_X, LABEL_Y_PADDING + (LABEL_HEIGHT * 0.f)}, {LABEL_WIDTH(width), LABEL_HEIGHT}}];
        _label2 = [[UILabel alloc] initWithFrame:(CGRect){{LABEL_X, LABEL_Y_PADDING + (LABEL_HEIGHT * 1.f)}, {LABEL_WIDTH(width), LABEL_HEIGHT}}];
        _label3 = [[UILabel alloc] initWithFrame:(CGRect){{LABEL_X, LABEL_Y_PADDING + (LABEL_HEIGHT * 2.f)}, {LABEL_WIDTH(width), LABEL_HEIGHT}}];

        [self _addLabel:_label1];
        [self _addLabel:_label2];
        [self _addLabel:_label3];

        [self updateWithProduct:product];
    }
    return self;
}

@end

@interface PurchaseStatsController: NSObject <BBWeeAppController, PurchaseStatsFetcherDelegate, PurchaseStatsStoreDelegate, PurchaseStatsMSPullToRefreshDelegate>
@property (nonatomic) UIView *view;
@end

@implementation PurchaseStatsController {
    PurchaseStatsSettings *_settings;
    PurchaseStatsFetcher *_fetcher;
    PurchaseStatsStore *_store;
    UIView *_view;
    UIScrollView *_scrollView;
    PurchaseStatsMSPullToRefreshController *_pullToRefreshController;
    UIActivityIndicatorView *_activityView;
    NSMutableArray *_productViews;
    NSString *_lastProductURL;
}

- (id)init {
    if ((self = [super init])) {
        _fetcher = [[PurchaseStatsFetcher alloc] init];
        _fetcher.delegate = self;
    }
    return self;
}

- (void)reloadSettings {
    if (_store) {
        _settings = [[PurchaseStatsSettings alloc] init];
        _store.settings = _settings;
        _fetcher.settings = _settings;
    }
}

static void settings_changed(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [(__bridge PurchaseStatsController *)observer reloadSettings];
    });
}

- (void)addOrUpdateViewForProduct:(PurchaseStatsProduct *)product {
    BOOL viewExists = NO;
    PurchaseStatsProductView *productView = nil;
    for (productView in _productViews) {
        if (productView.product.productURL == product.productURL || [productView.product.productURL isEqual:product.productURL]) {
            viewExists = YES;
            [productView updateWithProduct:product];
            break;
        }
    }
    if (!viewExists) {
        productView = [[PurchaseStatsProductView alloc] initWithProduct:product width:_scrollView.frame.size.width];
        [_productViews addObject:productView];
        [_scrollView addSubview:productView];
        CGSize size = _scrollView.contentSize;
        CGRect frame = productView.frame;
        frame.origin.x = size.width;
        productView.frame = frame;
        size.width += frame.size.width;
        _scrollView.contentSize = size;
    }
}

- (PurchaseStatsProductView *)productViewAtLocation:(CGPoint)location {
    CGPoint contentOffset = _scrollView.contentOffset;
    CGPoint contentLocation = CGPointMake(contentOffset.x + location.x, contentOffset.y + location.y);
    UIView *view = [_scrollView hitTest:contentLocation withEvent:nil];
    while (view) {
        if ([view isKindOfClass:PurchaseStatsProductView.class]) {
            break;
        }
        view = view.superview;
    }
    return (PurchaseStatsProductView *)view;
}

- (void)sortProductViews {
    PurchaseStatsProductView *currentView = [self productViewAtLocation:CGPointZero];
    [_productViews sortUsingComparator:^(id v1, id v2) {
        return [[v2 product].pendingEarnings compare:[v1 product].pendingEarnings options:NSNumericSearch];
    }];
    NSUInteger offset = 0;
    for (PurchaseStatsProductView *productView in _productViews) {
        CGRect frame = productView.frame;
        if (productView == currentView) {
            CGPoint contentOffset = _scrollView.contentOffset;
            if (contentOffset.x >= 0) {
                contentOffset.x = offset + (contentOffset.x - frame.origin.x);
                _scrollView.contentOffset = contentOffset;
            }
        }
        frame.origin.x = offset;
        productView.frame = frame;
        offset += frame.size.width;
    }
}

- (NSURL *)launchURLForTapLocation:(CGPoint)tapLocation {
    PurchaseStatsProductView *view = [self productViewAtLocation:tapLocation];
    NSURL *url = nil;
    if (view) {
        url = [NSURL URLWithString:view.product.productURL ?: PRODUCTS_URL];
    }
    return url;
}

- (void)purchaseStatsStore:(PurchaseStatsStore *)store updatedProduct:(PurchaseStatsProduct *)product {
    [self addOrUpdateViewForProduct:product];
    [self sortProductViews];
}

- (void)finishedRefresh {
    [_activityView stopAnimating];
    _activityView.color = UIColor.grayColor;
    [_pullToRefreshController finishRefreshingDirection:MSRefreshDirectionLeft animated:YES];
}

- (void)purchaseStatsFetcherStarted:(PurchaseStatsFetcher *)fetcher {
    _activityView.color = UIColor.whiteColor;
    [_activityView startAnimating];
}

- (void)purchaseStatsFetcherFinished:(PurchaseStatsFetcher *)fetcher {
    [self finishedRefresh];
}

- (void)purchaseStatsFetcher:(PurchaseStatsFetcher *)fetcher failed:(id)reason {
    [self finishedRefresh];
}

- (void)purchaseStatsFetcher:(PurchaseStatsFetcher *)fetcher gotProductDictionary:(NSDictionary *)productDict {
    [_store updateProductWithDictionary:productDict];
}

- (void)loadPlaceholderView {
    _view = [[UIView alloc] initWithFrame:(CGRect){CGPointZero, {0, HEIGHT}}];
}

- (void)loadFullView {
    _store = [[PurchaseStatsStore alloc] init];
    _store.delegate = self;

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self, &settings_changed, (__bridge CFStringRef)SETTINGS_DOMAIN, NULL, 0);
    [self reloadSettings];

    _scrollView = [[UIScrollView alloc] initWithFrame:_view.bounds];
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.pagingEnabled = YES;
    _scrollView.alwaysBounceHorizontal = YES;
    CGSize contentSize = _scrollView.contentSize;
    contentSize.height = _scrollView.frame.size.height;
    _scrollView.contentSize = contentSize;
    [_view addSubview:_scrollView];

    _productViews = [[NSMutableArray alloc] init];
    for (PurchaseStatsProduct *product in _store.visibleProducts) {
        [self addOrUpdateViewForProduct:product];
    }
    [self sortProductViews];

    CGPoint contentOffset = CGPointZero;
    if (_lastProductURL) {
        CGFloat x = 0.f;
        for (PurchaseStatsProductView *productView in _productViews) {
            if ([productView.product.productURL isEqualToString:_lastProductURL]) {
                contentOffset.x = x;
                break;
            }
            x += productView.frame.size.width;
        }
    }
    _scrollView.contentOffset = contentOffset;

    _activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _activityView.frame = CGRectMake(-_scrollView.frame.size.height, 0, _scrollView.frame.size.height, _scrollView.frame.size.height);
    _activityView.hidesWhenStopped = NO;
    _activityView.color = UIColor.grayColor;
    [_scrollView addSubview:_activityView];

    _pullToRefreshController = [[PurchaseStatsMSPullToRefreshController alloc] initWithScrollView:_scrollView delegate:self];

    if (_settings.autoRefresh) {
        [_fetcher autoFetch];
    }
}

- (void)unloadView {
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)self, (__bridge CFStringRef)SETTINGS_DOMAIN, NULL);
    _settings = nil;

    [_fetcher stop];
    [_fetcher cancelAutoFetchTimer];

    [_store save];
    _store.delegate = nil;
    _store = nil;

    PurchaseStatsProductView *productView = [self productViewAtLocation:CGPointZero];
    if (productView) {
        _lastProductURL = productView.product.productURL;
    }

    _view = nil;
    _productViews = nil;
    _pullToRefreshController = nil;
    _activityView = nil;
    _scrollView = nil;
}

- (void)dealloc {
    _fetcher.delegate = nil;
    [self unloadView];
}

- (float)viewHeight {
    return HEIGHT;
}

- (BOOL)pullToRefreshController:(PurchaseStatsMSPullToRefreshController *)controller canRefreshInDirection:(MSRefreshDirection)direction {
    return direction == MSRefreshDirectionLeft;
}

- (CGFloat)pullToRefreshController:(PurchaseStatsMSPullToRefreshController *)controller refreshableInsetForDirection:(MSRefreshDirection)direction {
    return _activityView.frame.size.width + 5;
}

- (CGFloat)pullToRefreshController:(PurchaseStatsMSPullToRefreshController *)controller refreshingInsetForDirection:(MSRefreshDirection)direction {
    return _activityView.frame.size.width;
}

- (void)pullToRefreshController:(PurchaseStatsMSPullToRefreshController *)controller canEngageRefreshDirection:(MSRefreshDirection)direction {
    _scrollView.pagingEnabled = NO;
    _activityView.color = UIColor.whiteColor;
}

- (void)pullToRefreshController:(PurchaseStatsMSPullToRefreshController *)controller didDisengageRefreshDirection:(MSRefreshDirection)direction {
    _scrollView.pagingEnabled = YES;
    _activityView.color = UIColor.grayColor;
}

- (void)pullToRefreshController:(PurchaseStatsMSPullToRefreshController *)controller didEngageRefreshDirection:(MSRefreshDirection)direction {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        _scrollView.pagingEnabled = YES;
    });
    [_fetcher fetch];
}

@end
