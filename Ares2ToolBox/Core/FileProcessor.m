//
//  FileProcessor.m
//  Ares2ToolBox
//
//  文件加解密处理器实现
//  XOR加密算法：使用加密标记(%$@3^) + XOR密钥字节流
//

#import "FileProcessor.h"
#import "Constants.h"
#import "minizip.h"
#import <CommonCrypto/CommonDigest.h>

@interface FileProcessor ()
@property (nonatomic, copy) NSString *tempDirPath;
@property (nonatomic, copy) NSString *tempDbPath;
@property (nonatomic, copy) NSString *decryptedDbPath;
@property (nonatomic, copy) NSString *originalZipPath;
@property (nonatomic, copy) NSString *outputDir;
@end

@implementation FileProcessor

#pragma mark - Public Methods

- (void)processFile:(NSString *)inputPath
          outputDir:(NSString *)outputDir
           progress:(FPProgressBlock)progress
         completion:(FPCompletionBlock)completion {
    self.originalZipPath = inputPath;
    self.outputDir = outputDir;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        @autoreleasepool {
            // 创建临时目录
            NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                 [NSString stringWithFormat:@"temp_zip_%lld", (long long)([[NSDate date] timeIntervalSince1970] * 1000)]];
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:tempDir
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:&error];
            if (error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, nil, @"创建临时目录失败");
                });
                return;
            }
            self.tempDirPath = tempDir;
            if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(10, @"创建临时目录成功"); });

            // 解压ZIP
            BOOL unzipSuccess = [self unzipFile:inputPath toDirectory:tempDir];
            if (!unzipSuccess) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, nil, @"解压ZIP文件失败");
                });
                return;
            }
            if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(30, @"解压ZIP文件完成"); });

            // 查找GameWorld.db
            NSString *dbPath = [self findGameWorldDbInDirectory:tempDir];
            if (!dbPath) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, nil, @"找不到GameWorld.db文件");
                });
                return;
            }
            self.tempDbPath = dbPath;
            if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(40, @"找到数据库文件"); });

            // 解密数据库
            NSString *key = [Constants encryptKeys][@"db"];
            NSData *dbData = [NSData dataWithContentsOfFile:dbPath];
            if (!dbData) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, nil, @"读取数据库文件失败");
                });
                return;
            }
            NSData *decrypted = [self decryptData:dbData withKey:key];
            if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(50, @"数据库解密完成"); });

            // 保存解密后的数据库
            NSString *decPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"decrypted.db"];
            [decrypted writeToFile:decPath atomically:YES];
            self.decryptedDbPath = decPath;
            if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(60, @"准备编辑环境"); });

            dispatch_async(dispatch_get_main_queue(), ^{
                completion(YES, decPath, @"存档已准备好，可以开始编辑");
            });
        }
    });
}

- (void)finishExportWithTempDir:(NSString *)tempDirPath
                     outputPath:(NSString *)outputPath
                       progress:(FPProgressBlock)progress
                     completion:(FPCompletionBlock)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        @autoreleasepool {
            if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(80, @"重新打包存档..."); });

            BOOL zipSuccess = [self zipFolder:tempDirPath toZip:outputPath];
            if (!zipSuccess) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(NO, nil, @"打包存档失败");
                });
                return;
            }

            if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(90, @"清理临时文件..."); });
            [self deleteFolder:tempDirPath];

            if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(100, @"导出完成"); });
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(YES, outputPath, nil);
            });
        }
    });
}

- (void)processAndExport:(NSString *)inputPath
          currentDbPath:(NSString *)currentDbPath
         userFolderName:(NSString *)userFolderName
               progress:(FPProgressBlock)progress
             completion:(FPCompletionBlock)completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        @autoreleasepool {
            // 创建临时目录
            NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:
                                 [NSString stringWithFormat:@"temp_export_%lld", (long long)([[NSDate date] timeIntervalSince1970] * 1000)]];
            [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];
            if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(10, @"创建临时目录成功"); });

            // 解压
            [self unzipFile:inputPath toDirectory:tempDir];
            if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(30, @"解压ZIP文件完成"); });

            // 查找数据库文件
            NSString *dbPath = [self findGameWorldDbInDirectory:tempDir];
            if (!dbPath) {
                dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, nil, @"找不到数据库文件"); });
                return;
            }
            if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(40, @"找到数据库文件"); });

            // 重命名存档文件夹
            NSString *archiveFolder = [dbPath stringByDeletingLastPathComponent];
            NSString *newArchiveFolder = [[archiveFolder stringByDeletingLastPathComponent] stringByAppendingPathComponent:userFolderName];
            [[NSFileManager defaultManager] moveItemAtPath:archiveFolder toPath:newArchiveFolder error:nil];
            if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(45, [NSString stringWithFormat:@"重命名存档文件夹为: %@", userFolderName]); });

            // 更新数据库文件路径
            dbPath = [newArchiveFolder stringByAppendingPathComponent:@"GameWorld.db"];

            // 加密并写入当前数据库
            if (currentDbPath && [[NSFileManager defaultManager] fileExistsAtPath:currentDbPath]) {
                NSData *currentDbData = [NSData dataWithContentsOfFile:currentDbPath];
                NSString *key = [Constants encryptKeys][@"db"];
                NSData *encrypted = [self encryptData:currentDbData withKey:key];
                [encrypted writeToFile:dbPath atomically:YES];
                if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(70, @"加密并应用当前修改完成"); });
            } else {
                if (progress) dispatch_async(dispatch_get_main_queue(), ^{ progress(70, @"没有修改的数据库，使用原始文件"); });
            }

            // 确保oss目录存在
            NSString *ossDir = [newArchiveFolder stringByAppendingPathComponent:@"oss"];
            [[NSFileManager defaultManager] createDirectoryAtPath:ossDir withIntermediateDirectories:YES attributes:nil error:nil];

            dispatch_async(dispatch_get_main_queue(), ^{
                completion(YES, tempDir, nil);
            });
        }
    });
}

- (void)cleanup {
    if (self.tempDirPath) {
        [self deleteFolder:self.tempDirPath];
    }
    if (self.decryptedDbPath) {
        [[NSFileManager defaultManager] removeItemAtPath:self.decryptedDbPath error:nil];
    }
}

- (NSString *)calculateMD5:(NSString *)filePath {
    NSData *data = [NSData dataWithContentsOfFile:filePath];
    if (!data) return nil;

    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data.bytes, (CC_LONG)data.length, digest);

    NSMutableString *md5String = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [md5String appendFormat:@"%02x", digest[i]];
    }
    return [md5String copy];
}

#pragma mark - Encryption/Decryption

- (NSData *)decryptData:(NSData *)data withKey:(NSString *)key {
    if (![self isEncrypted:data]) return data;

    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSData *marker = [Constants encryptionMarker];
    NSMutableData *result = [NSMutableData dataWithCapacity:data.length - marker.length];

    const uint8_t *keyBytes = keyData.bytes;
    NSUInteger keyLen = keyData.length;
    const uint8_t *dataBytes = data.bytes;

    NSUInteger keyIndex = 0;
    for (NSUInteger i = marker.length; i < data.length; i++) {
        uint8_t decrypted = dataBytes[i] ^ keyBytes[keyIndex];
        [result appendBytes:&decrypted length:1];
        keyIndex = (keyIndex + 1) % keyLen;
    }
    return [result copy];
}

- (NSData *)encryptData:(NSData *)data withKey:(NSString *)key {
    if ([self isEncrypted:data]) return data;

    NSData *keyData = [key dataUsingEncoding:NSUTF8StringEncoding];
    NSData *marker = [Constants encryptionMarker];
    NSMutableData *result = [NSMutableData dataWithCapacity:marker.length + data.length];

    [result appendData:marker];

    const uint8_t *keyBytes = keyData.bytes;
    NSUInteger keyLen = keyData.length;
    const uint8_t *dataBytes = data.bytes;

    NSUInteger keyIndex = 0;
    for (NSUInteger i = 0; i < data.length; i++) {
        uint8_t encrypted = dataBytes[i] ^ keyBytes[keyIndex];
        [result appendBytes:&encrypted length:1];
        keyIndex = (keyIndex + 1) % keyLen;
    }
    return [result copy];
}

- (BOOL)isEncrypted:(NSData *)data {
    NSData *marker = [Constants encryptionMarker];
    if (data.length < marker.length) return NO;
    NSData *prefix = [data subdataWithRange:NSMakeRange(0, marker.length)];
    return [prefix isEqualToData:marker];
}

#pragma mark - File Operations

- (BOOL)unzipFile:(NSString *)zipPath toDirectory:(NSString *)destDir {
    return minizip_unzip([zipPath UTF8String], [destDir UTF8String]);
}

- (NSString *)findGameWorldDbInDirectory:(NSString *)dirPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:dirPath];
    NSString *file;
    while ((file = [enumerator nextObject])) {
        if ([file hasSuffix:@"GameWorld.db"] && ![file containsString:@"/"]) {
            return [dirPath stringByAppendingPathComponent:file];
        }
        if ([file hasSuffix:@"GameWorld.db"]) {
            return [dirPath stringByAppendingPathComponent:file];
        }
    }
    return nil;
}

- (BOOL)zipFolder:(NSString *)folderPath toZip:(NSString *)zipPath {
    return minizip_zip_folder([folderPath UTF8String], [zipPath UTF8String]);
}

- (void)deleteFolder:(NSString *)folderPath {
    [[NSFileManager defaultManager] removeItemAtPath:folderPath error:nil];
}

@end
