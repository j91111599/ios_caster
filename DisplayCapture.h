#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

@interface DisplayCapture : NSObject
+ (CVPixelBufferRef)copyCurrentFrame CF_RETURNS_RETAINED;
@end
