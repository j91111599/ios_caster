#import "WsClient.h"
#import "YLog.h"

@implementation WsClient {
    NSURLSession *_session;
    NSURLSessionWebSocketTask *_task;
    NSMutableArray<id> *_pending;   // 任务没 resume 前先缓存
}

- (instancetype)initWithURL:(NSURL *)url {
    if ((self = [super init])) {
        _session = [NSURLSession sessionWithConfiguration:
                    [NSURLSessionConfiguration defaultSessionConfiguration]];
        _task = [_session webSocketTaskWithURL:url];
        _pending = [NSMutableArray array];
    }
    return self;
}

- (BOOL)isReady {
    return _task && _task.state == NSURLSessionTaskStateRunning;
}

- (void)flushPending {
    if (![self isReady]) return;
    for (id item in _pending) {
        @try {
            [_task sendMessage:item completionHandler:^(NSError *e) { }];
        } @catch (NSException *ex) { }
    }
    [_pending removeAllObjects];
}

- (void)connect {
    _task = [_session webSocketTaskWithURL:_task.originalRequest.URL];
    [_task resume];
    [self receive];
    NSLog(@"[YKC] ws connecting %@", _task.originalRequest.URL);
    // resume 之后 flush（给一点时间进入 running）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self flushPending]; });
}

- (void)receive {
    __weak typeof(self) weakSelf = self;
    [_task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *msg, NSError *err) {
        if (err) {
            NSLog(@"[YKC] ws recv err %@", err.localizedDescription);
            [weakSelf scheduleReconnect];
            return;
        }
        if (msg.type == NSURLSessionWebSocketMessageTypeString) {
            NSLog(@"[YKC] ws text: %@", msg.string);
            if (weakSelf.onText) weakSelf.onText(msg.string);
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
    if (![self isReady]) {
        [_pending addObject:[[NSURLSessionWebSocketMessage alloc] initWithData:data]];
        return;
    }
    @try {
        [_task sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithData:data]
         completionHandler:^(NSError *e) { }];
    } @catch (NSException *ex) { }
}

- (void)sendText:(NSString *)text {
    if (![self isReady]) {
        [_pending addObject:[[NSURLSessionWebSocketMessage alloc] initWithString:text]];
        return;
    }
    @try {
        [_task sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithString:text]
         completionHandler:^(NSError *e) { }];
    } @catch (NSException *ex) { }
}

@end
