//
//  DatabaseManager.h
//  Ares2ToolBox
//
//  SQLite数据库管理器 - 封装FMDatabase操作
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class DatabaseManager;

typedef void (^DBSearchProgressBlock)(NSString *tableName, NSInteger foundCount);
typedef void (^DBSearchCompletionBlock)(NSArray<NSDictionary *> *results);

@interface DBSearchResult : NSObject
@property (nonatomic, copy) NSString *tableName;
@property (nonatomic, assign) NSInteger rowId;
@property (nonatomic, copy) NSString *columnName;
@property (nonatomic, copy) NSString *matchedText;
@property (nonatomic, assign) NSInteger rowPosition;
@property (nonatomic, assign) NSInteger columnIndex;
@end

@interface DatabaseManager : NSObject

@property (nonatomic, readonly, nullable) NSString *currentTable;
@property (nonatomic, readonly) NSArray<NSString *> *tableNames;
@property (nonatomic, readonly) NSDictionary<NSString *, NSArray<NSString *> *> *tableColumns;

/// 打开数据库
- (BOOL)openDatabase:(NSString *)dbPath;

/// 关闭数据库
- (void)closeDatabase;

/// 加载所有表名
- (void)loadAllTableNames;

/// 加载表的列信息
- (void)loadTableColumnInfo:(NSString *)tableName;

/// 加载表数据
- (nullable NSArray<NSDictionary *> *)loadTableData:(NSString *)tableName;

/// 更新单元格值
- (BOOL)updateCellInTable:(NSString *)tableName
                    rowId:(NSInteger)rowId
               columnName:(NSString *)columnName
                    value:(NSString *)value;

/// 添加行
- (NSInteger)addRows:(NSInteger)count toTable:(NSString *)tableName;

/// 删除行
- (NSInteger)deleteRows:(NSInteger)count fromTable:(NSString *)tableName;

/// 删除指定行
- (BOOL)deleteRowById:(NSInteger)rowId fromTable:(NSString *)tableName;

/// 全局搜索
- (void)searchAllTables:(NSString *)keyword
               progress:(DBSearchProgressBlock)progress
             completion:(DBSearchCompletionBlock)completion;

/// 获取UserID
- (nullable NSString *)getUserId;

@end

NS_ASSUME_NONNULL_END
