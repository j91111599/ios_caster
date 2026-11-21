// 后台抓屏钩子 —— 依据厂商 YKSBTweak.dylib 的静态分析结果重写
//
// 证据（从 YKSBTweak.dylib 抽出的字符串/选择器）：
//   Filter.Bundles            = com.apple.springboard        ← 注入目标是 SpringBoard
//   CADisplayLink / displayDidRefresh: / setDisplayLink:      ← 用显示刷新回调驱动抓帧
//   _includesStateSnapshotInBridgeEvents                      ← SpringBoard 内部有状态快照
//   @rpath/YKSBTweak.dylib, SpringBoard 路径串
//
// 结论：原版在 SpringBoard 里挂 CADisplayLink，每帧回调时取屏幕内容并编码。
// 下面的骨架按这个思路写；像素获取用最通用的一步（窗口层 snapshot），
// 若目标系统上不可用，替换 getFramePixelBuffer() 的实现即可。

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreVideo/CoreVideo.h>

static CADisplayLink *gLink;
static id gTarget;

// —— 取一帧像素（返回 CGImageRef，调用方负责 release）——
static CGImageRef getFrameImage(void) {
    // SpringBoard 的 key window 就是我们想抓的整屏内容
    UIWindow *win = nil;
    for (UIScreen *s in [UIScreen screens]) {
        for (UIWindow *w in s.windows) {
            if (w.isKeyWindow) { win = w; break; }
        }
        if (win) break;
    }
    if (!win) return NULL;

    // 用 layer 渲染（不进主线程截图 API，开销可控）
    UIGraphicsBeginImageContextWithOptions(win.bounds.size, NO, 1.0);
    [win.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img ? CGImageRetain(img.CGImage) : NULL;
}

// —— 每帧回调：转成 CVPixelBufferRef 交给编码器 ——
static void onDisplayRefresh(CADisplayLink *link) {
    CGImageRef cg = getFrameImage();
    if (!cg) return;

    size_t w = CGImageGetWidth(cg), h = CGImageGetHeight(cg);
    CVPixelBufferRef pb = NULL;
    NSDictionary *attrs = @{ (id)kCVPixelBufferIOSurfacePropertiesKey: @{} };
    if (CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA,
                            (__bridge CFDictionaryRef)attrs, &pb) == kCVReturnSuccess) {
        CVPixelBufferLockBaseAddress(pb, 0);
        CGContextRef ctx = CGBitmapContextCreate(
            CVPixelBufferGetBaseAddress(pb), w, h, 8,
            CVPixelBufferGetBytesPerRow(pb),
            CGColorSpaceCreateDeviceRGB(),
            kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
        if (ctx) {
            CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cg);
            CGContextRelease(ctx);
        }
        CVPixelBufferUnlockBaseAddress(pb, 0);

        // TODO: 交给 VTCompressionSession 编码，再经 WS(10000) 发出。
        //       可直接复用 Encoder.m / WsClient.m（它们是独立的类，可在此处实例化）。
        CVPixelBufferRelease(pb);
    }
    CGImageRelease(cg);
}

%ctor {
    // 必须等 SpringBoard 的 UIApplication 起来
    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidFinishLaunchingNotification
                    object:nil queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *n) {
        gTarget = [NSObject new];
        gLink = [CADisplayLink displayLinkWithTarget:gTarget selector:@selector(tick:)];
        // 用一个轻量类承载 tick，避免阻塞主线程 UI
        Class proxy = objc_getClass("YKDisplayProxy");
        if (!proxy) {
            proxy = objc_allocateClassPair([NSObject class], "YKDisplayProxy", 0);
            class_addMethod(proxy, @selector(tick:), (IMP)onDisplayRefresh, "v@:@");
            objc_registerClassPair(proxy);
        }
        gTarget = [[proxy alloc] init];
        [gLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        NSLog(@"[YKScreenHook] display link started, interval=%.2f", gLink.duration);
    }];
}
