import Foundation

struct AccountRateLimitsResponse: Codable {
    let rateLimits: RateLimitSnapshot?
    let rateLimitsByLimitId: [String: RateLimitSnapshot]?
    let rateLimitResetCredits: RateLimitResetCreditsSummary?
    var accountId: String? = nil

    private enum CodingKeys: String, CodingKey {
        case rateLimits, rateLimitsByLimitId, rateLimitResetCredits, accountId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(rateLimits, forKey: .rateLimits)
        try container.encodeIfPresent(rateLimitsByLimitId, forKey: .rateLimitsByLimitId)
        try container.encodeIfPresent(rateLimitResetCredits, forKey: .rateLimitResetCredits)
    }
}

struct RateLimitResetCreditsSummary: Codable {
    let availableCount: Int
    var credits: [RateLimitResetCredit]? = nil
}

struct RateLimitResetCredit: Codable {
    let id: String
    let resetType: String
    let status: String
    let expiresAt: Int?
    let title: String?
    let description: String?
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

enum ResetOutcome: String, Decodable {
    case reset, alreadyRedeemed, nothingToReset, noCredit

    var message: String {
        switch self {
        case .reset, .alreadyRedeemed: return "已使用，正在更新限额"
        case .nothingToReset: return "当前额度尚不满足重置条件"
        case .noCredit: return "暂无可用重置卡"
        }
    }
}

struct ResetResponse: Decodable { let outcome: ResetOutcome }

struct ResetAttempt: Codable, Equatable {
    let key: String
    let creditId: String?
    let accountScope: String
}

final class ResetAttemptStore {
    private let fileURL: URL
    init(fileURL: URL = FileManager.default.codexQuotaBarContainerURL.appendingPathComponent("pending-reset.json")) {
        self.fileURL = fileURL
    }
    func load() -> ResetAttempt? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(ResetAttempt.self, from: data)
    }
    func begin(creditId: String?, accountScope: String) throws -> ResetAttempt {
        if let existing = load() { return existing }
        guard !FileManager.default.fileExists(atPath: fileURL.path) else {
            throw CodexAppServerClientError.serverError("重置操作记录不可读")
        }
        // Persist before sending; an uncertain result must reuse this key even after restart.
        let attempt = ResetAttempt(key: UUID().uuidString, creditId: creditId, accountScope: accountScope)
        try SecureLocalFileStore.write(JSONEncoder().encode(attempt), to: fileURL)
        return attempt
    }
    func complete() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
    }
}

struct TokenUsageResponse: Decodable {
    struct Summary: Decodable { let lifetimeTokens: Int64? }
    let summary: Summary
}

struct TokenQuotaSample: Codable, Equatable {
    let timestamp: Date
    let accountScope: String
    let totalTokens: Int64
    let usedPercent: Int
    let resetsAt: Int
}

struct TokenQuotaDay: Codable, Equatable {
    let day: Date
    var tokens: Int64
    var percentagePoints: Int
    var tokensPerPercent: Double { Double(tokens) / Double(max(1, percentagePoints)) }
    var estimatedWeeklyTokens: Double { tokensPerPercent * 100 }
}

struct TokenQuotaTrend: Codable {
    var baseline: TokenQuotaSample?
    var days: [TokenQuotaDay] = []
    var accountScope: String?
    var lastSampleAt: Date?

    mutating func record(_ sample: TokenQuotaSample, calendar: Calendar = .current) {
        guard (0...100).contains(sample.usedPercent), sample.totalTokens >= 0 else { return }
        if let lastSampleAt, sample.timestamp <= lastSampleAt { return }
        if accountScope != sample.accountScope {
            days = []
            baseline = nil
            accountScope = sample.accountScope
        }
        lastSampleAt = sample.timestamp
        let day = calendar.startOfDay(for: sample.timestamp)
        days.removeAll { $0.day < calendar.date(byAdding: .day, value: -29, to: day)! }
        guard let previous = baseline else { baseline = sample; return }
        // Never join samples across midnight, a reset, an account switch, or a counter rollback.
        guard calendar.isDate(previous.timestamp, inSameDayAs: sample.timestamp),
              previous.accountScope == sample.accountScope, previous.resetsAt == sample.resetsAt,
              sample.timestamp.timeIntervalSince1970 < Double(sample.resetsAt),
              sample.usedPercent >= previous.usedPercent, sample.totalTokens >= previous.totalTokens else {
            baseline = sample
            return
        }
        let percentage = sample.usedPercent - previous.usedPercent
        let tokens = sample.totalTokens - previous.totalTokens
        // Keep the original baseline while percentages round to the same integer or token totals lag.
        guard percentage > 0, tokens > 0 else { return }
        if let index = days.firstIndex(where: { $0.day == day }) {
            let sum = days[index].tokens.addingReportingOverflow(tokens)
            guard !sum.overflow else { baseline = sample; return }
            days[index].tokens = sum.partialValue
            days[index].percentagePoints += percentage
        } else {
            days.append(TokenQuotaDay(day: day, tokens: tokens, percentagePoints: percentage))
        }
        days.sort { $0.day < $1.day }
        baseline = sample
    }
}

final class TokenQuotaTrendStore {
    private let fileURL: URL
    init(fileURL: URL = FileManager.default.codexQuotaBarContainerURL.appendingPathComponent("token-quota-trend.json")) {
        self.fileURL = fileURL
    }
    func load() -> TokenQuotaTrend {
        guard let data = try? Data(contentsOf: fileURL),
              let value = try? JSONDecoder().decode(TokenQuotaTrend.self, from: data) else { return TokenQuotaTrend() }
        return value
    }
    func save(_ value: TokenQuotaTrend) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? SecureLocalFileStore.write(data, to: fileURL)
    }
    func clear() { try? FileManager.default.removeItem(at: fileURL) }
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
