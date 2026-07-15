import AppKit
import Foundation

@discardableResult
func uiExpect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    return true
}

private func decode<T: Decodable>(_ type: T.Type, from json: String) -> T {
    let data = Data(json.utf8)
    do {
        return try JSONDecoder().decode(T.self, from: data)
    } catch {
        fputs("FAIL: decode \(T.self): \(error)\n", stderr)
        exit(1)
    }
}

private func samplePanelState(
    primaryUsedPercent: Int = 100,
    secondaryUsedPercent: Int = 67,
    includesFiveHourLimit: Bool = true,
    primaryResetAt: Int = 1783254522,
    secondaryResetAt: Int = 1783411403,
    fetchedAt: Date = Date(timeIntervalSince1970: 1783238502),
    loadState: QuotaPanelLoadState = .success,
    runtimeHealth: CodexRuntimeStatusSnapshot.Health = .online,
    isRefreshing: Bool = false,
    lastError: String? = nil
) -> QuotaPanelViewModel {
    let primaryWindowJSON = includesFiveHourLimit
        ? """
        "primary": {
          "usedPercent": \(primaryUsedPercent),
          "windowDurationMins": 300,
          "resetsAt": \(primaryResetAt)
        },
        """
        : "\"primary\": null,"
    let rateLimitJSON = """
    {
      "rateLimits": {
        "limitId": "codex",
        \(primaryWindowJSON)
        "secondary": {
          "usedPercent": \(secondaryUsedPercent),
          "windowDurationMins": 10080,
          "resetsAt": \(secondaryResetAt)
        },
        "credits": {
          "hasCredits": false,
          "unlimited": false,
          "balance": "0"
        },
        "planType": "prolite",
        "rateLimitReachedType": null
      },
      "rateLimitResetCredits": {
        "availableCount": 4
      }
    }
    """
    let rateLimits = decode(AccountRateLimitsResponse.self, from: rateLimitJSON)
    let snapshot = QuotaSnapshot(
        rateLimits: rateLimits,
        fetchedAt: fetchedAt
    )
    let history = [
        QuotaHistoryPoint(timestamp: Date(timeIntervalSince1970: 1782633600), fiveHourUsedPercent: 10, weeklyUsedPercent: 20),
        QuotaHistoryPoint(timestamp: Date(timeIntervalSince1970: 1782720000), fiveHourUsedPercent: 20, weeklyUsedPercent: 28),
        QuotaHistoryPoint(timestamp: Date(timeIntervalSince1970: 1782806400), fiveHourUsedPercent: 30, weeklyUsedPercent: 34),
        QuotaHistoryPoint(timestamp: Date(timeIntervalSince1970: 1782892800), fiveHourUsedPercent: 40, weeklyUsedPercent: 41),
        QuotaHistoryPoint(timestamp: Date(timeIntervalSince1970: 1782979200), fiveHourUsedPercent: 50, weeklyUsedPercent: 52),
        QuotaHistoryPoint(timestamp: Date(timeIntervalSince1970: 1783065600), fiveHourUsedPercent: 60, weeklyUsedPercent: 60),
        QuotaHistoryPoint(timestamp: Date(timeIntervalSince1970: 1783152000), fiveHourUsedPercent: 67, weeklyUsedPercent: 67)
    ]
    return QuotaPanelViewModel(
        loadState: loadState,
        isRefreshing: isRefreshing,
        viewModel: QuotaViewModel(snapshot: snapshot),
        runtimeStatus: CodexRuntimeStatusSnapshot(
            health: runtimeHealth,
            latencyMs: 5053,
            autoRefreshMinutes: 5,
            activeTaskCount: 6,
            queueCount: 0,
            errorSummary: runtimeHealth == .online ? nil : runtimeHealth.rawValue,
            isDetected: true,
            isRefreshing: false
        ),
        history: history,
        lastError: lastError,
        lastUpdatedAt: snapshot.fetchedAt,
        refreshIntervalMinutes: 5
    )
}

private extension NSView {
    func descendants<T: NSView>(ofType type: T.Type) -> [T] {
        var matches: [T] = []
        for subview in subviews {
            if let match = subview as? T {
                matches.append(match)
            }
            matches.append(contentsOf: subview.descendants(ofType: type))
        }
        return matches
    }
}

private func alphaComponent(of color: NSColor) -> CGFloat {
    let converted = color.usingColorSpace(.deviceRGB) ?? color
    var alpha: CGFloat = 0
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return alpha
}

private func colorMatches(_ lhs: NSColor, _ rhs: NSColor, tolerance: CGFloat = 0.01) -> Bool {
    let left = lhs.usingColorSpace(.deviceRGB) ?? lhs
    let right = rhs.usingColorSpace(.deviceRGB) ?? rhs
    var lr: CGFloat = 0
    var lg: CGFloat = 0
    var lb: CGFloat = 0
    var la: CGFloat = 0
    var rr: CGFloat = 0
    var rg: CGFloat = 0
    var rb: CGFloat = 0
    var ra: CGFloat = 0
    left.getRed(&lr, green: &lg, blue: &lb, alpha: &la)
    right.getRed(&rr, green: &rg, blue: &rb, alpha: &ra)
    return abs(lr - rr) <= tolerance
        && abs(lg - rg) <= tolerance
        && abs(lb - rb) <= tolerance
        && abs(la - ra) <= tolerance
}

private func rgbComponents(of color: NSColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
    let converted = color.usingColorSpace(.deviceRGB) ?? color
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    converted.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return (red, green, blue, alpha)
}

private func colorDistance(_ lhs: NSColor, _ rhs: NSColor) -> CGFloat {
    let left = rgbComponents(of: lhs)
    let right = rgbComponents(of: rhs)
    let red = left.red - right.red
    let green = left.green - right.green
    let blue = left.blue - right.blue
    return sqrt(red * red + green * green + blue * blue)
}

private func brightness(of color: NSColor) -> CGFloat {
    let components = rgbComponents(of: color)
    return max(components.red, components.green, components.blue)
}

private final class InMemorySettingsBacking: QuotaSettingsBacking {
    private var values: [String: Int] = [:]

    func integer(forKey defaultName: String) -> Int {
        values[defaultName] ?? 0
    }

    func set(_ value: Int, forKey defaultName: String) {
        values[defaultName] = value
    }
}

@main
struct CodexQuotaUITests {
    static func main() {
        let state = samplePanelState()
        let menuBarBadge = MenuBarStatusView.image(for: state)
        let menuBarLayout = MenuBarStatusView.layout(for: state)
        uiExpect(DesignTokens.panelWidth == 250, "main quota panel should use the narrow 250pt width")
        uiExpect(DesignTokens.panelCornerRadius <= 18, "expanded quota panel should use a smaller macOS-style rounded rectangle radius")
        uiExpect(DesignTokens.cardCornerRadius <= 12, "inner cards should use a smaller macOS-style rounded rectangle radius")
        uiExpect(DesignTokens.statusBadgeCornerRadius <= 8, "menu bar badge should use a smaller rounded-rectangle radius instead of a full capsule")
        uiExpect(DesignTokens.statusBadgeWidth <= 48, "menu bar badge should stay compact after moving reset time into the capsule")
        uiExpect(DesignTokens.statusBadgeCapsuleWidth == DesignTokens.statusBadgeWidth, "menu bar badge should be a single capsule containing quota and reset time")
        uiExpect(menuBarBadge.size.width == DesignTokens.statusBadgeWidth, "menu bar badge should use the fixed capsule width")
        uiExpect(menuBarBadge.size.height == DesignTokens.statusBadgeHeight, "menu bar badge should use the fixed capsule height")
        uiExpect(StatusBadgeRenderer.statusItemLength(for: menuBarBadge) == DesignTokens.statusBadgeWidth, "status item width should match the fixed capsule width")
        uiExpect(state.statusBadgePercent == 0, "menu bar badge should use the 5-hour remaining quota instead of the 7-day quota")
        uiExpect(menuBarLayout.percentText == "0", "menu bar badge text should show the 5-hour remaining number without a percent sign")
        let expectedFiveHourReset = state.viewModel?.fiveHourWindowSummary?.resetText.replacingOccurrences(of: " 重置", with: "")
        uiExpect(menuBarLayout.resetText == expectedFiveHourReset, "menu bar badge should show the 5-hour reset time on the right")
        uiExpect(menuBarLayout.resetTextFrame.minX >= menuBarLayout.capsuleFrame.minX, "menu bar reset time should sit inside the capsule")
        uiExpect(menuBarLayout.resetTextFrame.maxX <= menuBarLayout.capsuleFrame.maxX, "menu bar reset time should stay inside the capsule")
        uiExpect(menuBarLayout.percentTextFrame.minY > menuBarLayout.resetTextFrame.maxY, "menu bar quota number and reset time should be stacked on two lines")
        uiExpect(menuBarLayout.monitorDotFrame.minX - menuBarLayout.percentTextFrame.maxX <= 5, "menu bar number and monitor dot should stay tightly grouped inside the capsule")
        uiExpect(menuBarLayout.capsuleCornerRadius == DesignTokens.statusBadgeCornerRadius, "menu bar badge drawing should use the shared smaller corner radius token")
        uiExpect(menuBarLayout.capsuleCornerRadius < DesignTokens.statusBadgeHeight / 2, "menu bar badge should render as a rounded rectangle rather than a pill")
        uiExpect(menuBarLayout.showsQuotaPieGlyph == false, "menu bar badge should not draw the old pie/ring quota glyph")
        uiExpect(colorMatches(menuBarLayout.capsuleColor, DesignColors.statusRed), "menu bar capsule background should follow 5-hour quota risk")
        uiExpect(menuBarLayout.capsuleFillAlpha >= 0.65, "menu bar capsule fill should be saturated enough to visibly reflect quota risk")
        uiExpect(colorMatches(menuBarLayout.monitorDotColor, DesignColors.monitorGreen), "menu bar status dot should indicate monitoring health with a high-contrast color")

        var statusCalendar = Calendar(identifier: .gregorian)
        statusCalendar.timeZone = .current
        let statusNow = Date()
        let futureWeeklyReset = statusCalendar.date(
            bySettingHour: 14,
            minute: 32,
            second: 0,
            of: statusCalendar.date(byAdding: .day, value: 7, to: statusNow)!
        )!
        let weeklyOnlyState = samplePanelState(
            secondaryUsedPercent: 42,
            includesFiveHourLimit: false,
            secondaryResetAt: Int(futureWeeklyReset.timeIntervalSince1970),
            fetchedAt: statusNow
        )
        let weeklyOnlyLayout = MenuBarStatusView.layout(for: weeklyOnlyState, now: statusNow)
        let weeklyDateFormatter = DateFormatter()
        weeklyDateFormatter.calendar = statusCalendar
        weeklyDateFormatter.timeZone = statusCalendar.timeZone
        weeklyDateFormatter.dateFormat = "M/d"
        uiExpect(weeklyOnlyState.statusBadgePercent == 58, "weekly-only mode should use the 7-day remaining quota in the menu bar")
        uiExpect(weeklyOnlyLayout.percentText == "58", "weekly-only menu bar badge should display the weekly remaining number")
        uiExpect(
            weeklyOnlyLayout.resetText == weeklyDateFormatter.string(from: futureWeeklyReset),
            "weekly-only menu bar badge should show the reset month/day before reset day"
        )
        uiExpect(colorMatches(weeklyOnlyLayout.capsuleColor, DesignColors.statusGreen), "weekly-only badge color should follow weekly remaining quota")
        uiExpect(MenuBarStatusView.accessibilityText(for: weeklyOnlyState).contains("7 天限额"), "weekly-only badge accessibility text should identify the weekly limit")

        let sameDayWeeklyReset = statusCalendar.date(bySettingHour: 14, minute: 32, second: 0, of: statusNow)!
        let sameDayWeeklyState = samplePanelState(
            secondaryUsedPercent: 42,
            includesFiveHourLimit: false,
            secondaryResetAt: Int(sameDayWeeklyReset.timeIntervalSince1970),
            fetchedAt: statusNow
        )
        uiExpect(
            MenuBarStatusView.layout(for: sameDayWeeklyState, now: statusNow).resetText == "14:32",
            "weekly-only menu bar badge should show the exact reset time on reset day"
        )
        uiExpect(colorMatches(QuotaRemainingColorRule.color(for: 100), DesignColors.statusGreen), "100% remaining quota should be green")
        uiExpect(colorMatches(QuotaRemainingColorRule.color(for: 20), DesignColors.statusGreen), "20% remaining quota should still be green")
        uiExpect(colorMatches(QuotaRemainingColorRule.color(for: 19), DesignColors.statusYellow), "19% remaining quota should be yellow")
        uiExpect(colorMatches(QuotaRemainingColorRule.color(for: 6), DesignColors.statusYellow), "6% remaining quota should be yellow")
        uiExpect(colorMatches(QuotaRemainingColorRule.color(for: 5), DesignColors.statusRed), "5% remaining quota should be red")
        uiExpect(colorMatches(QuotaRemainingColorRule.color(for: 0), DesignColors.statusRed), "0% remaining quota should be red")
        uiExpect(colorMatches(UIStatusValueColor.forRemainingPercent(20), DesignColors.statusGreen), "legacy remaining color helper should use the same 20% green threshold")
        uiExpect(colorMatches(UIStatusValueColor.forRemainingPercent(6), DesignColors.statusYellow), "legacy remaining color helper should use the same yellow threshold")
        uiExpect(colorMatches(UIStatusValueColor.forRemainingPercent(5), DesignColors.statusRed), "legacy remaining color helper should use the same red threshold")
        let refreshingState = samplePanelState(loadState: .loading, runtimeHealth: .refreshing, isRefreshing: true)
        let refreshingLayout = MenuBarStatusView.layout(for: refreshingState)
        uiExpect(refreshingLayout.percentText == menuBarLayout.percentText, "refreshing status badge should keep the last quota number instead of showing ellipsis")
        uiExpect(colorMatches(refreshingLayout.capsuleColor, menuBarLayout.capsuleColor), "refreshing status badge should keep the last quota color instead of using a dark loading fill")
        uiExpect(colorMatches(refreshingLayout.monitorDotColor, DesignColors.monitorBlue), "refreshing status badge should show only the monitor dot as blue")
        let refreshingBlue = rgbComponents(of: refreshingLayout.monitorDotColor)
        uiExpect(refreshingBlue.blue - max(refreshingBlue.red, refreshingBlue.green) >= 0.45, "refreshing status dot should use a more saturated electric blue")
        uiExpect(refreshingLayout.monitorDotAlpha >= 0.85, "refreshing status dot should remain bright at the dimmest breathing phase")
        uiExpect(abs(refreshingLayout.monitorDotFrame.width - menuBarLayout.monitorDotFrame.width) <= 0.01, "refreshing status dot should keep the same size as the normal online dot")
        let apiErrorWithQuota = samplePanelState(
            primaryUsedPercent: 20,
            secondaryUsedPercent: 67,
            loadState: .apiError,
            runtimeHealth: .apiException
        )
        let apiErrorLayout = MenuBarStatusView.layout(for: apiErrorWithQuota)
        uiExpect(colorMatches(apiErrorLayout.capsuleColor, DesignColors.statusGreen), "menu bar capsule background should keep following 5-hour quota when API is unhealthy")
        uiExpect(colorMatches(apiErrorLayout.monitorDotColor, DesignColors.monitorRed), "API failures should be shown by the monitor dot only")
        uiExpect(abs(apiErrorLayout.monitorDotFrame.width - menuBarLayout.monitorDotFrame.width) <= 0.01, "error status dot should keep the same size as the normal online dot")
        uiExpect(MenuBarStatusView.dotBreathingDuration >= 3.0, "monitor dot breathing animation should be slow and calm")
        let dimDotLayout = MenuBarStatusView.layout(for: state, dotPhase: 0)
        let brightDotLayout = MenuBarStatusView.layout(for: state, dotPhase: 0.5)
        uiExpect(dimDotLayout.monitorDotAlpha >= 0.35, "breathing status dot should remain visible at its dimmest point")
        uiExpect(brightDotLayout.monitorDotAlpha <= 1.0, "breathing status dot should not exceed full opacity")
        uiExpect(brightDotLayout.monitorDotAlpha > dimDotLayout.monitorDotAlpha, "breathing status dot should visibly pulse over time")
        uiExpect(AutoRefreshIntervalOption.all.count == 5, "settings should expose about five fixed auto-refresh interval choices")
        uiExpect(
            AutoRefreshIntervalOption.all.map(\.title) == ["10 秒", "30 秒", "1 分钟", "5 分钟", "15 分钟"],
            "settings should offer fixed short-to-normal auto-refresh choices without free-form input"
        )
        uiExpect(AutoRefreshIntervalOption.defaultOption.seconds == 300, "default auto-refresh interval should remain 5 minutes")
        let settingsBacking = InMemorySettingsBacking()
        let settingsStore = QuotaSettingsStore(backing: settingsBacking)
        uiExpect(settingsStore.autoRefreshIntervalSeconds == 300, "settings store should default to 5 minutes")
        settingsStore.autoRefreshIntervalSeconds = 30
        uiExpect(settingsStore.autoRefreshIntervalSeconds == 30, "settings store should persist a supported interval choice")
        settingsStore.autoRefreshIntervalSeconds = 17
        uiExpect(settingsStore.autoRefreshIntervalSeconds == 300, "settings store should reject unsupported custom intervals")
        uiExpect(
            CodexServiceFailureClassifier.classify(
                "failed to fetch codex rate limits: error sending request for url (https://chatgpt.com/backend-api/wham/usage)"
            ) == .network,
            "new Codex rate-limit transport failures should be reported as network errors"
        )
        uiExpect(
            CodexServiceFailureClassifier.classify(
                CodexAppServerClientError.serverError(
                    "failed to fetch codex rate limits: error sending request for url (https://chatgpt.com/backend-api/wham/usage)"
                )
            ) == .network,
            "typed app-server errors should keep their detailed network failure classification"
        )
        uiExpect(
            CodexServiceFailureClassifier.classify("Unauthorized: credentials expired") == .auth,
            "credential failures should remain classified as authentication errors"
        )
        uiExpect(
            CodexServiceFailureClassifier.classify("invalid JSON-RPC response") == .api,
            "unexpected protocol failures should remain API errors"
        )
        let sensitiveDiagnosticState = samplePanelState(
            lastError: "request failed for https://private.example/user/private@example.com at /Users/private/.codex/auth.json"
        )
        let sanitizedDiagnostic = QuotaDiagnosticFormatter.text(for: sensitiveDiagnosticState)
        uiExpect(!sanitizedDiagnostic.contains("https://"), "diagnostics should not copy raw service URLs")
        uiExpect(!sanitizedDiagnostic.contains("private@example.com"), "diagnostics should not copy account email")
        uiExpect(!sanitizedDiagnostic.contains("/Users/private"), "diagnostics should not copy user filesystem paths")
        let scheduler = RefreshScheduler(interval: 300) {}
        uiExpect(scheduler.currentInterval == 300, "refresh scheduler should expose its current interval for settings")
        scheduler.updateInterval(30)
        uiExpect(scheduler.currentInterval == 30, "refresh scheduler should update its repeating interval when settings change")
        var selectedAutoRefreshInterval: Int?
        let settingsController = SettingsView(selectedIntervalSeconds: 30) { seconds in
            selectedAutoRefreshInterval = seconds
        }
        settingsController.loadView()
        let intervalPicker = settingsController.view.descendants(ofType: NSPopUpButton.self).first {
            $0.identifier?.rawValue == "auto-refresh-interval-picker"
        }
        uiExpect(intervalPicker != nil, "settings window should show an auto-refresh interval picker")
        uiExpect(intervalPicker?.numberOfItems == AutoRefreshIntervalOption.all.count, "settings picker should contain every fixed interval option")
        uiExpect(intervalPicker?.titleOfSelectedItem == "30 秒", "settings picker should select the current auto-refresh interval")
        if let intervalPicker, let action = intervalPicker.action {
            intervalPicker.selectItem(withTitle: "1 分钟")
            _ = intervalPicker.target?.perform(action, with: intervalPicker)
        }
        uiExpect(selectedAutoRefreshInterval == 60, "settings picker should notify when the user chooses a new fixed interval")
        let healthyGreenCapsule = samplePanelState(primaryUsedPercent: 20, secondaryUsedPercent: 67)
        let healthyGreenLayout = MenuBarStatusView.layout(for: healthyGreenCapsule)
        uiExpect(colorDistance(healthyGreenLayout.monitorDotColor, healthyGreenLayout.capsuleColor) >= 0.16, "monitor dot color should be visibly distinct from a same-family green quota capsule")
        uiExpect(brightness(of: healthyGreenLayout.monitorDotColor) >= brightness(of: healthyGreenLayout.capsuleColor), "monitor dot should use a high-brightness status color")
        uiExpect(alphaComponent(of: healthyGreenLayout.monitorDotStrokeColor) >= 0.70, "monitor dot should have a strong light outline for contrast")
        uiExpect(alphaComponent(of: DesignColors.cardBackgroundStrong) <= 0.05, "native Liquid Glass tint should stay very transparent")
        uiExpect(alphaComponent(of: DesignColors.cardBackground) <= 0.04, "custom glass card fill should not become an opaque white overlay")

        let anchor = NSRect(x: 800, y: 770, width: 96, height: 24)
        let visible = NSRect(x: 0, y: 0, width: 1000, height: 800)
        let panelSize = NSSize(width: DesignTokens.panelWidth, height: 620)
        let frame = QuotaPanelWindowController.panelFrame(
            anchorScreenRect: anchor,
            panelSize: panelSize,
            visibleFrame: visible
        )
        uiExpect(frame.width == panelSize.width, "panel placement should preserve fixed width")
        uiExpect(frame.maxX <= visible.maxX - DesignTokens.panelScreenPadding, "panel placement should clamp to the visible right edge")
        uiExpect(frame.maxY <= visible.maxY - DesignTokens.panelTopSafetyInset, "panel should keep a safe top inset below the menu bar")
        let flushMenuAnchor = NSRect(x: 452, y: visible.maxY, width: 96, height: 24)
        let flushMenuFrame = QuotaPanelWindowController.panelFrame(
            anchorScreenRect: flushMenuAnchor,
            panelSize: NSSize(width: DesignTokens.panelWidth, height: DesignTokens.panelMinHeight),
            visibleFrame: visible
        )
        uiExpect(visible.maxY - flushMenuFrame.maxY <= 8, "panel should use the standard compact menu-bar popover gap")
        let menuBarAnchor = NSRect(x: 452, y: visible.maxY + 8, width: 96, height: 24)
        let menuBarFrame = QuotaPanelWindowController.panelFrame(
            anchorScreenRect: menuBarAnchor,
            panelSize: NSSize(width: DesignTokens.panelWidth, height: DesignTokens.panelMinHeight),
            visibleFrame: visible
        )
        uiExpect(visible.maxY - menuBarFrame.maxY <= 8, "panel should not sit noticeably lower when anchored from the menu bar")
        uiExpect(
            QuotaPanelWindowController.shouldDismissForGlobalClick(
                at: NSPoint(x: menuBarAnchor.midX, y: menuBarAnchor.midY),
                anchorScreenRect: menuBarAnchor
            ) == false,
            "global click monitor should ignore clicks on the status bar capsule so the button can toggle closed"
        )
        uiExpect(
            QuotaPanelWindowController.shouldDismissForGlobalClick(
                at: NSPoint(x: menuBarAnchor.maxX + 40, y: menuBarAnchor.midY),
                anchorScreenRect: menuBarAnchor
            ),
            "global click monitor should dismiss clicks outside the status bar capsule"
        )

        let glassView = QuotaGlassView()
        uiExpect(glassView.contentContainer.superview != nil, "glass view should expose a hosted content container")
        if #available(macOS 26.0, *) {
            uiExpect(glassView.usesNativeGlassEffect, "macOS 26 and later should use NSGlassEffectView for Liquid Glass")
            let mainGlass = glassView.descendants(ofType: NSGlassEffectView.self).first
            uiExpect(mainGlass?.style == .regular, "main panel should use the standard regular Liquid Glass style")
            uiExpect(mainGlass?.tintColor == nil, "main panel should let regular Liquid Glass sample the background without a custom tint")
            if #available(macOS 27.0, *) {
                uiExpect(mainGlass?.effectIsInteractive == false, "main content glass should remain noninteractive")
            }
        }
        let materialFreeCard = GlassCard()
        let materialFreeCardAlpha: CGFloat
        if let backgroundColor = materialFreeCard.layer?.backgroundColor,
           let color = NSColor(cgColor: backgroundColor) {
            materialFreeCardAlpha = alphaComponent(of: color)
        } else {
            materialFreeCardAlpha = 0
        }
        uiExpect(materialFreeCardAlpha == 0, "content cards should not add a custom translucent material over Liquid Glass")
        uiExpect(materialFreeCard.layer?.borderWidth == 0, "content cards should not draw a custom outer glass border")
        uiExpect(
            materialFreeCard.layer?.sublayers?.contains(where: { $0.borderWidth > 0 }) != true,
            "content cards should not draw a custom inner highlight border"
        )

        let controller = QuotaPopoverViewController(
            model: state,
            refreshAction: {},
            detailsAction: {},
            settingsAction: {},
            copyDiagnosticAction: {},
            pauseAutoRefreshAction: {},
            openLogDirectoryAction: {},
            clearLocalCacheAction: {},
            quitAction: {}
        )
        controller.loadView()
        let view = controller.view
        view.frame = NSRect(x: 0, y: 0, width: DesignTokens.panelWidth, height: DesignTokens.panelMinHeight)
        view.layoutSubtreeIfNeeded()
        uiExpect(view.fittingSize.height <= 190, "panel content should fit within the compact quota-only menu-bar panel height")

        let usage = view.descendants(ofType: UsageOverviewCard.self).first
        let runtimeCard = view.descendants(ofType: CodexRuntimeStatusCard.self).first
        let accountCard = view.descendants(ofType: AccountSummaryCard.self).first
        let oldQuotaCards = view.descendants(ofType: QuotaCard.self)
        let compactQuotaList = view.descendants(ofType: NSView.self).first { $0.identifier?.rawValue == "compact-quota-list" }
        let headerQuotaSeparator = view.descendants(ofType: NSView.self).first { $0.identifier?.rawValue == "header-quota-separator" }
        let resetQuotaSeparator = view.descendants(ofType: NSView.self).first { $0.identifier?.rawValue == "quota-reset-separator" }
        let segmentBars = view.descendants(ofType: QuotaSegmentedProgressView.self)
        let headerTitle = view.descendants(ofType: NSTextField.self).first { $0.stringValue == "Codex 限额监控" }
        let fiveHourLabel = view.descendants(ofType: NSTextField.self).first { $0.stringValue == "5 小时" }
        let weeklyLabel = view.descendants(ofType: NSTextField.self).first { $0.stringValue == "7 天" }
        let resetCountLabel = view.descendants(ofType: NSTextField.self).first { $0.identifier?.rawValue == "reset-credits-label" }
        let refreshInfoLabel = view.descendants(ofType: NSTextField.self).first { $0.identifier?.rawValue == "last-refresh-label" }
        let fiveHourRow = view.descendants(ofType: NSView.self).first { $0.identifier?.rawValue == "quota-row-5-hour" }
        let weeklyRow = view.descendants(ofType: NSView.self).first { $0.identifier?.rawValue == "quota-row-7-day" }
        let quotaMetaLabels = view.descendants(ofType: NSTextField.self).filter {
            $0.identifier?.rawValue.hasPrefix("quota-meta-") == true
        }
        let buttons = view.descendants(ofType: NSButton.self)
        let footerButtons = buttons.map(\.title)
        let buttonTooltips = buttons.compactMap(\.toolTip)
        let apiStatusDot = view.descendants(ofType: NSView.self).first { $0.identifier?.rawValue == "api-status-dot" }
        if #available(macOS 26.0, *) {
            let headerActionContainer = view.descendants(ofType: NSGlassEffectContainerView.self).first {
                $0.identifier?.rawValue == "header-action-glass-container"
            }
            uiExpect(headerActionContainer != nil, "header actions should be grouped in a native glass effect container")
            let headerActionButtons = buttons.filter { ["立即刷新", "设置", "退出"].contains($0.toolTip ?? "") }
            uiExpect(headerActionButtons.count == 3, "header should keep three interactive glass action buttons")
            uiExpect(
                headerActionButtons.allSatisfy { $0.isBordered && $0.bezelStyle == .glass },
                "only functional header controls should use the interactive system glass bezel"
            )
        }
        uiExpect(usage == nil, "usage overview card should be removed from the compact panel")
        uiExpect(runtimeCard == nil, "runtime status card should be removed from the compact panel")
        uiExpect(accountCard == nil, "account card should be removed from the compact panel")
        uiExpect(oldQuotaCards.isEmpty, "old two-card quota layout should be removed from the compact panel")
        uiExpect(compactQuotaList != nil, "compact quota list should be present as inline panel content")
        if let compactQuotaList {
            uiExpect(!(compactQuotaList is GlassCard), "compact quota list should not be wrapped in a separate rounded card")
        }
        uiExpect(headerQuotaSeparator != nil, "header and quota rows should be separated by a simple divider")
        uiExpect(resetQuotaSeparator != nil, "reset credits row should be separated by a simple divider")
        for separator in [headerQuotaSeparator, resetQuotaSeparator] {
            guard let separator,
                  let cgColor = separator.layer?.backgroundColor,
                  let separatorColor = NSColor(cgColor: cgColor) else { continue }
            uiExpect(colorMatches(separatorColor, DesignColors.separatorGray, tolerance: 0.02), "quota panel dividers should use the shared gray separator color")
        }
        uiExpect(segmentBars.count == 2, "compact quota list should use two segmented block progress bars")
        uiExpect(headerTitle != nil, "panel header title should remain visible")
        uiExpect(fiveHourLabel != nil, "compact quota list should show the 5-hour limit row")
        uiExpect(weeklyLabel != nil, "compact quota list should show the 7-day limit row")
        uiExpect(fiveHourRow != nil, "5-hour quota row should expose a stable layout identifier")
        uiExpect(weeklyRow != nil, "7-day quota row should expose a stable layout identifier")
        uiExpect(quotaMetaLabels.count == 8, "quota row name, remaining value, remaining label, and reset time should all be identifiable")
        let quotaFontSizes = Set(quotaMetaLabels.map { Int(round($0.font?.pointSize ?? 0)) })
        uiExpect(quotaFontSizes == [12], "quota row name, remaining value, remaining label, and reset time should share the same 12pt font size")
        if let compactQuotaList, let fiveHourRow, let weeklyRow {
            let fiveFrame = compactQuotaList.convert(fiveHourRow.bounds, from: fiveHourRow)
            let weeklyFrame = compactQuotaList.convert(weeklyRow.bounds, from: weeklyRow)
            let rowGap = fiveFrame.minY - weeklyFrame.maxY
            uiExpect(rowGap >= 0 && rowGap <= 4, "5-hour and 7-day quota rows should be tightly stacked with at most 4pt vertical gap")
        }
        uiExpect(resetCountLabel != nil, "reset credits should remain as a separated auxiliary row")
        uiExpect(resetCountLabel?.stringValue == "重置次数：4", "reset credits copy should stay short and left aligned")
        uiExpect(refreshInfoLabel?.stringValue.hasPrefix("刷新：") == true, "reset credits row should include the last quota refresh time on the right")
        uiExpect(resetCountLabel?.stringValue.contains("·") == false, "reset credits row should not use dot separators")
        uiExpect(refreshInfoLabel?.stringValue.contains("·") == false, "last refresh row should not use dot separators")
        uiExpect(refreshInfoLabel?.stringValue.contains("上次限额监控刷新") == false, "last quota refresh copy should stay concise")
        if let compactQuotaList, let resetCountLabel, let refreshInfoLabel {
            let resetFrame = compactQuotaList.convert(resetCountLabel.bounds, from: resetCountLabel)
            let refreshFrame = compactQuotaList.convert(refreshInfoLabel.bounds, from: refreshInfoLabel)
            uiExpect(refreshFrame.minX > resetFrame.maxX, "last refresh time should be right aligned away from reset credits")
            uiExpect(compactQuotaList.bounds.maxX - refreshFrame.maxX <= 4, "last refresh time should align to the right edge of the auxiliary row")
        }
        uiExpect(apiStatusDot != nil, "header should show a small API status light")
        uiExpect(buttonTooltips.contains("立即刷新"), "header should expose manual refresh as an icon button")
        uiExpect(buttonTooltips.contains("设置"), "header should keep the settings gear icon")
        uiExpect(buttonTooltips.contains("退出"), "header should expose quit as an icon button")
        uiExpect(!footerButtons.contains("立即刷新"), "footer should remove the text refresh button")
        uiExpect(!footerButtons.contains("退出"), "footer should remove the text quit button")
        uiExpect(!footerButtons.contains("打开详情面板"), "footer should remove the details button")
        uiExpect(!footerButtons.contains("更多"), "footer should remove the more button")
        uiExpect(!footerButtons.contains("设置"), "footer should remove the text settings button and keep only the header gear")
        for toolTip in ["立即刷新", "设置", "退出"] {
            guard let button = buttons.first(where: { $0.toolTip == toolTip }) else { continue }
            let buttonFrame = view.convert(button.bounds, from: button)
            uiExpect(view.bounds.contains(buttonFrame), "\(toolTip) header icon button should sit inside panel bounds")
        }
        if let headerTitle, let compactQuotaList {
            let headerFrame = view.convert(headerTitle.bounds, from: headerTitle)
            let compactFrame = view.convert(compactQuotaList.bounds, from: compactQuotaList)
            uiExpect(view.bounds.contains(headerFrame), "panel header title should sit inside panel bounds")
            uiExpect(headerFrame.width >= 70, "panel header title should keep visible width in the compact header")
            uiExpect(view.bounds.contains(compactFrame), "compact quota list should sit inside panel bounds")
        }
        if let resetCountLabel {
            let resetFrame = view.convert(resetCountLabel.bounds, from: resetCountLabel)
            uiExpect(view.bounds.contains(resetFrame), "reset credits auxiliary row should be fully visible")
            uiExpect(resetFrame.minY <= 8, "reset credits row should sit close to the panel bottom without visible dead space")
        }
        if let resetCountLabel, let compactQuotaList {
            let resetFrame = compactQuotaList.convert(resetCountLabel.bounds, from: resetCountLabel)
            uiExpect(compactQuotaList.bounds.contains(resetFrame), "reset credits auxiliary row should be fully visible inside the compact quota list")
        }
        for label in [fiveHourLabel, weeklyLabel, resetCountLabel] {
            guard let label else { continue }
            let labelFrame = view.convert(label.bounds, from: label)
            uiExpect(view.bounds.contains(labelFrame), "narrow panel labels should stay inside panel bounds")
        }

        let panelController = QuotaPanelWindowController()
        panelController.updateContent(controller)
        guard let panel = panelController.window,
              let contentView = panel.contentView,
              let hostedView = contentView.subviews.first else {
            fputs("FAIL: panel controller should install a content view\n", stderr)
            exit(1)
        }
        uiExpect(panel.contentViewController == nil, "panel should pin an explicit hosted root view instead of relying on contentViewController resizing")
        uiExpect(hostedView === controller.view, "panel should host the quota controller view as the content view's direct child")
        uiExpect(hostedView.translatesAutoresizingMaskIntoConstraints == false, "panel hosted view should be constraint-driven")
        contentView.layoutSubtreeIfNeeded()
        uiExpect(hostedView.frame.origin == .zero, "panel hosted view should start at the content bounds origin")
        uiExpect(hostedView.frame.size == contentView.bounds.size, "panel hosted view should exactly match panel content bounds")
        uiExpect(panel.frame.height <= 190, "runtime panel height should not contain unnecessary vertical whitespace")

        let weeklyOnlyController = QuotaPopoverViewController(
            model: weeklyOnlyState,
            refreshAction: {},
            detailsAction: {},
            settingsAction: {},
            copyDiagnosticAction: {},
            pauseAutoRefreshAction: {},
            openLogDirectoryAction: {},
            clearLocalCacheAction: {},
            quitAction: {}
        )
        weeklyOnlyController.loadView()
        let weeklyOnlyView = weeklyOnlyController.view
        weeklyOnlyView.frame = NSRect(x: 0, y: 0, width: DesignTokens.panelWidth, height: DesignTokens.panelMaxHeight)
        weeklyOnlyView.layoutSubtreeIfNeeded()
        uiExpect(
            weeklyOnlyView.descendants(ofType: NSView.self).contains { $0.identifier?.rawValue == "quota-row-5-hour" } == false,
            "weekly-only panel should remove the 5-hour quota row"
        )
        uiExpect(
            weeklyOnlyView.descendants(ofType: NSView.self).contains { $0.identifier?.rawValue == "quota-row-7-day" },
            "weekly-only panel should keep the weekly quota row"
        )
        uiExpect(weeklyOnlyView.descendants(ofType: QuotaSegmentedProgressView.self).count == 1, "weekly-only panel should render exactly one progress bar")

        let weeklyOnlyPanelController = QuotaPanelWindowController()
        weeklyOnlyPanelController.updateContent(weeklyOnlyController)
        guard let weeklyOnlyPanel = weeklyOnlyPanelController.window else {
            fputs("FAIL: weekly-only panel controller should create a panel\n", stderr)
            exit(1)
        }
        uiExpect(
            weeklyOnlyPanel.frame.height <= panel.frame.height - 30,
            "weekly-only panel should reduce its height instead of leaving space for the removed 5-hour row"
        )

        print("CodexQuotaUITests passed")
    }
}
