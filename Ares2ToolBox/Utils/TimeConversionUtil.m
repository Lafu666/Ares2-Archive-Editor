//
//  TimeConversionUtil.m
//  Ares2ToolBox
//

#import "TimeConversionUtil.h"

// .NET ticks从0001-01-01开始，每100纳秒一个tick
// Unix epoch从1970-01-01开始
static const int64_t kTicksAt1970 = 621355968000000000LL; // 1970-01-01的.NET ticks
static const int64_t kTicksPerSecond = 10000000LL;

@implementation TimeConversionUtil

+ (NSDate *)dateFromNetTicks:(int64_t)ticks {
    // 转换为Unix时间戳（秒）
    int64_t secondsSince1970 = (ticks - kTicksAt1970) / kTicksPerSecond;
    return [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)secondsSince1970];
}

+ (int64_t)netTicksFromDate:(NSDate *)date {
    NSTimeInterval secondsSince1970 = [date timeIntervalSince1970];
    return kTicksAt1970 + (int64_t)(secondsSince1970 * kTicksPerSecond);
}

+ (NSDateComponents *)componentsFromNetTicks:(int64_t)ticks {
    NSDate *date = [self dateFromNetTicks:ticks];
    return [[NSCalendar currentCalendar] components:
            NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay |
            NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond
                                           fromDate:date];
}

+ (int64_t)netTicksFromYear:(NSInteger)year
                      month:(NSInteger)month
                        day:(NSInteger)day
                       hour:(NSInteger)hour
                     minute:(NSInteger)minute
                     second:(NSInteger)second {
    NSDateComponents *comps = [[NSDateComponents alloc] init];
    comps.year = year;
    comps.month = month;
    comps.day = day;
    comps.hour = hour;
    comps.minute = minute;
    comps.second = second;

    NSDate *date = [[NSCalendar currentCalendar] dateFromComponents:comps];
    return [self netTicksFromDate:date];
}

@end