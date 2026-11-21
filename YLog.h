#import <Foundation/Foundation.h>

void YLog(NSString *fmt, ...);
void YLogSetSink(void (^sink)(NSString *line));
