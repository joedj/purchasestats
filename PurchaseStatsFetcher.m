#import "PurchaseStatsFetcher.h"

#import "AccountChooser.js.min.h"
#import "FacebookLogin.js.min.h"
#import "ScrapeProduct.js.min.h"
#import "ScrapeProducts.js.min.h"

#define INITIAL_MAX_REQUESTS 16
#define AUTOFETCH_INTERVAL 300
#define FETCH_TIMEOUT 240

static NSString *stringToJSON(NSString *s, NSError **error) {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:s options:(NSJSONWritingOptions)NSJSONReadingAllowFragments error:error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonString;
}

@implementation PurchaseStatsFetcher {
    PurchaseStatsSettings *_settings;
    UIWebView *_webView;
    NSUInteger _requests;
    NSUInteger _maxRequests;
    NSUInteger _retries;
    NSInteger _currentProduct;
    NSMutableArray *_products;
    NSDate *_lastFetch;
    NSTimer *_autoFetchTimer;
    NSTimer *_timeout;
}

- (id)init {
    if ((self = [super init])) {
        _currentProduct = -1;
    }
    return self;
}

- (void)_resetAutoFetchTimer {
    if (_autoFetchTimer) {
        [_autoFetchTimer invalidate];
        _autoFetchTimer = nil;
    }
    if (_settings.autoRefresh) {
        _autoFetchTimer = [NSTimer scheduledTimerWithTimeInterval:AUTOFETCH_INTERVAL target:self selector:@selector(autoFetch) userInfo:nil repeats:NO];
    }
}

- (void)_cleanup {
    _currentProduct = -1;
    _products = nil;
    _webView.delegate = nil;
    [_webView stopLoading];
    _webView = nil;
    _lastFetch = NSDate.date;
    [_timeout invalidate];
    _timeout = nil;
    [self _resetAutoFetchTimer];
}

- (void)dealloc {
    _settings = nil;
    [self _cleanup];
}

- (void)setSettings:(PurchaseStatsSettings *)settings {
    _settings = settings;
    [self _resetAutoFetchTimer];
}

- (void)_failHard:(id)reason {
    [self _cleanup];
    [self stop];
    NSLog(@"PurchaseStats: Fetch failed: %@", reason);
    [_delegate purchaseStatsFetcher:self failed:reason];
}

- (void)_fetch {
    [self _cleanup];
    _webView = [[UIWebView alloc] init];
    _webView.delegate = self;
    _requests = 1;
    _maxRequests = INITIAL_MAX_REQUESTS;
    [_delegate purchaseStatsFetcherStarted:self];
    if (_webView) {
        _timeout = [NSTimer scheduledTimerWithTimeInterval:FETCH_TIMEOUT target:self selector:@selector(_timeout) userInfo:nil repeats:NO];
        [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:PRODUCTS_URL]]];
    }
}

- (void)fetch {
    if (!_webView) {
        _retries = 0;
        if (_settings.isConfigured) {
            [self _fetch];
        } else {
            [self _failHard:@"Missing username and/or password."];
        }
    }
}

- (void)autoFetch {
    if (!_lastFetch || [_lastFetch timeIntervalSinceNow] < -AUTOFETCH_INTERVAL) {
        [self fetch];
    } else {
        [self _resetAutoFetchTimer];
    }
}

- (void)stop {
    _retries = 0;
    _requests = 0;
    _maxRequests = INITIAL_MAX_REQUESTS;
    if (_webView) {
        [self _cleanup];
    }
}

- (void)cancelAutoFetchTimer {
    [_autoFetchTimer invalidate];
    _autoFetchTimer = nil;
}

- (void)_win {
    [self _cleanup];
    [self stop];
    [_delegate purchaseStatsFetcherFinished:self];
}

- (void)_fail:(id)reason {
    _retries++;
    if (_retries <= 3) {
        NSLog(@"PurchaseStats: Fetch failed, retrying: %@", reason);
        [self _fetch];
    } else {
        [self _failHard:reason];
    }
}

- (void)_timeout {
    [self _fail:[NSString stringWithFormat:@"Timed out after %d seconds.", FETCH_TIMEOUT]];
}

- (BOOL)_countRequest {
    _requests++;
    if (_requests <= _maxRequests) {
        return YES;
    } else {
        [self _failHard:@"Too many requests - am I in a loop?"];
        return NO;
    }
}

- (id)webView:(UIWebView *)webView JSONObjectByEvaluatingJavaScript:(NSString *)js {
    js = [NSString stringWithFormat:@"(function() { return JSON.stringify(%@); })()", js];
    NSString *stringResult = [webView stringByEvaluatingJavaScriptFromString:js];
    NSData *dataResult = [stringResult dataUsingEncoding:NSUTF8StringEncoding];
    __autoreleasing NSError *error = nil;
    id result = [NSJSONSerialization JSONObjectWithData:dataResult options:NSJSONReadingAllowFragments error:&error];
    if (error) {
        NSLog(@"PurchaseStats: Unable to deserialize JSON: %@: %@", stringResult, error);
    }
    return result;
}

- (BOOL)webView:(UIWebView *)webView setValue:(id)value forElementId:(NSString *)elementId {
    __autoreleasing NSError *error = nil;
    NSData *jsValueData = [NSJSONSerialization dataWithJSONObject:value options:(NSJSONWritingOptions)NSJSONReadingAllowFragments error:&error];
    if (error || !jsValueData) {
        [self _fail:[NSString stringWithFormat:@"Could not encode value %@ as JSON string: %@", value, error]];
        return NO;
    }
    NSString *jsValue = [[NSString alloc] initWithData:jsValueData encoding:NSUTF8StringEncoding];
    if (!jsValue) {
        [self _fail:[NSString stringWithFormat:@"Could not decode JSON data %@ as UTF-8", jsValueData]];
        return NO;
    }
    if (![webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.getElementById('%@').value = %@; 1", elementId, jsValue]].length) {
        [self _fail:[NSString stringWithFormat:@"Couldn't set field %@", elementId]];
        return NO;
    }
    return YES;
}

- (BOOL)webView:(UIWebView *)webView submitForm:(NSString *)elementId {
    if (![webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.getElementById('%@').submit(); 1", elementId]].length) {
        [self _fail:[NSString stringWithFormat:@"Couldn't submit form %@", elementId]];
        return NO;
    }
    return YES;
}

- (BOOL)loadNextProduct {
    _currentProduct++;
    if (_currentProduct == _products.count) {
        [self _win];
        return YES;
    }
    if ([self _countRequest]) {
        NSString *productURL = _products[_currentProduct];
        if ([_settings isProductVisible:productURL]) {
            [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:productURL]]];
        } else {
            [self loadNextProduct];
        }
        return YES;
    }
    return NO;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSString *location = [webView stringByEvaluatingJavaScriptFromString:@"document.location.href"];
    if (_currentProduct >= 0 && [location hasPrefix:PRODUCTS_URL]) {
        NSDictionary *productDict = [self webView:webView JSONObjectByEvaluatingJavaScript:SCRAPEPRODUCT_JS_MIN];
        if (productDict) {
            [_delegate purchaseStatsFetcher:self gotProductDictionary:productDict];
        }
        [self loadNextProduct];
    } else if ([location hasPrefix:@"https://cydia.saurik.com/api/login"]) {
        for (int i = 0; i < 16; i++) {
            NSString *href = [webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"document.getElementsByTagName('a')[%i].href", i]];
            if (!href.length) {
                break;
            } else if (
                (_settings.authProvider == PurchaseStatsAuthProviderGoogle && [href hasPrefix:@"https://www.google.com/accounts"]) ||
                (_settings.authProvider == PurchaseStatsAuthProviderFacebook && [href hasPrefix:@"http://m.facebook.com/dialog/oauth"])
            ) {
                if ([self _countRequest]) {
                    [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:href]]];
                }
                return;
            }
        }
        [self _fail:@"Couldn't find Google link on first page."];
    } else if ([location hasPrefix:@"https://accounts.google.com/ServiceLogin"]) {
        [self webView:webView setValue:_settings.username forElementId:@"Email"] &&
        [self webView:webView setValue:_settings.password forElementId:@"Passwd"] &&
        [self _countRequest] &&
        [self webView:webView submitForm:@"gaia_loginform"];
    } else if ([location hasPrefix:@"https://accounts.google.com/AccountChooser"]) {
        if ([self _countRequest]) {
            __autoreleasing NSError *error = nil;
            NSString *jsUsername = stringToJSON(_settings.username, &error);
            if (error || !jsUsername.length) {
                [self _failHard:[NSString stringWithFormat:@"Unable to serialize username as JSON: %@", error]];
            } else if (![webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:ACCOUNTCHOOSER_JS_MIN, jsUsername]].length) {
                [self _fail:@"Unable to find username in account chooser."];
            }
        }
    } else if ([location hasPrefix:@"http://m.facebook.com/login.php"]) {
        if ([self _countRequest]) {
            __autoreleasing NSError *error = nil;
            NSString *jsUsername = stringToJSON(_settings.username, &error);
            if (error || !jsUsername.length) {
                [self _failHard:[NSString stringWithFormat:@"Unable to serialize username as JSON: %@", error]];
                return;
            }
            error = nil;
            NSString *jsPassword = stringToJSON(_settings.password, &error);
            if (error || !jsPassword.length) {
                [self _failHard:[NSString stringWithFormat:@"Unable to serialize password as JSON: %@", error]];
            } else if (![webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:FACEBOOKLOGIN_JS_MIN, jsUsername, jsPassword]].length) {
                [self _fail:@"Unable to perform facebook login."];
            }
        }
    } else if ([location isEqualToString:PRODUCTS_URL]) {
        NSDictionary *result = [self webView:webView JSONObjectByEvaluatingJavaScript:SCRAPEPRODUCTS_JS_MIN];
        NSDictionary *summary = result[@"summary"];
        if (summary) {
            [_delegate purchaseStatsFetcher:self gotProductDictionary:summary];
        }
        NSArray *products = result[@"products"];
        if (products) {
            _maxRequests += products.count;
            _currentProduct = -1;
            _products = [[NSMutableArray alloc] init];
            for (NSDictionary *productDict in products) {
                NSString *productURL = productDict[@"productURL"];
                if (productURL) {
                    [_products addObject:productURL];
                    [_delegate purchaseStatsFetcher:self gotProductDictionary:productDict];
                }
            }
            [self loadNextProduct];
        } else {
            [self _fail:@"Unable to scrape products"];
        }
    } else {
        [self _fail:[NSString stringWithFormat:@"Where the bloody hell am I? %@", location]];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    if (!(error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled)) {
        [self _fail:error];
    }
}

@end
