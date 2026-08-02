//
//  Constants.h
//  Ares2ToolBox
//
//  iOS端Ares2存档编辑器 - 全局常量定义
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Constants : NSObject

// 加密密钥
+ (NSDictionary<NSString *, NSString *> *)encryptKeys;

// 文档目录下的保存目录
+ (NSString *)saveDirectory;

// 允许的工人列表
+ (NSDictionary<NSNumber *, NSString *> *)allowedWorkers;

// 哈士奇ID
+ (NSInteger)huskyID;

// 数据库表名
+ (NSString *)tableWorker;
+ (NSString *)tableHire;

// 物品分类名称
+ (NSArray<NSString *> *)itemCategories;

// 加密标记
+ (NSData *)encryptionMarker;

@end

NS_ASSUME_NONNULL_END
