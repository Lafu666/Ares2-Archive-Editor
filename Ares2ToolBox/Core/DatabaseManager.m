//
//  DatabaseManager.m
//  Ares2ToolBox
//
//  SQLite数据库管理器实现
//

#import "DatabaseManager.h"
#import <sqlite3.h>

@implementation DBSearchResult
@end

@interface DatabaseManager () {
    sqlite3 *_database;
}
@property (nonatomic, copy) NSString *dbPath;
@property (nonatomic, copy) NSString *currentTable;
@property (nonatomic, strong) NSMutableArray<NSString *> *tableNames;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<NSString *> *> *tableColumns;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSArray<NSString *> *> *notNullColumns;
@end

@implementation DatabaseManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _tableNames = [NSMutableArray array];
        _tableColumns = [NSMutableDictionary dictionary];
        _notNullColumns = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)dealloc {
    [self closeDatabase];
}

#pragma mark - Database Operations

- (BOOL)openDatabase:(NSString *)dbPath {
    [self closeDatabase];
    self.dbPath = dbPath;

    int rc = sqlite3_open([dbPath UTF8String], &_database);
    if (rc != SQLITE_OK) {
        NSLog(@"无法打开数据库: %s", sqlite3_errmsg(_database));
        return NO;
    }

    // 启用WAL模式提升性能
    sqlite3_exec(_database, "PRAGMA journal_mode=WAL", NULL, NULL, NULL);
    return YES;
}

- (void)closeDatabase {
    if (_database) {
        sqlite3_close(_database);
        _database = NULL;
    }
    [self.tableNames removeAllObjects];
    [self.tableColumns removeAllObjects];
    [self.notNullColumns removeAllObjects];
    self.currentTable = nil;
}

- (void)loadAllTableNames {
    [self.tableNames removeAllObjects];

    sqlite3_stmt *stmt;
    const char *sql = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name";
    if (sqlite3_prepare_v2(_database, sql, -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            const char *name = (const char *)sqlite3_column_text(stmt, 0);
            if (name) {
                [self.tableNames addObject:[NSString stringWithUTF8String:name]];
            }
        }
        sqlite3_finalize(stmt);
    }
}

- (void)loadTableColumnInfo:(NSString *)tableName {
    NSMutableArray *columns = [NSMutableArray array];
    NSMutableArray *notNulls = [NSMutableArray array];

    NSString *pragmaSQL = [NSString stringWithFormat:@"PRAGMA table_info(%@)", tableName];
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_database, [pragmaSQL UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            const char *colName = (const char *)sqlite3_column_text(stmt, 1);
            const char *colType = (const char *)sqlite3_column_text(stmt, 2);
            int notNull = sqlite3_column_int(stmt, 3);

            if (colName && colType) {
                NSString *typeStr = [NSString stringWithUTF8String:colType];
                if (![typeStr caseInsensitiveCompare:@"BLOB"] == NSOrderedSame) {
                    [columns addObject:[NSString stringWithUTF8String:colName]];
                }
            }
            if (notNull == 1 && colName) {
                [notNulls addObject:[NSString stringWithUTF8String:colName]];
            }
        }
        sqlite3_finalize(stmt);
    }

    self.tableColumns[tableName] = [columns copy];
    self.notNullColumns[tableName] = [notNulls copy];
}

- (NSArray<NSDictionary *> *)loadTableData:(NSString *)tableName {
    if (!_database || !tableName) return nil;

    NSArray *columns = self.tableColumns[tableName];
    if (!columns || columns.count == 0) return nil;

    NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT rowid AS _id"];
    for (NSString *col in columns) {
        [query appendFormat:@", %@", col];
    }
    [query appendFormat:@" FROM %@ ORDER BY rowid", tableName];

    NSMutableArray *rows = [NSMutableArray array];
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_database, [query UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            NSMutableDictionary *row = [NSMutableDictionary dictionary];
            int colCount = sqlite3_column_count(stmt);
            for (int i = 0; i < colCount; i++) {
                const char *name = sqlite3_column_name(stmt, i);
                const char *text = (const char *)sqlite3_column_text(stmt, i);
                if (name) {
                    NSString *key = [NSString stringWithUTF8String:name];
                    NSString *value = text ? [NSString stringWithUTF8String:text] : @"";
                    row[key] = value;
                }
            }
            [rows addObject:row];
        }
        sqlite3_finalize(stmt);
    }
    return [rows copy];
}

- (BOOL)updateCellInTable:(NSString *)tableName
                    rowId:(NSInteger)rowId
               columnName:(NSString *)columnName
                    value:(NSString *)value {
    if (!_database) return NO;

    NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ = ? WHERE rowid = ?", tableName, columnName];
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(_database, [sql UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
        sqlite3_bind_text(stmt, 1, [value UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(stmt, 2, rowId);
        int rc = sqlite3_step(stmt);
        sqlite3_finalize(stmt);
        return rc == SQLITE_DONE;
    }
    return NO;
}

- (NSInteger)addRows:(NSInteger)count toTable:(NSString *)tableName {
    if (!_database) return 0;

    NSArray *columns = self.tableColumns[tableName];
    if (!columns) return 0;

    sqlite3_exec(_database, "BEGIN TRANSACTION", NULL, NULL, NULL);

    NSInteger successCount = 0;
    NSMutableString *sql = [NSMutableString stringWithFormat:@"INSERT INTO %@ DEFAULT VALUES", tableName];

    for (NSInteger i = 0; i < count; i++) {
        char *errMsg = NULL;
        int rc = sqlite3_exec(_database, [sql UTF8String], NULL, NULL, &errMsg);
        if (rc == SQLITE_OK) {
            successCount++;
        } else {
            if (errMsg) sqlite3_free(errMsg);
        }
    }

    sqlite3_exec(_database, "COMMIT", NULL, NULL, NULL);
    return successCount;
}

- (NSInteger)deleteRows:(NSInteger)count fromTable:(NSString *)tableName {
    if (!_database || !tableName) return 0;

    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE rowid IN (SELECT rowid FROM %@ ORDER BY rowid DESC LIMIT %ld)",
                     tableName, tableName, (long)count];

    char *errMsg = NULL;
    int rc = sqlite3_exec(_database, [sql UTF8String], NULL, NULL, &errMsg);
    if (errMsg) sqlite3_free(errMsg);

    return rc == SQLITE_OK ? sqlite3_changes(_database) : 0;
}

- (BOOL)deleteRowById:(NSInteger)rowId fromTable:(NSString *)tableName {
    if (!_database) return NO;

    NSString *sql = [NSString stringWithFormat:@"DELETE FROM %@ WHERE rowid = %ld", tableName, (long)rowId];
    char *errMsg = NULL;
    int rc = sqlite3_exec(_database, [sql UTF8String], NULL, NULL, &errMsg);
    if (errMsg) sqlite3_free(errMsg);
    return rc == SQLITE_OK;
}

- (void)searchAllTables:(NSString *)keyword
               progress:(DBSearchProgressBlock)progress
             completion:(DBSearchCompletionBlock)completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *results = [NSMutableArray array];
        NSInteger totalFound = 0;

        // 确保已加载表信息
        if (self.tableNames.count == 0) {
            [self loadAllTableNames];
        }

        for (NSString *table in self.tableNames) {
            if ([table hasPrefix:@"sqlite_"]) continue;

            NSArray *columns = self.tableColumns[table];
            if (!columns || columns.count == 0) {
                [self loadTableColumnInfo:table];
                columns = self.tableColumns[table];
            }
            if (!columns || columns.count == 0) continue;

            dispatch_async(dispatch_get_main_queue(), ^{
                if (progress) progress(table, totalFound);
            });

            // 构建查询
            NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT rowid"];
            for (NSString *col in columns) {
                [query appendFormat:@", %@", col];
            }
            [query appendFormat:@" FROM %@ ORDER BY rowid", table];

            sqlite3_stmt *stmt;
            if (sqlite3_prepare_v2(_database, [query UTF8String], -1, &stmt, NULL) == SQLITE_OK) {
                while (sqlite3_step(stmt) == SQLITE_ROW) {
                    for (NSInteger colIdx = 0; colIdx < (NSInteger)columns.count; colIdx++) {
                        const char *text = (const char *)sqlite3_column_text(stmt, (int)(colIdx + 1));
                        if (text) {
                            NSString *value = [NSString stringWithUTF8String:text];
                            if ([value rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
                                DBSearchResult *result = [[DBSearchResult alloc] init];
                                result.tableName = table;
                                result.rowId = sqlite3_column_int64(stmt, 0);
                                result.columnName = columns[colIdx];
                                result.matchedText = value;
                                result.rowPosition = totalFound;
                                result.columnIndex = colIdx;
                                [results addObject:result];
                                totalFound++;
                            }
                        }
                    }
                }
                sqlite3_finalize(stmt);
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([results copy]);
        });
    });
}

- (NSString *)getUserId {
    if (!_database) return nil;

    sqlite3_stmt *stmt;
    const char *sql = "SELECT UserID FROM DBData LIMIT 1";
    if (sqlite3_prepare_v2(_database, sql, -1, &stmt, NULL) == SQLITE_OK) {
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            const char *text = (const char *)sqlite3_column_text(stmt, 0);
            sqlite3_finalize(stmt);
            return text ? [NSString stringWithUTF8String:text] : nil;
        }
        sqlite3_finalize(stmt);
    }
    return nil;
}

@end