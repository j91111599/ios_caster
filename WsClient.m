#import "WsClient.h"
#import "YLog.h"

@implementation WsClient {
    NSURLSession *_session;
    NSURLSessionWebSocketTask *_task;
    NSMutableArray<id> *_pending;
    NSURL *_url;                 // 保存原始 ws:// URL（不要用 originalRequest.URL 重建）
}

- (instancetype)initWithURL:(NSURL *)url {
    if ((self = [super init])) {
        _url = url;
        _session = [NSURLSession sessionWithConfiguration:
                    [NSURLSessionConfiguration defaultSessionConfiguration]];
        _pending = [NSMutableArray array];
    }
    return self;
}

- (BOOL)isReady {
    return _task && _task.state == NSURLSessionTaskStateRunning;
}

- (void)flushPending {
    if (![self isReady]) return;
    NSArray *items = [_pending copy];
    [_pending removeAllObjects];
    for (id item in items) {
        @try { [_task sendMessage:item completionHandler:^(NSError *e) { }]; }
        @catch (NSException *ex) { }
    }
}

- (void)connect {
    @try {
        NSError *err = nil;
        NSString *scheme = _url.scheme.lowercaseString;
        if (![scheme isEqualToString:@"ws"] && ![scheme isEqualToString:@"wss"]) {
            YLog(@"connect aborted: bad scheme %@", _url);
            return;
        }
        _task = [_session webSocketTaskWithURL:_url];
        if (!_task) {
            YLog(@"connect failed: task nil for %@", _url);
            return;
        }
        [_task resume];
        [self receive];
        YLog(@"ws connecting %@", _url.absoluteString);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ [self flushPending]; });
    } @catch (NSException *e) {
        YLog(@"connect exception: %@ | %@", e.name, e.reason);
    }
}

- (void)receive {
    __weak typeof(self) weakSelf = self;
    [_task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *msg, NSError *err) {
        if (err) {
            YLog(@"ws recv err: %@", err.localizedDescription);
            [weakSelf scheduleReconnect];
            return;
        }
        if (msg.type == NSURLSessionWebSocketMessageTypeString) {
            YLog(@"ws text: %@", msg.string);
            if (weakSelf.onText) weakSelf.onText(msg.string);
        } else {
            YLog(@"ws binary recv %lu B (unexpected on this channel)",
                 (unsigned long)msg.data.length);
        }
        [weakSelf receive];
    }];
}

- (void)scheduleReconnect {
    static int attempt = 0;
    attempt++;
    NSTimeInterval delay = MIN(10.0, 1.0 * attempt);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self connect]; });
}

- (void)sendData:(NSData *)data {
    NSURLSessionWebSocketMessage *m = [[NSURLSessionWebSocketMessage alloc] initWithData:data];
    if (![self isReady]) { [_pending addObject:m]; return; }
    @try { [_task sendMessage:m completionHandler:^(NSError *e) { }]; }
    @catch (NSException *ex) { }
}

- (void)sendText:(NSString *)text {
    NSURLSessionWebSocketMessage *m = [[NSURLSessionWebSocketMessage alloc] initWithString:text];
    if (![self isReady]) { [_pending addObject:m]; return; }
    @try { [_task sendMessage:m completionHandler:^(NSError *e) { }]; }
    @catch (NSException *ex) { }
}

@end
