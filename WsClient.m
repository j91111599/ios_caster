#import "WsClient.h"

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
    [_task resume];
    [self receive];
    NSLog(@"[YKCaster] ws connect %@", _task.originalRequest.URL);
}

- (void)receive {
    __weak typeof(self) weakSelf = self;
    [_task receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage *msg, NSError *err) {
        if (err) {
            NSLog(@"[YKCaster] ws recv err %@", err);
            return;
        }
        if (msg.type == NSURLSessionWebSocketMessageTypeString) {
            NSLog(@"[YKCaster] ws text: %@", msg.string);
            if (weakSelf.onText) weakSelf.onText(msg.string);
        }
        [weakSelf receive];
    }];
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
