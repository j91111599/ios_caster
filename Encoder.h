#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@protocol EncoderDelegate <NSObject>
- (void)encoderDidOutputAnnexB:(NSData *)data keyframe:(BOOL)keyframe;
@end

@interface Encoder : NSObject
@property (nonatomic, weak) id<EncoderDelegate> delegate;
- (instancetype)initWithSize:(CGSize)size fps:(int)fps bitrate:(int)bitrate;
- (void)encode:(CMSampleBufferRef)sample;
- (void)forceKeyframe;
@end
