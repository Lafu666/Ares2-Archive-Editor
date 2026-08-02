//
//  FileProcessor.h
//  Ares2ToolBox
//
//  文件加解密处理器 - 处理存档ZIP的解压/加密/重新打包
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^FPProgressBlock)(NSInteger progress, NSString *message);
typedef void (^FPCompletionBlock)(BOOL success, NSString * _Nullable resultPath, NSString * _Nullable errorMessage);

@interface FileProcessor : NSObject

/// 当前解密的数据库路径
@property (nonatomic, copy, readonly, nullable) NSString *decryptedDbPath;

/// 临时目录路径（用于导出）
@property (nonatomic, copy, readonly, nullable) NSString *tempDirPath;

/// 处理存档文件：解压ZIP -> 找到GameWorld.db -> 解密
- (void)processFile:(NSString *)inputPath
          outputDir:(NSString *)outputDir
           progress:(FPProgressBlock)progress
         completion:(FPCompletionBlock)completion;

/// 导出处理：重新加密数据库 -> 打包ZIP -> 清理临时文件
- (void)finishExportWithTempDir:(NSString *)tempDirPath
                     outputPath:(NSString *)outputPath
                       progress:(FPProgressBlock)progress
                     completion:(FPCompletionBlock)completion;

/// 处理并导出存档（一步完成）
- (void)processAndExport:(NSString *)inputPath
          currentDbPath:(NSString *)currentDbPath
         userFolderName:(NSString *)userFolderName
               progress:(FPProgressBlock)progress
             completion:(FPCompletionBlock)completion;

/// 清理临时文件
- (void)cleanup;

/// 计算文件MD5
- (NSString *)calculateMD5:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END