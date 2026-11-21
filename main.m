#import <UIKit/UIKit.h>
#import "Capture.h"
#import "Encoder.h"
#import "WsClient.h"

static NSString *const kHost = @"192.168.1.42";   // PC 地址
static const int kVideoPort = 10000;

@interface RootVC : UIViewController <CaptureDelegate, EncoderDelegate>
@property (nonatomic, strong) Capture *capture;
@property (nonatomic, strong) Encoder *encoder;
@property (nonatomic, strong) WsClient *ws;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, assign) int fps;
@property (nonatomic, assign) int bitrate;
@property (nonatomic, assign) CGSize videoSize;
@end

@implementation RootVC

- (void)viewDidLoad {
    [super viewDidLoad];
    _fps = 30;
    _bitrate = 4000000;
    self.view.backgroundColor = [UIColor blackColor];
    _status = [[UILabel alloc] initWithFrame:self.view.bounds];
    _status.textAlignment = NSTextAlignmentCenter;
    _status.textColor = [UIColor whiteColor];
    _status.numberOfLines = 0;
    _status.text = @"准备中…";
    [self.view addSubview:_status];

    _ws = [[WsClient alloc] initWithURL:[NSURL URLWithString:
          [NSString stringWithFormat:@"ws://%@:%d/", kHost, kVideoPort]]];

    __weak typeof(self) weakSelf = self;
    _ws.onText = ^(NSString *text) {
        NSData *d = [text dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *o = [NSJSONSerialization JSONObjectWithData:d options:0 error:nil];
        if (![o isKindOfClass:[NSDictionary class]]) return;
        if ([o[@"cmd"] isEqualToString:@"config"]) {
            if (o[@"fps"]) weakSelf.fps = [o[@"fps"] intValue];
            if (o[@"bitrate"]) weakSelf.bitrate = [o[@"bitrate"] intValue];
            // 重建编码器以应用新参数
            weakSelf.encoder = nil;
            weakSelf.status.text = [NSString stringWithFormat:
                @"推流中 %dfps %.1fMbps → %@", weakSelf.fps, weakSelf.bitrate / 1e6, kHost];
            NSLog(@"[YKCaster] apply config fps=%d bitrate=%d", weakSelf.fps, weakSelf.bitrate);
        } else if ([o[@"cmd"] isEqualToString:@"keyframe"]) {
            [weakSelf.encoder forceKeyframe];
        }
    };

    [_ws connect];
    [_ws sendText:@"{\"cmd\":\"hello\",\"role\":\"device\",\"codec\":\"h264\"}"];

    _capture = [Capture new];
    _capture.delegate = self;
    [_capture start];
    _status.text = [NSString stringWithFormat:@"推流中 → ws://%@:%d", kHost, kVideoPort];
}

- (void)captureDidOutput:(CMSampleBufferRef)sample {
    CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(sample);
    CMVideoDimensions dim = CMVideoFormatDescriptionGetDimensions(fmt);
    if (!_encoder || dim.width != _videoSize.width || dim.height != _videoSize.height) {
        _videoSize = CGSizeMake(dim.width, dim.height);
        _encoder = [[Encoder alloc] initWithSize:_videoSize fps:_fps bitrate:_bitrate];
        _encoder.delegate = self;
    }
    [_encoder encode:sample];
}

- (void)encoderDidOutputAnnexB:(NSData *)data keyframe:(BOOL)keyframe {
    [_ws sendData:data];
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [RootVC new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, @"AppDelegate");
    }
}
