#import "YLog.h"
#import <stdio.h>

static void (^gSink)(NSString *line) = nil;

void YLogSetSink(void (^sink)(NSString *line)) {
    gSink = [sink copy];
}

void YLog(NSString *fmt, ...) {
    NSString *msg = nil;
    @try {
        va_list ap;
        va_start(ap, fmt);
        msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
        va_end(ap);
    } @catch (NSException *e) {
        return;
    }
    if (!msg) return;

    NSLog(@"[YKC] %@", msg);

    // C 级追加写：fopen 失败只返回 NULL，不会抛 ObjC 异常
    @try {
        FILE *f = fopen("/var/mobile/Media/ykc.log", "a");
        if (f) {
            fprintf(f, "%s\n", msg.UTF8String);
            fclose(f);
        }
    } @catch (NSException *e) { }

    if (gSink) {
        @try {
            NSDateFormatter *df = [NSDateFormatter new];
            df.dateFormat = @"HH:mm:ss.SSS";
            gSink([NSString stringWithFormat:@"%@ %@",
                   [df stringFromDate:[NSDate date]], msg]);
        } @catch (NSException *e) { }
    }
}
