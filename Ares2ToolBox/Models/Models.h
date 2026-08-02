//
//  Utility models for Ares2ToolBox
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - TreeNode

@interface TreeNode : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger type; // 0=folder, 1=zip, 2=db, 3=table
@property (nonatomic, strong) NSMutableArray<TreeNode *> *children;
@property (nonatomic, assign) BOOL expanded;
@property (nonatomic, weak, nullable) TreeNode *parent;
@end

#pragma mark - WorkerInfo

@interface WorkerInfo : NSObject
@property (nonatomic, assign) NSInteger workerId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) BOOL selected;
@end

#pragma mark - MapInfo

@interface MapInfo : NSObject
@property (nonatomic, assign) NSInteger mapId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) BOOL arrived;
@property (nonatomic, assign) BOOL owned;
@property (nonatomic, assign) BOOL refreshed;
@property (nonatomic, strong, nullable) NSDate *arrivalTime;
@end

#pragma mark - TalentInfo

@interface TalentInfo : NSObject
@property (nonatomic, assign) NSInteger talentId;
@property (nonatomic, assign) NSInteger level;
@property (nonatomic, copy) NSString *desc;
@property (nonatomic, assign) BOOL selected;
@end

#pragma mark - FurnitureInfo

@interface FurnitureInfo : NSObject
@property (nonatomic, assign) NSInteger furnitureId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSInteger position;
@property (nonatomic, copy) NSString *positionDesc;
@end

#pragma mark - ItemInfo

@interface ItemInfo : NSObject
@property (nonatomic, assign) NSInteger itemId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, assign) NSInteger quantity;
@end

NS_ASSUME_NONNULL_END
