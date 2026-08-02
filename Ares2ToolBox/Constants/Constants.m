//
//  Constants.m
//  Ares2ToolBox
//

#import "Constants.h"

@implementation Constants

+ (NSDictionary<NSString *, NSString *> *)encryptKeys {
    static NSDictionary *keys = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = @{
            @"db": @"zqgzs2017pheeki$%$%#",
            @"assetbundle": @"zqgzs2017^%#$%$#fkahsd",
            @"sqlite": @"z2q0y1x7gzs"
        };
    });
    return keys;
}

+ (NSString *)saveDirectory {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docsDir = [paths firstObject];
    return [docsDir stringByAppendingPathComponent:@"存档目录"];
}

+ (NSDictionary<NSNumber *, NSString *> *)allowedWorkers {
    static NSDictionary *workers = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        workers = @{
            @5101: @"[商人]许掌柜",
            @5102: @"[商人]齐掌柜",
            @5103: @"[商人]银狐",
            @5201: @"[伐木工]柴堪",
            @5202: @"[伐木工]叶有材",
            @5203: @"[伐木工]徐大斧",
            @5204: @"[伐木工]乔木",
            @5301: @"[硝石工]隋大石",
            @5302: @"[硝石工]杨石广",
            @5303: @"[铁矿工]班专",
            @5304: @"[铁矿工]洪大力",
            @6001: @"[战士]铁锤",
            @6002: @"[战士]宋远弓",
            @6003: @"[战士]岳大刀",
            @6004: @"[战士]林金枪",
            @6005: @"[战士]常木昆",
            @6101: @"[S.O.T] 尼奥",
            @6102: @"[S.O.T] K",
            @6105: @"超级战士",
            @6106: @"[受伤] K",
            @6201: @"[战士]虎哥",
            @6205: @"田营生",
            @6990: @"老吴",
            @20200132: @"阿蔡",
            @20200758: @"姜娜",
            @20220622: @"尼奥",
            @20220630: @"K"
        };
    });
    return workers;
}

+ (NSInteger)huskyID {
    return 2112;
}

+ (NSString *)tableWorker {
    return @"Worker";
}

+ (NSString *)tableHire {
    return @"Hire";
}

+ (NSArray<NSString *> *)itemCategories {
    static NSArray *categories = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        categories = @[
            @"全部物品", @"普通物资", @"BOSS掉落物", @"诱饵", @"养殖",
            @"工具", @"食物", @"子弹", @"成就物品", @"剧情物品",
            @"藏宝图", @"战利品", @"装修物品", @"武器", @"消耗品",
            @"武器配件", @"护具装备", @"地图", @"情报", @"蓝图模具图纸",
            @"家装修", @"出租房装修", @"配件", @"鱼类"
        ];
    });
    return categories;
}

+ (NSData *)encryptionMarker {
    static NSData *marker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        char bytes[] = {'%', '$', '@', '3', '^'};
        marker = [NSData dataWithBytes:bytes length:5];
    });
    return marker;
}

@end