import Foundation

struct AccountRateLimitsResponse: Codable {
    let rateLimits: RateLimitSnapshot?
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?
    let rateLimitResetCredits: RateLimitResetCreditsSummary?
}

struct RateLimitResetCreditsSummary: Codable {
    let availableCount: Int
}

struct RateLimitSnapshot: Codable {
    let limitId: String?
    let limitName: String?
    let primary: RateLimitWindow?
    let secondary: RateLimitWindow?
    let credits: CreditsSnapshot?
    let individualLimit: SpendControlLimitSnapshot?
    let planType: String?
    let rateLimitReachedType: String?
}

struct RateLimitWindow: Codable {
    let usedPercent: Int
    let windowDurationMins: Int?
    let resetsAt: Int?

    var remainingPercent: Int {
        max(0, min(100, 100 - usedPercent))
    }
}

struct CreditsSnapshot: Codable {
    let hasCredits: Bool
    let unlimited: Bool
    let balance: String?
}

struct SpendControlLimitSnapshot: Codable {
    let limit: String
    let remainingPercent: Int
    let resetsAt: Int
    let used: String
}

struct QuotaSnapshot: Codable {
    let rateLimits: AccountRateLimitsResponse?
    let fetchedAt: Date

    private enum CodingKeys: String, CodingKey {
        case rateLimits
        case fetchedAt
    }

    init(
        rateLimits: AccountRateLimitsResponse?,
        fetchedAt: Date
    ) {
        self.rateLimits = rateLimits
        self.fetchedAt = fetchedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rateLimits = try container.decodeIfPresent(AccountRateLimitsResponse.self, forKey: .rateLimits)
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(rateLimits, forKey: .rateLimits)
        try container.encode(fetchedAt, forKey: .fetchedAt)
    }

    var primaryRateLimit: RateLimitSnapshot? {
        rateLimits?.rateLimits ?? rateLimits?.rateLimitsByLimitId?["codex"]
    }

    var primaryRemainingPercent: Int? {
        primaryRateLimit?.primary?.remainingPercent
    }
}

enum QuotaRefreshSuccessClassification: Equatable {
    case success
    case invalidQuotaPayload
}

struct QuotaRefreshSuccessClassifier {
    static func classify(snapshot: QuotaSnapshot) -> QuotaRefreshSuccessClassification {
        snapshot.primaryRateLimit == nil ? .invalidQuotaPayload : .success
    }
}

struct QuotaViewModel {
    let statusTitle: String
    let detailLines: [String]
    let detailSections: [QuotaDetailSection]
    let snapshot: QuotaSnapshot
    let fiveHourWindowSummary: QuotaWindowSummary?
    let weeklyWindowSummary: QuotaWindowSummary?

    init(snapshot: QuotaSnapshot, calendar: Calendar = .current, timeZone: TimeZone = .current) {
        let formatter = QuotaFormatter(calendar: calendar, timeZone: timeZone)

        if let remaining = snapshot.quotaWindow(matching: 300)?.remainingPercent
            ?? snapshot.quotaWindow(matching: 10080)?.remainingPercent {
            statusTitle = "\(remaining)%"
        } else {
            statusTitle = "--"
        }

        var windowLines: [String] = []
        var windowSummaries: [QuotaWindowSummary] = []
        var accountLines: [String] = []
        var accountMetrics: [QuotaMetric] = []
        var refreshLines: [String] = []

        if let rateLimit = snapshot.primaryRateLimit {
            if let primary = rateLimit.primary {
                windowLines.append(formatter.windowLine(label: formatter.windowLabel(primary.windowDurationMins), window: primary))
                windowSummaries.append(formatter.windowSummary(label: formatter.compactWindowLabel(primary.windowDurationMins), window: primary, referenceDate: snapshot.fetchedAt))
            }
            if let secondary = rateLimit.secondary {
                windowLines.append(formatter.windowLine(label: formatter.windowLabel(secondary.windowDurationMins), window: secondary))
                windowSummaries.append(formatter.windowSummary(label: formatter.compactWindowLabel(secondary.windowDurationMins), window: secondary, referenceDate: snapshot.fetchedAt))
            }
            if let plan = rateLimit.planType {
                accountLines.append("套餐：\(plan)")
                accountMetrics.append(QuotaMetric(label: "套餐", value: plan))
            }
            if let credits = rateLimit.credits {
                if credits.unlimited {
                    accountLines.append("余额：不限量")
                    accountMetrics.append(QuotaMetric(label: "余额", value: "不限量"))
                } else {
                    let balance = credits.balance ?? "0"
                    accountLines.append("余额：\(balance)")
                    accountMetrics.append(QuotaMetric(label: "余额", value: balance))
                }
            }
            if let resetCredits = snapshot.rateLimits?.rateLimitResetCredits {
                accountLines.append("重置次数：\(resetCredits.availableCount)")
                accountMetrics.append(QuotaMetric(label: "重置次数", value: "\(resetCredits.availableCount)"))
            }
            if let reachedType = rateLimit.rateLimitReachedType {
                accountLines.append("限额状态：\(reachedType)")
            }
        } else {
            windowLines.append("暂无限额数据。")
        }

        refreshLines.append("上次刷新：\(formatter.date(snapshot.fetchedAt))")

        let fiveHourSummary = snapshot.windowSummary(forMinutes: 300, at: snapshot.fetchedAt, formatter: formatter)
        let weeklySummary = snapshot.windowSummary(forMinutes: 10080, at: snapshot.fetchedAt, formatter: formatter)
        fiveHourWindowSummary = fiveHourSummary
        weeklyWindowSummary = weeklySummary

        let sections = [
            QuotaDetailSection(title: "限额窗口", lines: windowLines, presentation: windowSummaries.isEmpty ? .list : .quotaWindows, windowSummaries: windowSummaries),
            QuotaDetailSection(title: "账户", lines: accountLines, presentation: accountMetrics.count > 1 ? .metricColumns : .list, metrics: accountMetrics),
            QuotaDetailSection(title: "刷新", lines: refreshLines),
        ].filter { !$0.lines.isEmpty }
        self.snapshot = snapshot
        detailSections = sections
        detailLines = sections.flatMap(\.lines)
    }
}

extension QuotaSnapshot {
    func quotaWindow(matching minutes: Int) -> RateLimitWindow? {
        guard let primaryRateLimit = primaryRateLimit else { return nil }
        if let primary = primaryRateLimit.primary, primary.windowDurationMins == minutes {
            return primary
        }
        if let secondary = primaryRateLimit.secondary, secondary.windowDurationMins == minutes {
            return secondary
        }
        return nil
    }

    func windowSummary(
        forMinutes minutes: Int,
        at referenceDate: Date,
        formatter: QuotaFormatter
    ) -> QuotaWindowSummary? {
        guard let window = quotaWindow(matching: minutes) else { return nil }
        let label = formatter.compactWindowLabel(minutes)
        return formatter.windowSummary(label: label, window: window, referenceDate: referenceDate)
    }
}

struct QuotaDetailSection {
    let title: String
    let lines: [String]
    let presentation: QuotaDetailSectionPresentation
    let windowSummaries: [QuotaWindowSummary]
    let metrics: [QuotaMetric]

    init(
        title: String,
        lines: [String],
        presentation: QuotaDetailSectionPresentation = .list,
        windowSummaries: [QuotaWindowSummary] = [],
        metrics: [QuotaMetric] = []
    ) {
        self.title = title
        self.lines = lines
        self.presentation = presentation
        self.windowSummaries = windowSummaries
        self.metrics = metrics
    }
}

enum QuotaDetailSectionPresentation: Equatable {
    case list
    case quotaWindows
    case metricColumns
}

struct QuotaWindowSummary: Equatable {
    let label: String
    let remainingPercent: Int
    let resetText: String
    let resetAt: Date?
}

struct QuotaMetric: Equatable {
    let label: String
    let value: String
}

struct QuotaFormatter {
    let calendar: Calendar
    let timeZone: TimeZone

    func windowLabel(_ minutes: Int?) -> String {
        guard let minutes else { return "限额窗口" }
        if minutes % 1440 == 0 {
            return "\(minutes / 1440) 天窗口"
        }
        if minutes % 60 == 0 {
            return "\(minutes / 60) 小时窗口"
        }
        return "\(minutes) 分钟窗口"
    }

    func compactWindowLabel(_ minutes: Int?) -> String {
        guard let minutes else { return "限额" }
        if minutes % 1440 == 0 {
            return "\(minutes / 1440) 天"
        }
        if minutes % 60 == 0 {
            return "\(minutes / 60) 小时"
        }
        return "\(minutes) 分钟"
    }

    func windowLine(label: String, window: RateLimitWindow) -> String {
        let resetText = window.resetsAt.map { "，重置时间 \(date(Date(timeIntervalSince1970: TimeInterval($0))))" } ?? ""
        return "\(label)：剩余 \(window.remainingPercent)%\(resetText)"
    }

    func windowSummary(label: String, window: RateLimitWindow, referenceDate: Date) -> QuotaWindowSummary {
        let resetAt = window.resetsAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
        let resetText = resetAt.map { compactResetText($0, referenceDate: referenceDate) } ?? "未提供"
        return QuotaWindowSummary(label: label, remainingPercent: window.remainingPercent, resetText: resetText, resetAt: resetAt)
    }

    func compactResetText(_ date: Date, referenceDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        if calendar.isDate(date, inSameDayAs: referenceDate) {
            formatter.dateFormat = "HH:mm"
            return "\(formatter.string(from: date)) 重置"
        }
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    func integer(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}

struct QuotaHistoryPoint: Codable, Equatable {
    let timestamp: Date
    let fiveHourUsedPercent: Int
    let weeklyUsedPercent: Int
}

enum SecureLocalFileStore {
    static func hardenPermissions(for fileURL: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: fileURL.deletingLastPathComponent().path
        )
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )
        }
    }

    static func write(_ data: Data, to fileURL: URL) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directoryURL.path
        )
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }
}

extension FileManager {
    var codexQuotaBarContainerURL: URL {
        let library = urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return library.appendingPathComponent("CodexQuotaBar")
    }

    var codexQuotaLogURL: URL {
        codexQuotaBarContainerURL
    }
}

final class QuotaCache {
    private struct CachePayload: Codable {
        let snapshot: QuotaSnapshot
        let fetchedAt: Date
    }

    private let fileURL: URL

    init(fileURL: URL = FileManager.default.codexQuotaBarContainerURL.appendingPathComponent("quota-cache.json")) {
        self.fileURL = fileURL
    }

    func load() -> QuotaSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        try? SecureLocalFileStore.hardenPermissions(for: fileURL)
        guard
              let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(CachePayload.self, from: data) else {
            return nil
        }
        return payload.snapshot
    }

    func save(snapshot: QuotaSnapshot) {
        let payload = CachePayload(snapshot: snapshot, fetchedAt: snapshot.fetchedAt)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? SecureLocalFileStore.write(data, to: fileURL)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

final class QuotaHistoryStore {
    private let fileURL: URL
    private let calendar: Calendar

    init(
        fileURL: URL = FileManager.default.codexQuotaLogURL.appendingPathComponent("quota-history.json"),
        calendar: Calendar = .current
    ) {
        self.fileURL = fileURL
        self.calendar = calendar
    }

    func load() -> [QuotaHistoryPoint] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        try? SecureLocalFileStore.hardenPermissions(for: fileURL)
        guard
              let data = try? Data(contentsOf: fileURL),
              let raw = try? JSONDecoder().decode([QuotaHistoryPoint].self, from: data) else {
            return []
        }
        return raw
    }

    func record(snapshot: QuotaSnapshot, at date: Date) -> [QuotaHistoryPoint] {
        var existing = load()
        let day = calendar.startOfDay(for: date)
        let formatter = QuotaFormatter(calendar: calendar, timeZone: calendar.timeZone)
        let point = QuotaHistoryPoint(
            timestamp: date,
            fiveHourUsedPercent: snapshot.windowSummary(forMinutes: 300, at: date, formatter: formatter)?.remainingPercent ?? 0,
            weeklyUsedPercent: snapshot.windowSummary(forMinutes: 10080, at: date, formatter: formatter)?.remainingPercent ?? 0
        )

        existing.removeAll { calendar.startOfDay(for: $0.timestamp) == day }
        existing.append(point)
        existing.sort { $0.timestamp < $1.timestamp }
        if existing.count > 90 {
            existing = Array(existing.suffix(90))
        }
        if let data = try? JSONEncoder().encode(existing) {
            try? SecureLocalFileStore.write(data, to: fileURL)
        }
        return existing
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
