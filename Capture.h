#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@protocol CaptureDelegate <NSObject>
- (void)captureDidOutput:(CMSampleBufferRef)sample;
@end

@interface Capture : NSObject
@property (nonatomic, weak) id<CaptureDelegate> delegate;
- (void)start;
- (void)stop;
@end
