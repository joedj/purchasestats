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

@interface UIImage ()
+ (UIImage *)imageNamed:(NSString *)name inBundle:(NSBundle *)bundle;
@end

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
    _label1.text = product.name ?: @"Unknown";
    NSString *delta = @"(Swipe right to refresh)";
    if (product.direction.length && product.delta.length) {
        delta = [NSString stringWithFormat:@" (%@%@)", product.direction, product.delta];
    }
    _label2.text = [NSString stringWithFormat:@"%@%@", product.incomeRate ?: @"", delta];
    _label2.textColor = [product.direction isEqualToString:@"+"] ? [UIColor greenColor] : [UIColor redColor];
    _label3.text = [NSString stringWithFormat:@"Sales: %@ Pending: %@", product.totalSales ?: @"?", product.pendingEarnings ?: @"?"];
    _imageView.image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:product.iconDataURL]]];
    if (!_imageView.image) {
        _imageView.image = [UIImage imageNamed:@"PurchaseStats" inBundle:[NSBundle bundleForClass:[self class]]];
    }
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

@protocol PurchaseStatsViewDelegate;

@interface PurchaseStatsView: UIView <PurchaseStatsMSPullToRefreshDelegate>
@property (nonatomic, weak) id<PurchaseStatsViewDelegate> delegate;
@end

@protocol PurchaseStatsViewDelegate
- (void)purchaseStatsViewReady:(PurchaseStatsView *)view;
- (void)refreshPurchaseStats;
@end

@implementation PurchaseStatsView {
    BOOL _needsFullViewLoad;
    UIScrollView *_scrollView;
    UIActivityIndicatorView *_activityView;
    NSMutableArray *_productViews;
    PurchaseStatsMSPullToRefreshController *_pullToRefreshController;
}

- (void)loadFullView {
    _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.pagingEnabled = YES;
    _scrollView.alwaysBounceHorizontal = YES;
    CGSize contentSize = _scrollView.contentSize;
    contentSize.height = _scrollView.frame.size.height;
    _scrollView.contentSize = contentSize;
    [self addSubview:_scrollView];

    _pullToRefreshController = [[PurchaseStatsMSPullToRefreshController alloc] initWithScrollView:_scrollView delegate:self];

    _activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _activityView.frame = CGRectMake(-contentSize.height, 0, contentSize.height, contentSize.height);
    _activityView.hidesWhenStopped = NO;
    _activityView.color = UIColor.grayColor;
    [_scrollView addSubview:_activityView];

    _productViews = [[NSMutableArray alloc] init];

    [_delegate purchaseStatsViewReady:self];
}

- (void)scheduleFullViewLoad {
    if (self.frame.size.width > 0.f) {
        [self loadFullView];
    } else {
        _needsFullViewLoad = YES;
    }
}

- (void)layoutSubviews {
    if (_needsFullViewLoad && self.frame.size.width > 0.f) {
        _needsFullViewLoad = NO;
        [self loadFullView];
    }
    [super layoutSubviews];
}

- (PurchaseStatsProductView *)productViewAtLocation:(CGPoint)location {
    CGPoint contentOffset = _scrollView.contentOffset;
    CGPoint contentLocation = CGPointMake(contentOffset.x + location.x, contentOffset.y + location.y);
    UIView *view = [_scrollView hitTest:contentLocation withEvent:nil];
    while (view && ![view isKindOfClass:PurchaseStatsProductView.class]) {
        view = view.superview;
    }
    return (PurchaseStatsProductView *)view;
}

- (void)addOrUpdateViewForProduct:(PurchaseStatsProduct *)product {
    BOOL viewExists = NO;
    PurchaseStatsProductView *productView = nil;
    for (productView in _productViews) {
        if (productView.product.productURL == product.productURL || [productView.product.productURL isEqualToString:product.productURL]) {
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

- (void)showProduct:(NSString *)productURL {
    CGPoint contentOffset = CGPointZero;
    if (productURL) {
        CGFloat x = 0.f;
        for (PurchaseStatsProductView *productView in _productViews) {
            if ([productView.product.productURL isEqualToString:productURL]) {
                contentOffset.x = x;
                break;
            }
            x += productView.frame.size.width;
        }
    }
    _scrollView.contentOffset = contentOffset;
}

- (void)startRefreshAnimation {
    _activityView.color = UIColor.whiteColor;
    [_activityView startAnimating];
}

- (void)stopRefreshAnimation:(BOOL)win {
    [_pullToRefreshController finishRefreshingDirection:MSRefreshDirectionLeft animated:YES];
    [_activityView stopAnimating];
    _activityView.color = win ? UIColor.grayColor : UIColor.redColor;
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
    __weak UIScrollView *scrollView = _scrollView;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        scrollView.pagingEnabled = YES;
    });
    [_delegate refreshPurchaseStats];
}

@end

@interface PurchaseStatsController: NSObject <BBWeeAppController,
                                              PurchaseStatsViewDelegate,
                                              PurchaseStatsFetcherDelegate,
                                              PurchaseStatsStoreDelegate>
@property (nonatomic, readonly) UIView *view;
@end

@implementation PurchaseStatsController {
    PurchaseStatsView *_view;
    PurchaseStatsSettings *_settings;
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
    _view = [[PurchaseStatsView alloc] init];
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

    _settings = nil;
    _lastProductURL = [_view productViewAtLocation:CGPointZero].product.productURL;

    _view.delegate = nil;
    _view = nil;
}

- (float)viewHeight {
    return HEIGHT;
}

- (NSURL *)launchURLForTapLocation:(CGPoint)tapLocation {
    PurchaseStatsProductView *view = [_view productViewAtLocation:tapLocation];
    NSURL *url = nil;
    if (view) {
        url = [NSURL URLWithString:view.product.productURL ?: PRODUCTS_URL];
    }
    return url;
}

- (void)refreshPurchaseStats {
    [_fetcher fetch];
}

- (void)purchaseStatsViewReady:(PurchaseStatsView *)view {
    _settings = [[PurchaseStatsSettings alloc] init];
    _store = [[PurchaseStatsStore alloc] init];
    _store.delegate = self;
    _store.settings = _settings;
    _fetcher.settings = _settings;

    for (PurchaseStatsProduct *product in _store.visibleProducts) {
        [_view addOrUpdateViewForProduct:product];
    }
    [_view sortProductViews];

    if (_lastProductURL) {
        [_view showProduct:_lastProductURL];
    }

    if (_settings.autoRefresh) {
        [_fetcher autoFetch];
    }
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
