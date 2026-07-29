import Foundation

/// .NET Ticks 与日期之间的转换工具
enum TimeConversionUtil {

    /// .NET Ticks 纪元偏移（公元1年1月1日 → Unix 纪元的 ticks 数）
    private static let ticksToUnixEpoch: Int64 = 621_355_968_000_000_000

    /// Windows 文件时间纪元偏移（1601-01-01 → Unix 纪元）
    private static let windowsTicksToUnixEpoch: Int64 = 116_444_736_000_000_000

    // MARK: - .NET Ticks

    /// 将 .NET Ticks 转换为 Date
    static func netTicksToDate(_ ticks: Int64) -> Date {
        let unixMillis = (ticks - ticksToUnixEpoch) / 10_000
        return Date(timeIntervalSince1970: TimeInterval(unixMillis) / 1000.0)
    }

    /// 将 Date 转换为 .NET Ticks
    static func dateToNetTicks(_ date: Date) -> Int64 {
        let unixMillis = Int64(date.timeIntervalSince1970 * 1000)
        return unixMillis * 10_000 + ticksToUnixEpoch
    }

    /// 从时间分量创建 .NET Ticks
    static func createNetTicks(year: Int, month: Int, day: Int,
                               hour: Int, minute: Int, second: Int) -> Int64 {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = TimeZone(identifier: "UTC")

        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: components) else { return 0 }
        return dateToNetTicks(date)
    }

    /// 将 .NET Ticks 解析为 DateComponents
    static func parseNetTicks(_ ticks: Int64) -> DateComponents {
        let date = ticks == 0 ? Date() : netTicksToDate(ticks)
        let calendar = Calendar(identifier: .gregorian)
        return calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
    }

    // MARK: - Windows File Time

    /// Windows 文件时间 → Date
    static func windowsFileTimeToDate(_ fileTime: Int64) -> Date {
        let unixMillis = (fileTime - windowsTicksToUnixEpoch) / 10_000
        return Date(timeIntervalSince1970: TimeInterval(unixMillis) / 1000.0)
    }

    /// Date → Windows 文件时间
    static func dateToWindowsFileTime(_ date: Date) -> Int64 {
        let unixMillis = Int64(date.timeIntervalSince1970 * 1000)
        return unixMillis * 10_000 + windowsTicksToUnixEpoch
    }

    // MARK: - 格式化

    /// 将 .NET Ticks 格式化为可读字符串
    static func formatNetTicks(_ ticks: Int64) -> String {
        let date = netTicksToDate(ticks)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }
}
