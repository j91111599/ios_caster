// SpringBoard 注入抓屏 —— 与原版 YKSBTweak.dylib 同技术路线
//
// 静态证据（从厂商 YKSBTweak.dylib 提取）：
//   Filter.Bundles = com.apple.springboard
//   CADisplayLink / setDisplayLink: / displayDidRefresh:
//   _includesStateSnapshotInBridgeEvents
//
// 流程：CADisplayLink 每帧回调 → 取 SpringBoard 主窗口 layer 渲染 → CVPixelBuffer
//       → VTCompressionSession(H.264 Baseline) → WebSocket PC:10000
//       控制/日志走 PC:10001

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreVideo/CoreVideo.h>
#import "Encoder.h"
#import "WsClient.h"
#import "YLog.h"

static NSString *const kHost = @"192.168.1.42";
static const int kVideoPort = 42400;
static const int kControlPort = 10001;

@interface YKScreenHooker : NSObject <EncoderDelegate>
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic, strong) Encoder *encoder;
@property (nonatomic, strong) WsClient *video;
@property (nonatomic, strong) WsClient *ctrl;
@property (nonatomic, assign) CGSize size;
@property (nonatomic, assign) int fps;
@property (nonatomic, assign) int bitrate;
@property (nonatomic, assign) int frameIndex;
@end

@implementation YKScreenHooker

+ (instancetype)shared {
    static YKScreenHooker *s = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [YKScreenHooker new]; });
    return s;
}

- (void)start {
    self.fps = 30;
    self.bitrate = 4000000;
    self.frameIndex = 0;

    self.video = [[WsClient alloc] initWithURL:
                  [NSURL URLWithString:[NSString stringWithFormat:@"ws://%@:%d/", kHost, kVideoPort]]];
    __weak typeof(self) weakSelf = self;
    self.video.onText = ^(NSString *t) {
        NSData *d = [t dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *o = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if (![o isKindOfClass:[NSDictionary class]]) return;
        if ([o[@"cmd"] isEqualToString:@"config"]) {
            if (o[@"fps"]) weakSelf.fps = [o[@"fps"] intValue];
            if (o[@"bitrate"]) weakSelf.bitrate = [o[@"bitrate"] intValue];
            weakSelf.encoder = nil;
            YLog(@"config applied fps=%d bitrate=%d", weakSelf.fps, weakSelf.bitrate);
        } else if ([o[@"cmd"] isEqualToString:@"keyframe"]) {
            [weakSelf.encoder forceKeyframe];
        }
    };
    [self.video connect];
    [self.video sendText:@"{\"cmd\":\"hello\",\"role\":\"device\",\"codec\":\"h264\"}"];

    self.ctrl = [[WsClient alloc] initWithURL:
                 [NSURL URLWithString:[NSString stringWithFormat:@"ws://%@:%d/", kHost, kControlPort]]];
    [self.ctrl connect];

    YLogSetSink(^(NSString *line) {
        NSDictionary *o = @{@"cmd": @"log", @"msg": line};
        NSData *d = [NSJSONSerialization dataWithJSONObject:o options:0 error:nil];
        [weakSelf.ctrl sendText:[[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding]];
    });

    self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    YLog(@"springboard hook started, display=%.1fHz", 1.0 / self.link.duration);
}

- (void)tick:(CADisplayLink *)link {
    // 按目标帧率抽帧
    static int acc = 0;
    acc++;
    int step = MAX(1, (int)round(60.0 / (double)MAX(1, self.fps)));
    if ((acc % step) != 0) return;

    @autoreleasepool {
        CVPixelBufferRef pb = [self currentPixelBuffer];
        if (!pb) return;

        // 不管有没有收到 config，第一次拿到像素就建编码器（否则 PC 重连后不推流）
        if (!self.encoder) {
            size_t w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb);
            self.size = CGSizeMake(w, h);
            self.encoder = [[Encoder alloc] initWithSize:self.size
                                                     fps:self.fps
                                                 bitrate:self.bitrate];
            self.encoder.delegate = self;
            YLog(@"encoder created %zux%zu", w, h);
        }
        [self.encoder encodePixelBuffer:pb pts:link.timestamp];
        CVPixelBufferRelease(pb);
    }
}

- (CVPixelBufferRef)currentPixelBuffer {
    UIWindow *win = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *w in ((UIWindowScene *)scene).windows) {
            if (w.isKeyWindow) { win = w; break; }
        }
        if (win) break;
    }
    if (!win) return NULL;

    CGRect bounds = win.bounds;
    size_t w = (size_t)(bounds.size.width * win.screen.scale);
    size_t h = (size_t)(bounds.size.height * win.screen.scale);
    if (w == 0 || h == 0) return NULL;

    CVPixelBufferRef pb = NULL;
    NSDictionary *attrs = @{ (id)kCVPixelBufferIOSurfacePropertiesKey: @{} };
    if (CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA,
                            (__bridge CFDictionaryRef)attrs, &pb) != kCVReturnSuccess)
        return NULL;

    CVPixelBufferLockBaseAddress(pb, 0);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(CVPixelBufferGetBaseAddress(pb), w, h, 8,
                                             CVPixelBufferGetBytesPerRow(pb), cs,
                                             kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    if (ctx) {
        UIGraphicsPushContext(ctx);
        [win.layer renderInContext:ctx];
        UIGraphicsPopContext();
        CGContextRelease(ctx);
    }
    CGColorSpaceRelease(cs);
    CVPixelBufferUnlockBaseAddress(pb, 0);
    return pb;
}

- (void)encoderDidOutputAnnexB:(NSData *)data keyframe:(BOOL)keyframe {
    [self.video sendData:data];
    if (keyframe) YLog(@"keyframe sent %lu B", (unsigned long)data.length);
}

@end

__attribute__((constructor))
static void YKHookInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        @try {
            YLog(@"=== springboard hook booting ===");
            [[YKScreenHooker shared] start];
        } @catch (NSException *e) {
            YLog(@"hook start EXCEPTION %@ | %@", e.name, e.reason);
        }
    });
}
