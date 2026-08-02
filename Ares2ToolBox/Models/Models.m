//
//  Models.m
//  Ares2ToolBox
//

#import "Models.h"

@implementation TreeNode
- (instancetype)init {
    self = [super init];
    if (self) {
        _children = [NSMutableArray array];
        _expanded = NO;
    }
    return self;
}
@end

@implementation WorkerInfo
@end

@implementation MapInfo
@end

@implementation TalentInfo
@end

@implementation FurnitureInfo
@end

@implementation ItemInfo
@end