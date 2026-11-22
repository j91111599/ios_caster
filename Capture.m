#import "Capture.h"
#import <QuartzCore/QuartzCore.h>
#import "DisplayCapture.h"
#import "YLog.h"

@interface Capture ()
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic, assign) int frameAcc;
@property (nonatomic, assign) int targetFps;
@end

@implementation Capture

- (void)start {
    self.targetFps = 30;
    self.frameAcc = 0;
    YLog(@"display capture starting (CARenderServer)");
    self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)tick:(CADisplayLink *)link {
    int step = MAX(1, (int)round(60.0 / (double)MAX(1, self.targetFps)));
    self.frameAcc++;
    if ((self.frameAcc % step) != 0) return;

    @autoreleasepool {
        CVPixelBufferRef pb = [DisplayCapture copyCurrentFrame];
        if (!pb) return;
        ++self.frameCount;
        if (self.frameCount == 1) YLog(@"first display frame captured");
        [self.delegate capturePixelBuffer:pb pts:link.timestamp];
        CVPixelBufferRelease(pb);
    }
}

- (void)stop {
    [self.link invalidate];
    self.link = nil;
}

@end
