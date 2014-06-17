#import <objc/runtime.h>

#import "PurchaseStatsFetcher.h"

#import "AccountChooser.js.min.h"
#import "FacebookLogin.js.min.h"
#import "ScrapeProducts.js.min.h"

#define INITIAL_MAX_REQUESTS 16
#define AUTOFETCH_INTERVAL 1800
#define FETCH_TIMEOUT 240
#define PRODUCT_DATA_ASSOCIATION "net.joedj.purchasestats.productData"

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
    NSMutableSet *_productConnections;
    NSDate *_lastFetch;
    NSTimer *_autoFetchTimer;
    NSTimer *_timeout;
    NSRegularExpression *_productDataRegex;
}

- (id)init {
    if ((self = [super init])) {
        _productDataRegex = [NSRegularExpression regularExpressionWithPattern:
            @"<label><p>Total Sales</p></label>\\s*<label[^>]*><p>(.*?)</p></label>.*<label><p>Pending Earnings</p></label>\\s*<label[^>]*><p>(.*?)</p></label>"
            options:NSRegularExpressionDotMatchesLineSeparators error:NULL];
    }
    return self;
}

- (void)cancelAutoFetchTimer {
    [_autoFetchTimer invalidate];
    _autoFetchTimer = nil;
}

- (void)_resetAutoFetchTimer {
    [self cancelAutoFetchTimer];
    if (_settings.autoRefresh) {
        _autoFetchTimer = [NSTimer scheduledTimerWithTimeInterval:AUTOFETCH_INTERVAL target:self selector:@selector(autoFetch) userInfo:nil repeats:NO];
    }
}

- (void)_cleanup {
    for (NSURLConnection *connection in _productConnections) {
        [connection cancel];
    }
    _productConnections = nil;
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

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    NSString *location = [webView stringByEvaluatingJavaScriptFromString:@"document.location.href"];
    if ([location hasPrefix:@"https://cydia.saurik.com/api/login"]) {
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
    } else if ([location hasPrefix:@"https://accounts.google.com/"]) {
        if ([webView stringByEvaluatingJavaScriptFromString:@"document.getElementById('accountchooser-title').innerHTML"].length) {
            if ([self _countRequest]) {
                __autoreleasing NSError *error = nil;
                NSString *jsUsername = stringToJSON(_settings.username, &error);
                if (error || !jsUsername.length) {
                    [self _failHard:[NSString stringWithFormat:@"Unable to serialize username as JSON: %@", error]];
                } else if (![webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:ACCOUNTCHOOSER_JS_MIN, jsUsername]].length) {
                    [self _fail:@"Unable to find username in account chooser."];
                }
            }
        } else {
            [self webView:webView setValue:_settings.username forElementId:@"Email"] &&
            [self webView:webView setValue:_settings.password forElementId:@"Passwd"] &&
            [self _countRequest] &&
            [self webView:webView submitForm:@"gaia_loginform"];
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
            _productConnections = [[NSMutableSet alloc] init];
            for (NSDictionary *productDict in products) {
                NSString *productURL = productDict[@"productURL"];
                if (productURL) {
                    [_delegate purchaseStatsFetcher:self gotProductDictionary:productDict];
                    if ([self _countRequest]) {

                    }
                    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:productURL] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
                    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
                    [_productConnections addObject:connection];
                }
            }
        } else {
            [self _fail:@"Unable to scrape products."];
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

- (void)productConnectionFinished:(NSURLConnection *)cxn reason:(id)reason {
    [cxn cancel];
    [_productConnections removeObject:cxn];
    if (reason) {
        [self _fail:reason];
    } else if (!_productConnections.count) {
        [self _win];
    }
}

- (void)connection:(NSURLConnection *)cxn didReceiveResponse:(NSHTTPURLResponse *)response {
    if (response.statusCode != 200) {
        NSString *reason = [NSString stringWithFormat:@"Unable to scrape %@: %d %@",
            cxn.originalRequest.URL,
            (int)response.statusCode,
            [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode]];
        [self productConnectionFinished:cxn reason:reason];
    }
    objc_setAssociatedObject(cxn, PRODUCT_DATA_ASSOCIATION, [[NSMutableData alloc] init], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)connection:(NSURLConnection *)cxn didReceiveData:(NSData *)data {
    [objc_getAssociatedObject(cxn, PRODUCT_DATA_ASSOCIATION) appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)cxn {
    NSData *productData = objc_getAssociatedObject(cxn, PRODUCT_DATA_ASSOCIATION);
    NSString *productHTML = [[NSString alloc] initWithData:productData encoding:NSUTF8StringEncoding];
    NSString *reason = nil;
    NSTextCheckingResult *match = [_productDataRegex firstMatchInString:productHTML options:0 range:NSMakeRange(0, productHTML.length)];
    if (match) {
        NSString *totalSales = [productHTML substringWithRange:[match rangeAtIndex:1]];
        NSString *pendingEarnings = [productHTML substringWithRange:[match rangeAtIndex:2]];
        [_delegate purchaseStatsFetcher:self gotProductDictionary:@{
            @"productURL" : cxn.originalRequest.URL.absoluteString,
            @"totalSales" : totalSales,
            @"pendingEarnings" : pendingEarnings
        }];
    } else {
        reason = [NSString stringWithFormat:@"Unable to scrape product: %@", cxn.originalRequest.URL];
    }
    [self productConnectionFinished:cxn reason:reason];
}

- (void)connection:(NSURLConnection *)cxn didFailWithError:(NSError *)error {
    [self productConnectionFinished:cxn reason:error];
}

@end
