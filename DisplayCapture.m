#import "DisplayCapture.h"
#import <UIKit/UIKit.h>
#import <CoreVideo/CoreVideo.h>
#import "YLog.h"

// iOS SDK 里没有公开的 IOSurface 头文件，这里手写声明（越狱环境可用）
typedef struct __IOSurface *IOSurfaceRef;
extern IOSurfaceRef IOSurfaceCreate(CFDictionaryRef properties);

// 私有 API：把整块显示渲染进 IOSurface
extern int CARenderServerRenderDisplay(uint32_t display, CFStringRef name,
                                       IOSurfaceRef surface, int x, int y);

static IOSurfaceRef gSurface = NULL;
static size_t gW = 0, gH = 0;

@implementation DisplayCapture

+ (CVPixelBufferRef)copyCurrentFrame {
    UIScreen *screen = [UIScreen mainScreen];
    CGFloat scale = screen.scale;
    CGSize size = screen.bounds.size;
    size_t w = (size_t)(size.width * scale);
    size_t h = (size_t)(size.height * scale);
    if (w == 0 || h == 0) return NULL;

    if (!gSurface || gW != w || gH != h) {
        if (gSurface) { CFRelease(gSurface); gSurface = NULL; }
        // 用字符串键（等同 kIOSurfaceWidth / Height / BytesPerElement / PixelFormat）
        const void *keys[] = {
            CFSTR("IOSurfaceWidth"), CFSTR("IOSurfaceHeight"),
            CFSTR("IOSurfaceBytesPerElement"), CFSTR("IOSurfacePixelFormat")
        };
        int wv = (int)w, hv = (int)h, bpe = 4, fmt = 'BGRA';
        const void *vals[] = {
            CFNumberCreate(NULL, kCFNumberIntType, &wv),
            CFNumberCreate(NULL, kCFNumberIntType, &hv),
            CFNumberCreate(NULL, kCFNumberIntType, &bpe),
            CFNumberCreate(NULL, kCFNumberIntType, &fmt)
        };
        CFDictionaryRef props = CFDictionaryCreate(NULL, keys, vals, 4,
                                                   &kCFTypeDictionaryKeyCallBacks,
                                                   &kCFTypeDictionaryValueCallBacks);
        gSurface = IOSurfaceCreate(props);
        CFRelease(props);
        for (int i = 0; i < 4; i++) CFRelease(vals[i]);
        gW = w; gH = h;
        if (!gSurface) { YLog(@"IOSurfaceCreate failed %zux%zu", w, h); return NULL; }
        YLog(@"IOSurface created %zux%zu", w, h);
    }

    int rc = CARenderServerRenderDisplay(0, CFSTR("LCD"), gSurface, 0, 0);
    if (rc != 0) {
        static int warned = 0;
        if (warned < 3) { YLog(@"CARenderServerRenderDisplay rc=%d", rc); warned++; }
        return NULL;
    }

    CVPixelBufferRef pb = NULL;
    NSDictionary *attrs = @{ (id)kCVPixelBufferIOSurfacePropertiesKey: @{} };
    CVReturn st = CVPixelBufferCreateWithIOSurface(kCFAllocatorDefault, gSurface,
                                                   (__bridge CFDictionaryRef)attrs, &pb);
    if (st != kCVReturnSuccess || !pb) {
        static int warned2 = 0;
        if (warned2 < 3) { YLog(@"CVPixelBufferCreateWithIOSurface st=%d", (int)st); warned2++; }
        return NULL;
    }
    return pb;
}

@end
