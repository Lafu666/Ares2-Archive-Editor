//
//  AssetLoaderUtil.m
//  Ares2ToolBox
//

#import "AssetLoaderUtil.h"

@implementation AssetLoaderUtil

+ (NSDictionary<NSNumber *, NSString *> *)loadMapNames {
    static NSDictionary *mapNames = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"map_data" ofType:@"txt"];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (!content) return;

        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        NSArray *lines = [content componentsSeparatedByString:@"\n"];
        for (NSString *line in lines) {
            NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmed.length == 0) continue;
            NSArray *parts = [trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSMutableArray *filtered = [NSMutableArray array];
            for (NSString *p in parts) {
                if (p.length > 0) [filtered addObject:p];
            }
            if (filtered.count >= 2) {
                NSInteger mapId = [filtered[0] integerValue];
                NSString *name = filtered[1];
                dict[@(mapId)] = name;
            }
        }
        mapNames = [dict copy];
    });
    return mapNames;
}

+ (NSArray<NSDictionary *> *)loadTalentData {
    static NSArray *talents = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"talent_data" ofType:@"txt"];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (!content) return;

        NSMutableArray *arr = [NSMutableArray array];
        NSArray *lines = [content componentsSeparatedByString:@"\n"];
        for (NSString *line in lines) {
            NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmed.length == 0) continue;
            NSArray *parts = [trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSMutableArray *filtered = [NSMutableArray array];
            for (NSString *p in parts) {
                if (p.length > 0) [filtered addObject:p];
            }
            if (filtered.count >= 3) {
                NSInteger talentId = [filtered[0] integerValue];
                NSInteger level = [filtered[1] integerValue];
                // 剩余部分拼接为描述
                NSString *desc = [[filtered subarrayWithRange:NSMakeRange(2, filtered.count - 2)] componentsJoinedByString:@" "];
                [arr addObject:@{@"talentId": @(talentId), @"level": @(level), @"desc": desc}];
            }
        }
        talents = [arr copy];
    });
    return talents;
}

+ (NSDictionary<NSNumber *, NSString *> *)loadItemNames {
    static NSDictionary *items = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"item_ids" ofType:@"txt"];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (!content) return;

        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        NSArray *lines = [content componentsSeparatedByString:@"\n"];
        for (NSString *line in lines) {
            NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmed.length == 0) continue;
            NSArray *parts = [trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSMutableArray *filtered = [NSMutableArray array];
            for (NSString *p in parts) {
                if (p.length > 0) [filtered addObject:p];
            }
            if (filtered.count >= 2) {
                NSInteger itemId = [filtered[0] integerValue];
                NSString *name = filtered[1];
                dict[@(itemId)] = name;
            }
        }
        items = [dict copy];
    });
    return items;
}

+ (NSDictionary<NSString *, NSArray<NSDictionary *> *> *)loadCategorizedItems {
    static NSDictionary *categorized = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *path = [[NSBundle mainBundle] pathForResource:@"categorized_items" ofType:@"txt"];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (!content) return;

        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        NSString *currentCategory = nil;
        NSMutableArray *currentItems = nil;

        NSArray *lines = [content componentsSeparatedByString:@"\n"];
        for (NSString *line in lines) {
            NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmed.length == 0) continue;

            // 判断是否是分类标题（纯中文或带空格）
            NSArray *parts = [trimmed componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSMutableArray *filtered = [NSMutableArray array];
            for (NSString *p in parts) {
                if (p.length > 0) [filtered addObject:p];
            }

            if (filtered.count == 1 && ![[NSScanner scannerWithString:filtered[0]] scanInteger:nil]) {
                // 单列非数字，视为分类标题
                if (currentCategory && currentItems) {
                    dict[currentCategory] = [currentItems copy];
                }
                currentCategory = filtered[0];
                currentItems = [NSMutableArray array];
            } else if (filtered.count >= 2) {
                NSInteger itemId = [filtered[0] integerValue];
                NSString *name = filtered[1];
                if (currentItems) {
                    [currentItems addObject:@{@"id": @(itemId), @"name": name}];
                }
            }
        }
        if (currentCategory && currentItems) {
            dict[currentCategory] = [currentItems copy];
        }
        categorized = [dict copy];
    });
    return categorized;
}

+ (NSString *)itemNameForId:(NSInteger)itemId {
    NSDictionary *items = [self loadItemNames];
    return items[@(itemId)] ?: [NSString stringWithFormat:@"未知物品(%ld)", (long)itemId];
}

+ (NSString *)mapNameForId:(NSInteger)mapId {
    NSDictionary *maps = [self loadMapNames];
    return maps[@(mapId)] ?: [NSString stringWithFormat:@"未知地图(%ld)", (long)mapId];
}

@end