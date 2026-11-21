#import "Capture.h"
#import <ReplayKit/ReplayKit.h>
#import "YLog.h"

@interface Capture () <RPScreenRecorderDelegate>
@end

@implementation Capture

- (void)start {
    RPScreenRecorder *rec = [RPScreenRecorder sharedRecorder];
    rec.delegate = self;
    rec.microphoneEnabled = NO;
    YLog(@"capture start requested, available=%d", (int)rec.isAvailable);
    [rec startCaptureWithHandler:^(CMSampleBufferRef sample, RPSampleBufferType type, NSError *err) {
        if (type == RPSampleBufferTypeVideo && sample) {
            static int n = 0;
            if (n < 3) { YLog(@"capture sample #%d", n + 1); n++; }
            [self.delegate captureDidOutput:sample];
        } else if (err) {
            YLog(@"capture handler err: %@", err);
        }
    } completionHandler:^(NSError *err) {
        YLog(@"capture start completion: %@", err ? err.description : @"ok");
    }];
}

- (void)stop {
    [[RPScreenRecorder sharedRecorder] stopCaptureWithHandler:^(NSError *err) {
        NSLog(@"[YKCaster] capture stop: %@", err ?: @"ok");
    }];
}

@end
