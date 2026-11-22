#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

@protocol CaptureDelegate <NSObject>
- (void)capturePixelBuffer:(CVPixelBufferRef)pb pts:(CFTimeInterval)pts;
@end

@interface Capture : NSObject
@property (nonatomic, weak) id<CaptureDelegate> delegate;
@property (nonatomic, assign) int frameCount;
- (void)start;
- (void)stop;
@end
