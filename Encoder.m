#import "Encoder.h"
#import <VideoToolbox/VideoToolbox.h>

@implementation Encoder {
    VTCompressionSessionRef _session;
    int _fps;
}

- (instancetype)initWithSize:(CGSize)size fps:(int)fps bitrate:(int)bitrate {
    if ((self = [super init])) {
        _fps = fps;
        NSDictionary *spec = @{
            (id)kVTCompressionPropertyKey_RealTime: @YES,
            (id)kVTCompressionPropertyKey_ProfileLevel: (id)kVTProfileLevel_H264_Baseline_AutoLevel,
            (id)kVTCompressionPropertyKey_AllowFrameReordering: @NO,
            (id)kVTCompressionPropertyKey_MaxKeyFrameInterval: @(fps),
            (id)kVTCompressionPropertyKey_AverageBitRate: @(bitrate),
        };
        VTCompressionSessionCreate(NULL, (int)size.width, (int)size.height,
                                   kCMVideoCodecType_H264, NULL,
                                   (__bridge CFDictionaryRef)spec, NULL,
                                   &_callback, (__bridge void *)self, &_session);
        VTSessionSetProperty(_session, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    }
    return self;
}

static void _callback(void *out, void *src, OSStatus status, VTEncodeInfoFlags flags,
                      CMSampleBufferRef buffer) {
    if (status != noErr || !buffer) return;
    Encoder *self = (__bridge Encoder *)src;
    [self handle:buffer];
}

- (void)handle:(CMSampleBufferRef)buffer {
    BOOL key = NO;
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, false);
    if (attachments && CFArrayGetCount(attachments) > 0) {
        CFDictionaryRef d = CFArrayGetValueAtIndex(attachments, 0);
        key = !CFDictionaryContainsKey(d, kCMSampleAttachmentKey_NotSync);
    }
    CMBlockBufferRef block = CMSampleBufferGetDataBuffer(buffer);
    size_t total = CMBlockBufferGetDataLength(block);
    NSMutableData *out = [NSMutableData dataWithCapacity:total + 64];
    // 关键帧前置 SPS/PPS（Annex-B）
    if (key) {
        CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(buffer);
        size_t count = 0, len = 0; const uint8_t *ptr = NULL;
        for (int i = 0; i < 2; i++) {
            if (CMVideoFormatDescriptionGetH264ParameterSetAtIndex(fmt, i, &ptr, &len, &count, NULL) == noErr) {
                uint8_t sc[4] = {0, 0, 0, 1};
                [out appendBytes:sc length:4];
                [out appendBytes:ptr length:len];
            }
        }
    }
    uint8_t *raw = malloc(total);
    CMBlockBufferCopyDataBytes(block, 0, total, raw);
    // AVCC 长度前缀 -> Annex-B
    size_t off = 0;
    while (off + 4 <= total) {
        uint32_t n = 0;
        memcpy(&n, raw + off, 4); n = ntohl(n);
        off += 4;
        if (off + n > total) break;
        uint8_t sc[4] = {0, 0, 0, 1};
        [out appendBytes:sc length:4];
        [out appendBytes:raw + off length:n];
        off += n;
    }
    free(raw);
    [self.delegate encoderDidOutputAnnexB:out keyframe:key];
}

- (void)encode:(CMSampleBufferRef)sample {
    if (!_session) return;
    VTEncodeInfoFlags flags;
    VTCompressionSessionEncodeFrame(_session, sample, kCMTimeInvalid, kCMTimeInvalid,
                                   NULL, NULL, &flags);
}

- (void)forceKeyframe {
    if (_session)
        VTSessionSetProperty(_session, kVTCompressionPropertyKey_ForceKeyFrame, kCFBooleanTrue);
}

@end
