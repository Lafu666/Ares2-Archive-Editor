import Foundation
import ZIPFoundation
import CryptoKit

/// 存档文件处理：解压、解密、加密、重新打包
final class FileProcessor {

    /// 进度回调
    typealias ProgressCallback = (Int, String) -> Void
    /// 完成回调
    typealias CompleteCallback = (Bool, String) -> Void
    /// 导出完成回调
    typealias FinishCallback = (Bool, String) -> Void

    // MARK: - 公开属性

    /// 当前处理的临时目录路径
    private(set) var tempDirPath: URL?
    /// 解密后的数据库路径
    private(set) var decryptedDbPath: URL?
    /// 原始 ZIP 文件路径
    private(set) var originalZipPath: URL?

    private let fileManager = FileManager.default

    // MARK: - 处理存档（解压 + 解密）

    /// 处理存档文件：解压 → 找到 GameWorld.db → 解密
    func processFile(
        inputPath: URL,
        outputDir: URL,
        progress: @escaping ProgressCallback,
        completion: @escaping CompleteCallback
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.originalZipPath = inputPath

            // 创建临时目录
            let tempDir = outputDir.appendingPathComponent("temp_zip_\(Int(Date().timeIntervalSince1970 * 1000))")
            do {
                try self.fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            } catch {
                DispatchQueue.main.async { completion(false, "创建临时目录失败") }
                return
            }
            self.tempDirPath = tempDir
            DispatchQueue.main.async { progress(10, "创建临时目录成功") }

            // 解压
            do {
                try self.unzipFile(at: inputPath, to: tempDir)
            } catch {
                DispatchQueue.main.async { completion(false, "解压失败: \(error.localizedDescription)") }
                return
            }
            DispatchQueue.main.async { progress(30, "解压ZIP文件完成") }

            // 查找 GameWorld.db
            guard let dbFile = self.findGameWorldDb(in: tempDir) else {
                DispatchQueue.main.async { completion(false, "找不到 GameWorld.db 文件") }
                return
            }
            DispatchQueue.main.async { progress(40, "找到数据库文件") }

            // 解密数据库
            do {
                let dbData = try Data(contentsOf: dbFile)
                let decryptedData = self.decrypt(dbData, key: Constants.dbEncryptKey)
                let decryptedPath = outputDir.appendingPathComponent("decrypted.db")
                try decryptedData.write(to: decryptedPath)
                self.decryptedDbPath = decryptedPath
                DispatchQueue.main.async { progress(60, "准备编辑环境") }
                DispatchQueue.main.async { completion(true, "存档已准备好，可以开始编辑") }
            } catch {
                DispatchQueue.main.async { completion(false, "处理失败: \(error.localizedDescription)") }
            }
        }
    }

    // MARK: - 导出处理（重打包 + 加密）

    /// 导出存档：解压原始 ZIP → 重命名文件夹 → 加密当前修改的数据库 → 返回临时目录路径
    func processFileForExport(
        inputPath: URL,
        outputDir: URL,
        currentDbPath: URL?,
        userFolderName: String,
        progress: @escaping ProgressCallback,
        completion: @escaping CompleteCallback
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let tempDir = outputDir.appendingPathComponent("temp_export_\(Int(Date().timeIntervalSince1970 * 1000))")
            do {
                try self.fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            } catch {
                DispatchQueue.main.async { completion(false, "创建临时目录失败") }
                return
            }
            DispatchQueue.main.async { progress(10, "创建临时目录成功") }

            do {
                try self.unzipFile(at: inputPath, to: tempDir)
            } catch {
                DispatchQueue.main.async { completion(false, "解压失败: \(error.localizedDescription)") }
                return
            }
            DispatchQueue.main.async { progress(30, "解压ZIP文件完成") }

            guard let dbFile = self.findGameWorldDb(in: tempDir) else {
                DispatchQueue.main.async { completion(false, "找不到数据库文件") }
                return
            }
            DispatchQueue.main.async { progress(40, "找到数据库文件") }

            // 重命名存档文件夹
            let archiveFolder = dbFile.deletingLastPathComponent()
            let newArchiveFolder = archiveFolder.deletingLastPathComponent()
                .appendingPathComponent(userFolderName)

            do {
                if self.fileManager.fileExists(atPath: newArchiveFolder.path) {
                    try self.fileManager.removeItem(at: newArchiveFolder)
                }
                try self.fileManager.moveItem(at: archiveFolder, to: newArchiveFolder)
            } catch {
                DispatchQueue.main.async { completion(false, "无法重命名存档文件夹") }
                return
            }
            DispatchQueue.main.async { progress(45, "重命名存档文件夹为: \(userFolderName)") }

            let newDbFile = newArchiveFolder.appendingPathComponent("GameWorld.db")

            // 加密当前修改的数据库
            if let currentDbPath = currentDbPath {
                do {
                    let currentDbData = try Data(contentsOf: currentDbPath)
                    let encryptedData = self.encrypt(currentDbData, key: Constants.dbEncryptKey)
                    try encryptedData.write(to: newDbFile)
                    DispatchQueue.main.async { progress(70, "加密并应用当前修改完成") }
                } catch {
                    DispatchQueue.main.async { completion(false, "加密失败: \(error.localizedDescription)") }
                    return
                }
            } else {
                DispatchQueue.main.async { progress(70, "没有修改的数据库，使用原始文件") }
            }

            // 确保 oss 目录存在
            let ossDir = newArchiveFolder.appendingPathComponent("oss")
            if !self.fileManager.fileExists(atPath: ossDir.path) {
                try? self.fileManager.createDirectory(at: ossDir, withIntermediateDirectories: true)
                let keepFile = ossDir.appendingPathComponent(".keep")
                try? "".write(to: keepFile, atomically: true, encoding: .utf8)
            }

            DispatchQueue.main.async { completion(true, tempDir.path) }
        }
    }

    /// 完成导出：将临时目录重新打包为 ZIP
    func finishExport(
        tempDir: URL,
        outputPath: URL,
        progress: @escaping ProgressCallback,
        completion: @escaping FinishCallback
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async { progress(80, "重新打包存档...") }

            do {
                try self.zipFolder(at: tempDir, to: outputPath)
            } catch {
                DispatchQueue.main.async { completion(false, "导出失败: \(error.localizedDescription)") }
                return
            }

            DispatchQueue.main.async { progress(90, "清理临时文件...") }
            try? self.fileManager.removeItem(at: tempDir)

            DispatchQueue.main.async { progress(100, "导出完成") }
            DispatchQueue.main.async { completion(true, outputPath.path) }
        }
    }

    // MARK: - 加密 / 解密

    /// 解密数据（XOR with key, 跳过加密标记头部）
    func decrypt(_ data: Data, key: String) -> Data {
        guard isEncrypted(data) else { return data }
        let keyBytes = Array(key.utf8)
        let markerLen = Constants.encryptionMarker.count
        var result = Data(capacity: data.count - markerLen)
        var keyIndex = 0
        for i in markerLen..<data.count {
            result.append(data[i] ^ keyBytes[keyIndex])
            keyIndex = (keyIndex + 1) % keyBytes.count
        }
        return result
    }

    /// 加密数据（XOR with key, 添加加密标记头部）
    func encrypt(_ data: Data, key: String) -> Data {
        guard !isEncrypted(data) else { return data }
        let keyBytes = Array(key.utf8)
        var result = Data(capacity: data.count + Constants.encryptionMarker.count)
        result.append(contentsOf: Constants.encryptionMarker)
        var keyIndex = 0
        for byte in data {
            result.append(byte ^ keyBytes[keyIndex])
            keyIndex = (keyIndex + 1) % keyBytes.count
        }
        return result
    }

    /// 检查数据是否已加密（通过头部标记判断）
    func isEncrypted(_ data: Data) -> Bool {
        guard data.count >= Constants.encryptionMarker.count else { return false }
        for i in 0..<Constants.encryptionMarker.count {
            if data[i] != Constants.encryptionMarker[i] { return false }
        }
        return true
    }

    // MARK: - MD5 校验

    /// 计算文件的 MD5 哈希
    func calculateMD5(at path: URL) -> String? {
        guard let data = try? Data(contentsOf: path) else { return nil }
        return data.md5Hash
    }

    /// 更新存档目录中的 MD5 标记文件
    func updateMd5File(_ md5: String, rootDir: URL) {
        // 删除旧的 MD5 文件
        if let files = try? fileManager.contentsOfDirectory(atPath: rootDir.path) {
            for file in files where file.hasPrefix("MD5_") {
                try? fileManager.removeItem(at: rootDir.appendingPathComponent(file))
            }
        }
        let md5File = rootDir.appendingPathComponent("MD5_\(md5)")
        try? md5.write(to: md5File, atomically: true, encoding: .utf8)
    }

    // MARK: - 清理

    /// 清理临时文件
    func cleanup() {
        if let tempDir = tempDirPath {
            try? fileManager.removeItem(at: tempDir)
            tempDirPath = nil
        }
        if let decrypted = decryptedDbPath {
            try? fileManager.removeItem(at: decrypted)
            decryptedDbPath = nil
        }
    }

    // MARK: - 私有方法

    private func unzipFile(at zipPath: URL, to outputDir: URL) throws {
        try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)
        try fileManager.unzipItem(at: zipPath, to: outputDir)
    }

    private func zipFolder(at inputDir: URL, to outputZip: URL) throws {
        // 删除已存在的输出文件
        if fileManager.fileExists(atPath: outputZip.path) {
            try fileManager.removeItem(at: outputZip)
        }
        try fileManager.zipItem(at: inputDir, to: outputZip)
    }

    /// 递归查找 GameWorld.db
    private func findGameWorldDb(in dir: URL) -> URL? {
        guard let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return nil
        }
        for file in files {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: file.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    if let result = findGameWorldDb(in: file) {
                        return result
                    }
                } else if file.lastPathComponent == "GameWorld.db" {
                    return file
                }
            }
        }
        return nil
    }
}

// MARK: - Data MD5 扩展

extension Data {
    var md5Hash: String {
        let digest = Insecure.MD5.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
