//
//  TimeConversionUtil.h
//  Ares2ToolBox
//
//  时间转换工具 - .NET Ticks与NSDate互转
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TimeConversionUtil : NSObject

/// .NET Ticks 转 NSDate
+ (NSDate *)dateFromNetTicks:(int64_t)ticks;

/// NSDate 转 .NET Ticks
+ (int64_t)netTicksFromDate:(NSDate *)date;

/// 解析.NET Ticks为时间分量
+ (NSDateComponents *)componentsFromNetTicks:(int64_t)ticks;

/// 从时间分量创建.NET Ticks
+ (int64_t)netTicksFromYear:(NSInteger)year
                      month:(NSInteger)month
                        day:(NSInteger)day
                       hour:(NSInteger)hour
                     minute:(NSInteger)minute
                     second:(NSInteger)second;

@end

NS_ASSUME_NONNULL_END