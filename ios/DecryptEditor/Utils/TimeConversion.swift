import Foundation

struct TimeConversion {
    static func netTicksToDate(_ ticks: Int64) -> Date {
        let dotNetEpoch = Date(timeIntervalSince1970: 62135596800)
        return dotNetEpoch.addingTimeInterval(Double(ticks) / 10_000_000)
    }

    static func dateToNetTicks(_ date: Date) -> Int64 {
        let dotNetEpoch = Date(timeIntervalSince1970: 62135596800)
        return Int64(date.timeIntervalSince(dotNetEpoch) * 10_000_000)
    }

    static func windowsFileTimeToDate(_ fileTime: Int64) -> Date {
        let windowsEpoch = Date(timeIntervalSince1970: 11644473600)
        return windowsEpoch.addingTimeInterval(Double(fileTime) / 10_000_000)
    }

    static func dateToWindowsFileTime(_ date: Date) -> Int64 {
        let windowsEpoch = Date(timeIntervalSince1970: 11644473600)
        return Int64(date.timeIntervalSince(windowsEpoch) * 10_000_000)
    }
}
