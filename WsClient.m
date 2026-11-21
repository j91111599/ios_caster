#import "WsClient.h"
#import "YLog.h"

@implementation WsClient {
    NSURLSession *_session;
    NSURLSessionWebSocketTask *_task;
}

- (instancetype)initWithURL:(NSURL *)url {
    if ((self = [super init])) {
        _session = [NSURLSession sessionWithConfiguration:
                    [NSURLSessionConfiguration defaultSessionConfiguration]];
        _task = [_session webSocketTaskWithURL:url];
    }
    return self;
}

- (void)connect {
    _task = [_session webSocketTaskWithURL:_task.originalRequest.URL];
    [_task resume];
    [self receive];
    YLog(@"ws connecting %@", _task.originalRequest.URL);
}

- (void)receive {
    __weak typeof(self) weakSelf = self;
    [_task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *msg, NSError *err) {
        if (err) {
            YLog(@"ws recv err %@", err.localizedDescription);
            [self scheduleReconnect];
            return;
        }
        if (msg.type == NSURLSessionWebSocketMessageTypeString) {
            NSLog(@"[YKCaster] ws text: %@", msg.string);
            if (weakSelf.onText) weakSelf.onText(msg.string);
        }
        [weakSelf receive];
    }];
}

- (void)scheduleReconnect {
    static int attempt = 0;
    attempt++;
    NSTimeInterval delay = MIN(10.0, 1.0 * attempt);
    YLog(@"ws reconnect in %.0fs (attempt %d)", delay, attempt);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self connect];
        if (self.onText) self.onText(@"{\"cmd\":\"hello\",\"role\":\"device\",\"codec\":\"h264\"}");
    });
}

- (void)sendData:(NSData *)data {
    [_task sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithData:data]
     completionHandler:^(NSError *err) {
        if (err) NSLog(@"[YKCaster] ws send err %@", err);
    }];
}

- (void)sendText:(NSString *)text {
    NSURLSessionWebSocketMessage *msg =
        [[NSURLSessionWebSocketMessage alloc] initWithString:text];
    [_task sendMessage:msg completionHandler:^(NSError *error) {
        if (error) {
            NSLog(@"[YKCaster] ws sendText err %@", error);
        }
    }];
}

@end
