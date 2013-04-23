#import "PurchaseStatsStore.h"

#define SAVE_INTERVAL 60

@implementation PurchaseStatsProduct

+ (NSArray *)keys {
    return @[@"productURL", @"iconDataURL", @"name", @"incomeRate", @"delta", @"direction", @"totalSales", @"pendingEarnings"];
}

- (void)updateWithDictionary:(NSDictionary *)d {
    for (NSString *key in [self.class keys]) {
        id newValue = d[key];
        id oldValue = [self valueForKey:key];
        if (newValue && newValue != NSNull.null && ![newValue isEqual:oldValue]) {
            [self setValue:newValue forKey:key];
            _dirty = YES;
        }
    }
}

- (id)initWithDictionary:(NSDictionary *)d {
    if ((self = [super init])) {
        [self updateWithDictionary:d];
    }
    return self;
}

- (NSDictionary *)dictionary {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSString *key in [self.class keys]) {
        id value = [self valueForKey:key];
        if (value) {
            d[key] = value;
        }
    }
    return d;
}

@end

@implementation PurchaseStatsStore {
    PurchaseStatsSettings *_settings;
    NSMutableDictionary *_products;
    PurchaseStatsProduct *_summary;
    NSTimer *_saveTimer;
}

- (void)scheduleSave {
    if (!_saveTimer) {
        _saveTimer = [NSTimer scheduledTimerWithTimeInterval:SAVE_INTERVAL target:self selector:@selector(save) userInfo:nil repeats:NO];
    }
}

- (void)save {
    if (_saveTimer) {
        [_saveTimer invalidate];
        _saveTimer = nil;
        NSData *data = [NSPropertyListSerialization dataFromPropertyList:self.dictionary format:NSPropertyListBinaryFormat_v1_0 errorDescription:NULL];
        [data writeToFile:STORE_PLIST options:NSAtomicWrite error:NULL];
    }
}

- (id)init {
    if ((self = [super init])) {
        NSMutableDictionary *stats = [NSMutableDictionary dictionaryWithContentsOfFile:STORE_PLIST];
        _summary = [[PurchaseStatsProduct alloc] initWithDictionary:stats[@"summary"]];
        _summary.dirty = NO;
        _products = [[NSMutableDictionary alloc] init];
        for (NSDictionary *productDict in stats[@"products"]) {
            PurchaseStatsProduct *product = [[PurchaseStatsProduct alloc] initWithDictionary:productDict];
            product.dirty = NO;
            _products[product.productURL] = product;
        }
    }
    return self;
}

- (void)dealloc {
    [self save];
}

- (void)setSettings:(PurchaseStatsSettings *)settings {
    _settings = settings;
}

- (NSDictionary *)dictionary {
    NSMutableDictionary *stats = [NSMutableDictionary dictionary];
    NSMutableArray *products = [NSMutableArray array];
    for (PurchaseStatsProduct *product in _products.allValues) {
        [products addObject:product.dictionary];
    }
    stats[@"summary"] = _summary.dictionary;
    stats[@"products"] = products;
    return stats;
}

- (void)updateSummary {
    int totalSales = 0;
    double pendingEarnings = 0;
    for (PurchaseStatsProduct *product in _products.allValues) {
        totalSales += [product.totalSales intValue];
        pendingEarnings += [[product.pendingEarnings stringByReplacingOccurrencesOfString:@"$" withString:@""] doubleValue];
    }
    [_summary updateWithDictionary:@{
        @"totalSales" : [NSString stringWithFormat:@"%d", totalSales],
        @"pendingEarnings" : [NSString stringWithFormat:@"$%.0f", pendingEarnings]
    }];
}

static NSString *toDataURL(NSData *data) {
    NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    dataStr = [dataStr stringByAddingPercentEscapesUsingEncoding:NSISOLatin1StringEncoding];
    return [@"data:," stringByAppendingString:dataStr];
}

- (void)updateProductWithDictionary:(NSDictionary *)d {
    PurchaseStatsProduct *product;
    NSString *productURL = d[@"productURL"];
    if (productURL) {
        product = _products[productURL];
    } else {
        product = _summary;
        if (!d[@"asyncIconResult"]) {
            d = [[NSMutableDictionary alloc] initWithDictionary:d];
            NSString *iconDataURL = d[@"iconDataURL"];
            [(NSMutableDictionary *)d removeObjectForKey:@"iconDataURL"];
            if (iconDataURL && (!product.iconDataURL || /* hack to fix broken caches from previous version */[product.iconDataURL hasPrefix:@"http"])) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSData *iconData = [NSData dataWithContentsOfURL:[NSURL URLWithString:iconDataURL]];
                    if (iconData) {
                        NSString *dataURL = toDataURL(iconData);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self updateProductWithDictionary:@{ @"asyncIconResult" : @YES, @"iconDataURL" : dataURL }];
                        });
                    }
                });
            }
        }
    }
    if (!product) {
        product = [[PurchaseStatsProduct alloc] initWithDictionary:d];
        _products[productURL] = product;
    } else {
        [product updateWithDictionary:d];
    }
    if (product.dirty) {
        if (product != _summary) {
            [self updateSummary];
        }
        if (_summary.dirty) {
            _summary.dirty = NO;
            [_delegate purchaseStatsStore:self updatedProduct:_summary];
        }
        product.dirty = NO;
        if ([_settings isProductVisible:product.productURL]) {
            [_delegate purchaseStatsStore:self updatedProduct:product];
        }
        [self scheduleSave];
    }
}

- (NSArray *)allProducts {
    return _products.allValues;
}

- (NSArray *)visibleProducts {
    NSMutableArray *visibleProducts = [NSMutableArray array];
    for (PurchaseStatsProduct *product in _products.allValues) {
        if ([_settings isProductVisible:product.productURL]) {
            [visibleProducts addObject:product];
        }
    }
    [visibleProducts insertObject:_summary atIndex:0];
    return visibleProducts;
}

@end
