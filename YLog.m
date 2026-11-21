#import "YLog.h"

static void (^gSink)(NSString *line) = nil;

void YLogSetSink(void (^sink)(NSString *line)) {
    gSink = [sink copy];
}

void YLog(NSString *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:ap];
    va_end(ap);

    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"HH:mm:ss.SSS";
    NSString *line = [NSString stringWithFormat:@"%@ %@", [df stringFromDate:[NSDate date]], msg];

    NSLog(@"[YKC] %@", msg);

    if (gSink) {
        gSink(line);
    }

    // 顺带尝试写文件（失败也不影响）
    static NSFileHandle *fh = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *path = @"/var/mobile/Media/ykc.log";
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        fh = [NSFileHandle fileHandleForWritingAtPath:path];
        [fh seekToEndOfFile];
    });
    if (fh) {
        @try { [fh writeData:[[line stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]]; }
        @catch (NSException *e) { }
    }
}
