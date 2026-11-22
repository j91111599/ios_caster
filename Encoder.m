#import "Encoder.h"
#import <VideoToolbox/VideoToolbox.h>
#import "YLog.h"

// 前置声明：C 里必须先声明后使用
static void EncoderCallback(void *outputCallbackRefCon, void *sourceFrameRefCon,
                            OSStatus status, VTEncodeInfoFlags infoFlags,
                            CMSampleBufferRef sampleBuffer);

@implementation Encoder {
    VTCompressionSessionRef _session;
    int _fps;
}

- (instancetype)initWithSize:(CGSize)size fps:(int)fps bitrate:(int)bitrate {
    if ((self = [super init])) {
        _fps = fps > 0 ? fps : 30;
        NSDictionary *spec = @{
            (id)kVTCompressionPropertyKey_RealTime: @YES,
            (id)kVTCompressionPropertyKey_ProfileLevel: (id)kVTProfileLevel_H264_Baseline_AutoLevel,
            (id)kVTCompressionPropertyKey_AllowFrameReordering: @NO,
            (id)kVTCompressionPropertyKey_MaxKeyFrameInterval: @(_fps),
            (id)kVTCompressionPropertyKey_AverageBitRate: @(bitrate > 0 ? bitrate : 4000000),
        };
        OSStatus st = VTCompressionSessionCreate(kCFAllocatorDefault,
                                                 (int32_t)size.width,
                                                 (int32_t)size.height,
                                                 kCMVideoCodecType_H264,
                                                 NULL,
                                                 (__bridge CFDictionaryRef)spec,
                                                 NULL,
                                                 EncoderCallback,
                                                 (__bridge void *)self,
                                                 &_session);
        if (st != noErr || !_session) {
            YLog(@"VTCompressionSessionCreate FAILED status=%d size=%.0fx%.0f",
                 (int)st, size.width, size.height);
            _session = NULL;
        } else {
            VTSessionSetProperty(_session, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
            YLog(@"encoder ready %.0fx%.0f fps=%d bitrate=%d",
                 size.width, size.height, _fps, bitrate);
        }
    }
    return self;
}

- (void)dealloc {
    if (_session) {
        VTCompressionSessionCompleteFrames(_session, kCMTimeInvalid);
        VTCompressionSessionInvalidate(_session);
        CFRelease(_session);
        _session = NULL;
    }
}

static void EncoderCallback(void *outputCallbackRefCon, void *sourceFrameRefCon,
                            OSStatus status, VTEncodeInfoFlags infoFlags,
                            CMSampleBufferRef sampleBuffer) {
    if (status != noErr || !sampleBuffer) {
        YLog(@"encode cb status=%d buf=%p", (int)status, sampleBuffer);
        return;
    }
    Encoder *self = (__bridge Encoder *)outputCallbackRefCon;
    [self handleSampleBuffer:sampleBuffer];
}

- (void)handleSampleBuffer:(CMSampleBufferRef)buffer {
    BOOL keyframe = NO;
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, false);
    if (attachments && CFArrayGetCount(attachments) > 0) {
        CFDictionaryRef d = (CFDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        keyframe = !CFDictionaryContainsKey(d, kCMSampleAttachmentKey_NotSync);
    }

    NSMutableData *out = [NSMutableData data];

    // 关键帧前置 SPS/PPS（Annex-B），保证中途接入也能解
    if (keyframe) {
        CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(buffer);
        if (fmt) {
            const uint8_t *sps = NULL, *pps = NULL;
            size_t spsLen = 0, ppsLen = 0, count = 0;
            int32_t nalLen = 0;
            if (CMVideoFormatDescriptionGetH264ParameterSetAtIndex(fmt, 0, &sps, &spsLen,
                                                                   &count, &nalLen) == noErr && sps) {
                uint8_t sc[4] = {0, 0, 0, 1};
                [out appendBytes:sc length:4];
                [out appendBytes:sps length:spsLen];
            }
            if (CMVideoFormatDescriptionGetH264ParameterSetAtIndex(fmt, 1, &pps, &ppsLen,
                                                                   &count, &nalLen) == noErr && pps) {
                uint8_t sc[4] = {0, 0, 0, 1};
                [out appendBytes:sc length:4];
                [out appendBytes:pps length:ppsLen];
            }
        }
    }

    CMBlockBufferRef block = CMSampleBufferGetDataBuffer(buffer);
    if (!block) return;
    size_t total = CMBlockBufferGetDataLength(block);
    uint8_t *raw = malloc(total);
    if (!raw) return;
    CMBlockBufferCopyDataBytes(block, 0, total, raw);

    // AVCC（4 字节长度前缀）-> Annex-B（00 00 00 01）
    size_t off = 0;
    while (off + 4 <= total) {
        uint32_t n = 0;
        memcpy(&n, raw + off, 4);
        n = ntohl(n);
        off += 4;
        if (off + n > total) break;
        uint8_t sc[4] = {0, 0, 0, 1};
        [out appendBytes:sc length:4];
        [out appendBytes:raw + off length:n];
        off += n;
    }
    free(raw);

    if (out.length > 0 && [self.delegate respondsToSelector:@selector(encoderDidOutputAnnexB:keyframe:)]) {
        [self.delegate encoderDidOutputAnnexB:out keyframe:keyframe];
    }
}

- (void)encode:(CMSampleBufferRef)sample {
    if (!_session) { return; }
    if (!sample) { YLog(@"encode: sample nil"); return; }
    // 关键：VideoToolbox 要的是 CVImageBufferRef，不是 CMSampleBufferRef
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sample);
    if (!pixelBuffer) { YLog(@"encode: no pixelBuffer"); return; }

    CMTime pts = CMSampleBufferGetPresentationTimeStamp(sample);
    VTEncodeInfoFlags flags = 0;
    VTCompressionSessionEncodeFrame(_session, pixelBuffer, pts, kCMTimeInvalid,
                                    NULL, NULL, &flags);
}

- (void)forceKeyframe {
    if (!_session) return;
    // 旧 SDK 没有 kVTCompressionPropertyKey_ForceKeyFrame 常量，直接用字符串键
    VTSessionSetProperty(_session, CFSTR("ForceKeyFrame"), kCFBooleanTrue);
}
@end

@implementation Encoder (PixelBuffer)
- (void)encodePixelBuffer:(CVImageBufferRef)pb pts:(CFTimeInterval)pts {
    if (!_session || !pb) return;
    CMTime t = CMTimeMakeWithSeconds(pts, 600);
    VTEncodeInfoFlags flags = 0;
    VTCompressionSessionEncodeFrame(_session, pb, t, kCMTimeInvalid, NULL, NULL, &flags);
}
@end
