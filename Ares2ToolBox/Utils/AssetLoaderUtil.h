//
//  AssetLoaderUtil.h
//  Ares2ToolBox
//
//  资源加载工具 - 从Bundle中加载游戏数据文件
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AssetLoaderUtil : NSObject

/// 加载地图名称映射
+ (NSDictionary<NSNumber *, NSString *> *)loadMapNames;

/// 加载天赋数据
+ (NSArray<NSDictionary *> *)loadTalentData;

/// 加载物品ID数据
+ (NSDictionary<NSNumber *, NSString *> *)loadItemNames;

/// 加载已分类物品ID
+ (NSDictionary<NSString *, NSArray<NSDictionary *> *> *)loadCategorizedItems;

/// 根据物品ID获取物品名称
+ (NSString *)itemNameForId:(NSInteger)itemId;

/// 根据地图ID获取地图名称
+ (NSString *)mapNameForId:(NSInteger)mapId;

@end

NS_ASSUME_NONNULL_END
