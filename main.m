#import <UIKit/UIKit.h>
#import "Capture.h"
#import "Encoder.h"
#import "WsClient.h"
#import "YLog.h"

static NSString *const kHost = @"192.168.1.42";   // PC 地址
static const int kVideoPort = 42400;
static const int kControlPort = 10001;

static WsClient *gCtrl = nil;   // 控制/日志通道

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

    YLog(@"viewDidLoad begin");
    @try {
        _ws = [[WsClient alloc] initWithURL:[NSURL URLWithString:
              [NSString stringWithFormat:@"ws://%@:%d/", kHost, kVideoPort]]];
        YLog(@"video client created");
    } @catch (NSException *e) {
        YLog(@"WS CREATE EXCEPTION: %@ | %@", e.name, e.reason);
    }

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
            YLog(@"apply config fps=%d bitrate=%d", weakSelf.fps, weakSelf.bitrate);
        } else if ([o[@"cmd"] isEqualToString:@"keyframe"]) {
            [weakSelf.encoder forceKeyframe];
        }
    };

    @try {
        [_ws connect];
        [_ws sendText:@"{\"cmd\":\"hello\",\"role\":\"device\",\"codec\":\"h264\"}"];
        YLog(@"video connect issued");
    } @catch (NSException *e) {
        YLog(@"WS CONNECT EXCEPTION: %@ | %@", e.name, e.reason);
    }

    // 控制通道：把设备日志实时发到 PC（PC 端 rp_ws.log 可见）
    @try {
        gCtrl = [[WsClient alloc] initWithURL:[NSURL URLWithString:
                 [NSString stringWithFormat:@"ws://%@:%d/", kHost, kControlPort]]];
        [gCtrl connect];
        YLog(@"control connect issued");
    } @catch (NSException *e) {
        YLog(@"CTRL EXCEPTION: %@ | %@", e.name, e.reason);
    }
    YLogSetSink(^(NSString *line) {
        NSDictionary *o = @{@"cmd": @"log", @"msg": line};
        NSData *d = [NSJSONSerialization dataWithJSONObject:o options:0 error:nil];
        @try {
            @try {
            NSString *json = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
            [gCtrl sendText:json];
        } @catch (NSException *e) { }
        } @catch (NSException *e) { }
    });

    @try {
        _capture = [Capture new];
        _capture.delegate = self;
        [_capture start];
        YLog(@"capture start issued");
    } @catch (NSException *e) {
        YLog(@"CAPTURE EXCEPTION: %@ | %@", e.name, e.reason);
    }
    _status.text = [NSString stringWithFormat:@"推流中 → ws://%@:%d", kHost, kVideoPort];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        YLog(@"app launched, video=%@:%d control=%@:%d",
             kHost, kVideoPort, kHost, kControlPort);
    });
}

- (void)capturePixelBuffer:(CVPixelBufferRef)pb pts:(CFTimeInterval)pts {
    size_t w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb);
    if (!_encoder || w != (size_t)_videoSize.width || h != (size_t)_videoSize.height) {
        _videoSize = CGSizeMake(w, h);
        _encoder = [[Encoder alloc] initWithSize:_videoSize fps:_fps bitrate:_bitrate];
        _encoder.delegate = self;
    }
    [_encoder encodePixelBuffer:pb pts:pts];
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
    @try {
        YLog(@"didFinishLaunching");
        self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.window.rootViewController = [RootVC new];
        [self.window makeKeyAndVisible];
        YLog(@"window visible");
    } @catch (NSException *e) {
        YLog(@"LAUNCH EXCEPTION: %@ | %@", e.name, e.reason);
    }
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        YLog(@"=== boot === uid=%d home=%@", getuid(), NSHomeDirectory());
        return UIApplicationMain(argc, argv, nil, @"AppDelegate");
    }
}
