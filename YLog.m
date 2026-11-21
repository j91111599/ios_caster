#import "YLog.h"

static void (^gSink)(NSString *line) = nil;

void YLogSetSink(void (^sink)(NSString *line)) {
    gSink = [sink copy];
}

void YLog(NSString *fmt, ...) {
    @try {
        va_list ap;
        va_start(ap, fmt);
        NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
        va_end(ap);

        NSLog(@"[YKC] %@", msg);

        if (gSink) {
            NSDateFormatter *df = [NSDateFormatter new];
            df.dateFormat = @"HH:mm:ss.SSS";
            NSString *line = [NSString stringWithFormat:@"%@ %@",
                              [df stringFromDate:[NSDate date]], msg];
            gSink(line);
        }
    } @catch (NSException *e) {
        NSLog(@"[YKC] log failed: %@", e.reason);
    }
}
