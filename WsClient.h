#import <Foundation/Foundation.h>

@interface WsClient : NSObject
@property (nonatomic, copy) void (^onText)(NSString *text);
- (instancetype)initWithURL:(NSURL *)url;
- (void)connect;
- (void)sendData:(NSData *)data;
- (void)sendText:(NSString *)text;
@end
