#import "Capture.h"
#import <ReplayKit/ReplayKit.h>

@interface Capture () <RPScreenRecorderDelegate>
@end

@implementation Capture

- (void)start {
    RPScreenRecorder *rec = [RPScreenRecorder sharedRecorder];
    rec.delegate = self;
    rec.microphoneEnabled = NO;
    [rec startCaptureWithHandler:^(CMSampleBufferRef sample, RPSampleBufferType type, NSError *err) {
        if (type == RPSampleBufferTypeVideo && sample) {
            [self.delegate captureDidOutput:sample];
        }
    } completionHandler:^(NSError *err) {
        NSLog(@"[YKCaster] capture start: %@", err ?: @"ok");
    }];
}

- (void)stop {
    [[RPScreenRecorder sharedRecorder] stopCaptureWithHandler:^(NSError *err) {
        NSLog(@"[YKCaster] capture stop: %@", err ?: @"ok");
    }];
}

@end
