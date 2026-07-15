import AppKit
import Foundation

enum DesignTokens {
    static let panelWidth: CGFloat = 250
    static let panelSidePadding: CGFloat = 12
    static let contentSpacing: CGFloat = 7
    static let cardSpacing: CGFloat = 12
    static let cardPadding: CGFloat = 10
    static let panelCornerRadius: CGFloat = 18
    static let cardCornerRadius: CGFloat = 12
    static let borderWidth: CGFloat = 1
    static let shadowOpacity: Float = 0.18
    static let shadowRadius: CGFloat = 16
    static let statusBadgeWidth: CGFloat = 48
    static let statusBadgeCapsuleWidth: CGFloat = 48
    static let statusBadgeHeight: CGFloat = 24
    static let statusBadgeCornerRadius: CGFloat = 8
    static let panelVerticalGap: CGFloat = 6
    static let panelScreenPadding: CGFloat = 8
    static let panelTopSafetyInset: CGFloat = 6
    static let panelMinHeight: CGFloat = 143
    static let panelSingleLimitMinHeight: CGFloat = 104
    static let panelMaxHeight: CGFloat = 190
    static let quotaCardHeight: CGFloat = 112
    static let compactQuotaCardHeight: CGFloat = 96
    static let compactSingleQuotaCardHeight: CGFloat = 58
    static let usageCardHeight: CGFloat = 132
    static let lowerCardHeight: CGFloat = 140
    static let footerHeight: CGFloat = 28
}

enum DesignColors {
    static let statusGreen = NSColor.systemGreen
    static let statusYellow = NSColor.systemYellow
    static let statusOrange = NSColor.systemOrange
    static let statusRed = NSColor.systemRed
    static let statusBlue = NSColor.systemBlue
    static let statusGray = NSColor.secondaryLabelColor
    static let monitorGreen = NSColor(calibratedRed: 0.12, green: 1.00, blue: 0.52, alpha: 1.00)
    static let monitorYellow = NSColor(calibratedRed: 1.00, green: 0.92, blue: 0.18, alpha: 1.00)
    static let monitorRed = NSColor(calibratedRed: 1.00, green: 0.16, blue: 0.22, alpha: 1.00)
    static let monitorBlue = NSColor(calibratedRed: 0.02, green: 0.24, blue: 1.00, alpha: 1.00)
    static let monitorGray = NSColor(calibratedRed: 0.88, green: 0.91, blue: 0.95, alpha: 1.00)

    static let panelOuterStroke = NSColor(calibratedWhite: 1.0, alpha: 0.18)
    static let panelInnerStroke = NSColor(calibratedWhite: 1.0, alpha: 0.08)
    static let glassTint = NSColor(calibratedWhite: 1.0, alpha: 0.04)
    static let cardBackground = NSColor(calibratedWhite: 1.0, alpha: 0.03)
    static let cardBackgroundStrong = NSColor(calibratedWhite: 1.0, alpha: 0.04)
    static let cardBorder = NSColor(calibratedWhite: 1.0, alpha: 0.14)
    static let separatorGray = NSColor(calibratedWhite: 0.58, alpha: 0.42)
    static let primaryText = NSColor.labelColor
    static let secondaryText = NSColor.secondaryLabelColor
    static let accentText = NSColor.tertiaryLabelColor
}

enum UIStatusValueColor {
    static func forRemainingPercent(_ percent: Int?) -> NSColor {
        guard let value = percent else { return DesignColors.statusGray }
        return QuotaRemainingColorRule.color(for: value)
    }

    static func badgeText(for value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value)%"
    }
}

enum QuotaPanelLoadState: Equatable {
    case loading
    case success
    case staleCache
    case apiError
    case authError
    case networkTimeout
    case runtimeUndetected
}

struct CodexRuntimeStatusSnapshot {
    enum Health: String {
        case online
        case refreshing
        case apiException
        case networkError
        case authError
        case undetected
    }

    let health: Health
    let latencyMs: Int?
    let autoRefreshMinutes: Int
    let activeTaskCount: Int?
    let queueCount: Int?
    let errorSummary: String?
    let isDetected: Bool
    let isRefreshing: Bool

    static let idle = CodexRuntimeStatusSnapshot(
        health: .undetected,
        latencyMs: nil,
        autoRefreshMinutes: 5,
        activeTaskCount: nil,
        queueCount: nil,
        errorSummary: nil,
        isDetected: false,
        isRefreshing: false
    )

    var statusText: String {
        if isRefreshing { return "正在刷新" }
        switch health {
        case .online: return "API 在线"
        case .refreshing: return "正在刷新"
        case .apiException: return "API 异常"
        case .networkError: return "网络异常"
        case .authError: return "未登录/凭据失效"
        case .undetected: return "未检测到运行中任务"
        }
    }
}

struct QuotaPanelViewModel {
    let loadState: QuotaPanelLoadState
    let isRefreshing: Bool
    let viewModel: QuotaViewModel?
    let runtimeStatus: CodexRuntimeStatusSnapshot
    let history: [QuotaHistoryPoint]
    let lastError: String?
    let lastUpdatedAt: Date?
    let refreshIntervalMinutes: Int

    var statusBadgeWindowSummary: QuotaWindowSummary? {
        viewModel?.fiveHourWindowSummary ?? viewModel?.weeklyWindowSummary
    }

    var statusBadgePercent: Int? {
        statusBadgeWindowSummary?.remainingPercent
    }

    var statusBadgeResetText: String? {
        statusBadgeWindowSummary?.resetText
    }

    var statusBadgeLimitLabel: String {
        statusBadgeWindowSummary?.label ?? "限额"
    }

    var isWeeklyOnlyLimit: Bool {
        viewModel?.fiveHourWindowSummary == nil && viewModel?.weeklyWindowSummary != nil
    }

    var visibleQuotaWindowCount: Int {
        [viewModel?.fiveHourWindowSummary, viewModel?.weeklyWindowSummary].compactMap { $0 }.count
    }

    var usesSingleQuotaLayout: Bool {
        visibleQuotaWindowCount == 1
    }

    var isError: Bool {
        loadState == .apiError || loadState == .authError || loadState == .networkTimeout || loadState == .runtimeUndetected
    }
}

struct AutoRefreshIntervalOption: Equatable {
    let seconds: Int
    let title: String

    static let all: [AutoRefreshIntervalOption] = [
        AutoRefreshIntervalOption(seconds: 10, title: "10 秒"),
        AutoRefreshIntervalOption(seconds: 30, title: "30 秒"),
        AutoRefreshIntervalOption(seconds: 60, title: "1 分钟"),
        AutoRefreshIntervalOption(seconds: 300, title: "5 分钟"),
        AutoRefreshIntervalOption(seconds: 900, title: "15 分钟")
    ]

    static let defaultOption = AutoRefreshIntervalOption(seconds: 300, title: "5 分钟")

    static func option(forSeconds seconds: Int) -> AutoRefreshIntervalOption? {
        all.first { $0.seconds == seconds }
    }

    static func validatedSeconds(_ seconds: Int) -> Int {
        option(forSeconds: seconds)?.seconds ?? defaultOption.seconds
    }
}

protocol QuotaSettingsBacking: AnyObject {
    func integer(forKey defaultName: String) -> Int
    func set(_ value: Int, forKey defaultName: String)
}

extension UserDefaults: QuotaSettingsBacking {}

final class QuotaSettingsStore {
    private static let autoRefreshIntervalKey = "autoRefreshIntervalSeconds"
    private let backing: QuotaSettingsBacking

    init(backing: QuotaSettingsBacking = UserDefaults.standard) {
        self.backing = backing
    }

    var autoRefreshIntervalSeconds: Int {
        get {
            AutoRefreshIntervalOption.validatedSeconds(backing.integer(forKey: Self.autoRefreshIntervalKey))
        }
        set {
            backing.set(AutoRefreshIntervalOption.validatedSeconds(newValue), forKey: Self.autoRefreshIntervalKey)
        }
    }
}

enum QuotaRefreshErrorKind {
    case auth
    case infrastructure
    case timeout
    case api
}

@MainActor
final class CodexQuotaBarDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: DesignTokens.statusBadgeWidth)
    private let panelController = QuotaPanelWindowController()
    private let quotaService = QuotaService()
    private let quotaCache = QuotaCache()
    private let historyStore = QuotaHistoryStore()
    private let runtimeMonitor = CodexRuntimeMonitor()
    private let settingsStore = QuotaSettingsStore()
    private var refreshScheduler: RefreshScheduler?
    private var settingsWindowController: NSWindowController?
    private var statusAnimationTimer: Timer?
    private var statusDotPhase: CGFloat = 0
    private var autoRefreshIntervalSeconds = AutoRefreshIntervalOption.defaultOption.seconds

    private var currentToken = UUID().uuidString
    private var isRefreshing = false
    private var refreshPausedUntil: Date?
    private var viewModel: QuotaViewModel?
    private var runtimeStatus = CodexRuntimeStatusSnapshot.idle
    private var lastError: String?
    private var panelState: QuotaPanelLoadState = .loading
    private var history: [QuotaHistoryPoint] = []

    private var refreshInterval: TimeInterval {
        TimeInterval(autoRefreshIntervalSeconds)
    }

    private var refreshIntervalMinutesForStatus: Int {
        max(1, Int(ceil(Double(autoRefreshIntervalSeconds) / 60.0)))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        autoRefreshIntervalSeconds = settingsStore.autoRefreshIntervalSeconds
        history = historyStore.load()
        loadCachedState()
        configureStatusButton()
        renderPopover()
        startStatusAnimation()

        refreshScheduler = RefreshScheduler(interval: refreshInterval) { [weak self] in
            self?.refresh()
        }
        refreshScheduler?.start()
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshScheduler?.stop()
        statusAnimationTimer?.invalidate()
        panelController.close()
        NotificationCenter.default.removeObserver(self)
    }

    private func loadCachedState() {
        guard let cached = quotaCache.load() else {
            panelState = .loading
            updateStatusBadge()
            return
        }

        viewModel = QuotaViewModel(snapshot: cached)
        runtimeStatus = CodexRuntimeStatusSnapshot(
            health: .undetected,
            latencyMs: nil,
            autoRefreshMinutes: refreshIntervalMinutesForStatus,
            activeTaskCount: nil,
            queueCount: nil,
            errorSummary: nil,
            isDetected: false,
            isRefreshing: false
        )
        panelState = .staleCache
        lastError = nil
        updateStatusBadge()
        renderPopover()
    }

    @objc private func refreshFromMenu() {
        refresh()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func copyDiagnosticInfo() {
        let state = panelStateModel
        let text = QuotaDiagnosticFormatter.text(for: state)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func openSettings() {
        closePopover()

        if let window = settingsWindowController?.window, window.isVisible {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = SettingsView(
            selectedIntervalSeconds: autoRefreshIntervalSeconds,
            intervalChanged: { [weak self] seconds in
                self?.setAutoRefreshInterval(seconds: seconds)
            }
        )
        window.title = "设置"
        window.delegate = self
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindowController = NSWindowController(window: window)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindowController?.showWindow(nil)
    }

    private func setAutoRefreshInterval(seconds: Int) {
        let validatedSeconds = AutoRefreshIntervalOption.validatedSeconds(seconds)
        autoRefreshIntervalSeconds = validatedSeconds
        settingsStore.autoRefreshIntervalSeconds = validatedSeconds
        refreshScheduler?.updateInterval(TimeInterval(validatedSeconds))
        runtimeStatus = CodexRuntimeStatusSnapshot(
            health: runtimeStatus.health,
            latencyMs: runtimeStatus.latencyMs,
            autoRefreshMinutes: refreshIntervalMinutesForStatus,
            activeTaskCount: runtimeStatus.activeTaskCount,
            queueCount: runtimeStatus.queueCount,
            errorSummary: runtimeStatus.errorSummary,
            isDetected: runtimeStatus.isDetected,
            isRefreshing: runtimeStatus.isRefreshing
        )
        updateStatusBadge()
        renderPopover()
    }

    @objc private func pauseAutoRefresh() {
        refreshScheduler?.pause(for: 3600)
        runtimeStatus = CodexRuntimeStatusSnapshot(
            health: runtimeStatus.health,
            latencyMs: runtimeStatus.latencyMs,
            autoRefreshMinutes: refreshIntervalMinutesForStatus,
            activeTaskCount: runtimeStatus.activeTaskCount,
            queueCount: runtimeStatus.queueCount,
            errorSummary: "已暂停 1 小时",
            isDetected: runtimeStatus.isDetected,
            isRefreshing: runtimeStatus.isRefreshing
        )
        refreshPausedUntil = Date().addingTimeInterval(3600)
        updateStatusBadge()
        renderPopover()
    }

    @objc private func openLogDirectory() {
        let url = FileManager.default.codexQuotaBarContainerURL
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        NSWorkspace.shared.open(url)
    }

    @objc private func clearLocalCache() {
        historyStore.clear()
        quotaCache.clear()
        history = []
        if let snapshot = viewModel?.snapshot {
            self.panelState = .staleCache
            self.viewModel = QuotaViewModel(snapshot: snapshot)
        }
        lastError = "已清除本地缓存"
        updateStatusBadge()
        renderPopover()
    }

    @objc private func openDetailsPanel() {
        refresh()
    }

    private var panelStateModel: QuotaPanelViewModel {
        QuotaPanelViewModel(
            loadState: panelState,
            isRefreshing: isRefreshing,
            viewModel: viewModel,
            runtimeStatus: runtimeStatus,
            history: history,
            lastError: lastError,
            lastUpdatedAt: viewModel?.snapshot.fetchedAt,
            refreshIntervalMinutes: refreshIntervalMinutesForStatus
        )
    }

    private func refresh() {
        if isRefreshing { return }
        if let pauseUntil = refreshPausedUntil, pauseUntil > Date() {
            return
        }

        isRefreshing = true
        panelState = .loading
        updateStatusBadge()
        renderPopover()

        let localToken = UUID().uuidString
        currentToken = localToken
        let start = Date()
        quotaService.fetchQuota { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.currentToken == localToken else { return }
                let latency = max(1, Int(Date().timeIntervalSince(start) * 1000))
                self.isRefreshing = false
                switch result {
                case .success(let snapshot):
                    let effectiveSnapshot = snapshot
                    let viewModel = QuotaViewModel(snapshot: effectiveSnapshot)
                    self.viewModel = viewModel
                    self.runtimeStatus = self.runtimeMonitor.refreshStatus(
                        from: viewModel,
                        refreshInProgress: false,
                        autoRefreshMinutes: self.refreshIntervalMinutesForStatus,
                        latencyMs: latency
                    )
                    self.history = self.historyStore.record(
                        snapshot: effectiveSnapshot,
                        at: effectiveSnapshot.fetchedAt
                    )
                    self.lastError = nil
                    switch QuotaRefreshSuccessClassifier.classify(
                        snapshot: effectiveSnapshot
                    ) {
                    case .success:
                        self.panelState = .success
                    case .invalidQuotaPayload:
                        self.panelState = .apiError
                        self.lastError = "未返回有效限额数据"
                    }
                    self.quotaCache.save(snapshot: effectiveSnapshot)
                case .failure(let error):
                    self.runtimeStatus = self.runtimeMonitor.failureStatus(
                        autoRefreshMinutes: self.refreshIntervalMinutesForStatus,
                        latencyMs: latency,
                        error: error
                    )
                    self.lastError = CodexServiceFailureClassifier.userFacingMessage(for: error)
                    switch self.classify(error: error) {
                    case .auth:
                        self.panelState = .authError
                    case .infrastructure:
                        self.panelState = .apiError
                    case .timeout:
                        self.panelState = .networkTimeout
                    case .api:
                        self.panelState = .apiError
                    }
                    if self.viewModel == nil {
                        self.panelState = self.runtimeStatus.isDetected ? .runtimeUndetected : self.panelState
                    }
                }
                if self.viewModel == nil {
                    self.panelState = .runtimeUndetected
                }
                self.refreshPausedUntil = nil
                self.updateStatusBadge()
                self.renderPopover()
            }
        }
    }

    private func classify(error: Error) -> QuotaRefreshErrorKind {
        let message = CodexServiceFailureClassifier.message(for: error).lowercased()
        if message.contains("sqlite")
            || message.contains("state")
            || message.contains("initialize")
            || message.contains("failed to initialize") {
            return .infrastructure
        }
        switch CodexServiceFailureClassifier.classify(message) {
        case .auth:
            return .auth
        case .network:
            return .timeout
        case .api:
            return .api
        }
    }

    private func updateStatusBadge() {
        let model = panelStateModel
        guard let button = statusItem.button else { return }
        button.title = ""
        button.image = MenuBarStatusView.image(for: model, dotPhase: statusDotPhase)
        button.imagePosition = .imageOnly
        button.toolTip = MenuBarStatusView.accessibilityText(for: model)
        button.setAccessibilityTitle(MenuBarStatusView.accessibilityText(for: model))
    }

    private func startStatusAnimation() {
        statusAnimationTimer?.invalidate()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let elapsed = Date().timeIntervalSinceReferenceDate
                let duration = MenuBarStatusView.dotBreathingDuration
                self.statusDotPhase = CGFloat(elapsed.truncatingRemainder(dividingBy: duration) / duration)
                self.updateStatusBadge()
            }
        }
        statusAnimationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.isHidden = false
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if panelController.isShown {
            closePopover()
        } else {
            renderPopover()
            panelController.show(relativeTo: button)
        }
    }

    private func closePopover() {
        panelController.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == settingsWindowController?.window else { return }
        settingsWindowController = nil
    }

    private func renderPopover() {
        let controller = QuotaPopoverViewController(
            model: panelStateModel,
            refreshAction: { [weak self] in self?.refreshFromMenu() },
            detailsAction: { [weak self] in self?.openDetailsPanel() },
            settingsAction: { [weak self] in self?.openSettings() },
            copyDiagnosticAction: { [weak self] in self?.copyDiagnosticInfo() },
            pauseAutoRefreshAction: { [weak self] in self?.pauseAutoRefresh() },
            openLogDirectoryAction: { [weak self] in self?.openLogDirectory() },
            clearLocalCacheAction: { [weak self] in self?.clearLocalCache() },
            quitAction: { [weak self] in self?.quit() }
        )
        panelController.updateContent(controller)
    }
}

@MainActor
final class QuotaPanelWindowController: NSWindowController {
    private var localDismissMonitor: Any?
    private var globalDismissMonitor: Any?
    private var anchorScreenRect: NSRect?
    private var hostedViewController: NSViewController?
    private var hostedConstraints: [NSLayoutConstraint] = []

    var isShown: Bool {
        window?.isVisible == true
    }

    init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: DesignTokens.panelWidth, height: DesignTokens.panelMinHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isMovable = false
        panel.title = "Codex 限额监控"
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: DesignTokens.panelWidth, height: DesignTokens.panelMinHeight))
        contentView.autoresizingMask = [.width, .height]
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = contentView
        super.init(window: panel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateContent(_ controller: NSViewController) {
        guard let panel = window else { return }
        let wasShown = panel.isVisible
        let previousTop = panel.frame.maxY

        controller.loadViewIfNeeded()
        let rootView = controller.view
        let targetSize = fittingPanelSize(for: rootView)
        panel.setContentSize(targetSize)
        installHostedView(rootView, in: panel)
        hostedViewController = controller

        if wasShown {
            var frame = panel.frame
            frame.origin.y = previousTop - frame.height
            panel.setFrame(frame, display: true)
        }
    }

    func show(relativeTo button: NSStatusBarButton) {
        guard let panel = window,
              let anchorRect = Self.statusButtonScreenRect(for: button) else {
            return
        }
        anchorScreenRect = anchorRect
        let visibleFrame = Self.screen(containing: anchorRect)?.visibleFrame ?? NSScreen.main?.visibleFrame ?? anchorRect
        let size = panel.frame.size == .zero
            ? NSSize(width: DesignTokens.panelWidth, height: DesignTokens.panelMinHeight)
            : panel.frame.size
        let frame = Self.panelFrame(
            anchorScreenRect: anchorRect,
            panelSize: size,
            visibleFrame: visibleFrame
        )
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        startDismissMonitoring()
    }

    override func close() {
        window?.orderOut(nil)
        stopDismissMonitoring()
    }

    static func panelFrame(
        anchorScreenRect: NSRect,
        panelSize: NSSize,
        visibleFrame: NSRect
    ) -> NSRect {
        let insetVisibleFrame = visibleFrame.insetBy(
            dx: DesignTokens.panelScreenPadding,
            dy: DesignTokens.panelScreenPadding
        )
        let minX = insetVisibleFrame.minX
        let maxX = insetVisibleFrame.maxX - panelSize.width
        let rawX = anchorScreenRect.midX - panelSize.width / 2
        let x = min(max(rawX, minX), maxX)

        let minY = insetVisibleFrame.minY
        let preferredTop = anchorScreenRect.minY - DesignTokens.panelVerticalGap
        let safeTop = visibleFrame.maxY - DesignTokens.panelTopSafetyInset
        let panelTop = min(preferredTop, safeTop)
        let maxY = max(minY, (visibleFrame.maxY - DesignTokens.panelTopSafetyInset) - panelSize.height)
        let rawY = panelTop - panelSize.height
        let y = min(max(rawY, minY), maxY)

        return NSRect(x: x, y: y, width: panelSize.width, height: panelSize.height)
    }

    private func fittingPanelSize(for view: NSView) -> NSSize {
        view.frame = NSRect(x: 0, y: 0, width: DesignTokens.panelWidth, height: DesignTokens.panelMaxHeight)
        view.layoutSubtreeIfNeeded()
        let fittingHeight = ceil(view.fittingSize.height)
        let height = min(max(fittingHeight, DesignTokens.panelSingleLimitMinHeight), DesignTokens.panelMaxHeight)
        return NSSize(width: DesignTokens.panelWidth, height: height)
    }

    private func installHostedView(_ hostedView: NSView, in panel: NSWindow) {
        guard let contentView = panel.contentView else { return }
        hostedConstraints.forEach { $0.isActive = false }
        hostedConstraints.removeAll()
        contentView.subviews.forEach { $0.removeFromSuperview() }

        hostedView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hostedView)
        hostedConstraints = [
            hostedView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ]
        NSLayoutConstraint.activate(hostedConstraints)
        contentView.needsLayout = true
        contentView.layoutSubtreeIfNeeded()
    }

    private static func statusButtonScreenRect(for button: NSStatusBarButton) -> NSRect? {
        guard let window = button.window else { return nil }
        let windowRect = button.convert(button.bounds, to: nil)
        return window.convertToScreen(windowRect)
    }

    private static func screen(containing rect: NSRect) -> NSScreen? {
        let center = NSPoint(x: rect.midX, y: rect.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
            ?? NSScreen.screens.first { $0.frame.intersects(rect) }
    }

    private func startDismissMonitoring() {
        stopDismissMonitoring()
        localDismissMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closeIfEventIsOutsidePanelAndAnchor(event)
            return event
        }
        globalDismissMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closeIfGlobalEventIsOutsideAnchor(event)
        }
    }

    private func stopDismissMonitoring() {
        if let localDismissMonitor {
            NSEvent.removeMonitor(localDismissMonitor)
            self.localDismissMonitor = nil
        }
        if let globalDismissMonitor {
            NSEvent.removeMonitor(globalDismissMonitor)
            self.globalDismissMonitor = nil
        }
    }

    private func closeIfEventIsOutsidePanelAndAnchor(_ event: NSEvent) {
        guard isShown else { return }
        if event.window === window {
            return
        }
        if let eventWindow = event.window,
           let anchorScreenRect,
           anchorScreenRect.contains(Self.screenPoint(for: event, in: eventWindow)) {
            return
        }
        close()
    }

    private func closeIfGlobalEventIsOutsideAnchor(_ event: NSEvent) {
        guard isShown else { return }
        let screenPoint = Self.globalScreenPoint(for: event)
        if Self.shouldDismissForGlobalClick(at: screenPoint, anchorScreenRect: anchorScreenRect) {
            close()
        }
    }

    static func shouldDismissForGlobalClick(at screenPoint: NSPoint, anchorScreenRect: NSRect?) -> Bool {
        guard let anchorScreenRect else { return true }
        return !anchorScreenRect.contains(screenPoint)
    }

    private static func globalScreenPoint(for event: NSEvent) -> NSPoint {
        if let window = event.window {
            return screenPoint(for: event, in: window)
        }
        return NSEvent.mouseLocation
    }

    private static func screenPoint(for event: NSEvent, in window: NSWindow) -> NSPoint {
        let rect = NSRect(origin: event.locationInWindow, size: .zero)
        return window.convertToScreen(rect).origin
    }
}

final class MenuBarStatusView {
    struct BadgeLayout {
        let percentText: String
        let resetText: String
        let capsuleColor: NSColor
        let monitorDotColor: NSColor
        let monitorDotStrokeColor: NSColor
        let monitorDotAlpha: CGFloat
        let monitorDotGlowAlpha: CGFloat
        let monitorDotGlowInset: CGFloat
        let monitorDotStrokeWidth: CGFloat
        let capsuleFillAlpha: CGFloat
        let capsuleCornerRadius: CGFloat
        let capsuleFrame: NSRect
        let percentTextFrame: NSRect
        let monitorDotFrame: NSRect
        let resetTextFrame: NSRect
        let showsQuotaPieGlyph: Bool
    }

    static let dotBreathingDuration: TimeInterval = 3.6

    static func layout(for model: QuotaPanelViewModel, dotPhase: CGFloat = 0, now: Date = Date()) -> BadgeLayout {
        let percentText = badgeNumberText(for: model.statusBadgePercent)
        let resetText = badgeResetText(for: model, now: now)
        let refreshing = isRefreshingStatus(for: model)
        let size = NSSize(width: DesignTokens.statusBadgeWidth, height: DesignTokens.statusBadgeHeight)
        let capsuleFrame = NSRect(x: 0, y: 0, width: DesignTokens.statusBadgeCapsuleWidth, height: size.height)
        let percentFont = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        let percentWidth = ceil((percentText as NSString).size(withAttributes: [.font: percentFont]).width)
        let dotSize: CGFloat = 3.5
        let dotGap: CGFloat = 3
        let groupWidth = percentWidth + dotGap + dotSize
        let groupX = min(max(6, capsuleFrame.midX - groupWidth / 2), capsuleFrame.maxX - groupWidth - 6)
        let percentTextFrame = NSRect(x: groupX, y: 12, width: percentWidth, height: 10)
        let baseMonitorDotFrame = NSRect(x: percentTextFrame.maxX + dotGap, y: 15, width: dotSize, height: dotSize)
        let dotScale = dotBreathingScale(for: dotPhase)
        let dotExpansion = dotSize * (dotScale - 1) / 2
        let monitorDotFrame = baseMonitorDotFrame.insetBy(dx: -dotExpansion, dy: -dotExpansion)
        let resetFont = NSFont.monospacedDigitSystemFont(ofSize: 7.5, weight: .medium)
        let resetWidth = ceil((resetText as NSString).size(withAttributes: [.font: resetFont]).width)
        let resetX = min(max(5, capsuleFrame.midX - resetWidth / 2), capsuleFrame.maxX - resetWidth - 5)
        let resetTextFrame = NSRect(
            x: resetX,
            y: 3,
            width: min(resetWidth, max(0, capsuleFrame.width - 10)),
            height: 8.5
        )
        return BadgeLayout(
            percentText: percentText,
            resetText: resetText,
            capsuleColor: capsuleColor(for: model),
            monitorDotColor: monitorDotColor(for: model),
            monitorDotStrokeColor: NSColor.white.withAlphaComponent(0.82),
            monitorDotAlpha: dotBreathingAlpha(for: dotPhase, refreshing: refreshing),
            monitorDotGlowAlpha: dotGlowAlpha(for: dotPhase, refreshing: refreshing),
            monitorDotGlowInset: 1.8,
            monitorDotStrokeWidth: 0.8,
            capsuleFillAlpha: 0.68,
            capsuleCornerRadius: DesignTokens.statusBadgeCornerRadius,
            capsuleFrame: capsuleFrame,
            percentTextFrame: percentTextFrame,
            monitorDotFrame: monitorDotFrame,
            resetTextFrame: resetTextFrame,
            showsQuotaPieGlyph: false
        )
    }

    static func image(for model: QuotaPanelViewModel, dotPhase: CGFloat = 0) -> NSImage {
        let size = NSSize(width: DesignTokens.statusBadgeWidth, height: DesignTokens.statusBadgeHeight)
        let layout = layout(for: model, dotPhase: dotPhase)
        let image = NSImage(size: size)
        image.lockFocus()

        let capsulePath = NSBezierPath(
            roundedRect: layout.capsuleFrame.insetBy(dx: 1, dy: 2),
            xRadius: layout.capsuleCornerRadius,
            yRadius: layout.capsuleCornerRadius
        )
        layout.capsuleColor.withAlphaComponent(layout.capsuleFillAlpha).setFill()
        capsulePath.fill()
        NSColor(calibratedWhite: 1.0, alpha: 0.22).setStroke()
        capsulePath.lineWidth = 1
        capsulePath.stroke()

        let percentFont = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold)
        let percentAttributes: [NSAttributedString.Key: Any] = [
            .font: percentFont,
            .foregroundColor: NSColor.white.withAlphaComponent(0.95)
        ]
        (layout.percentText as NSString).draw(in: layout.percentTextFrame, withAttributes: percentAttributes)

        let glowFrame = layout.monitorDotFrame.insetBy(dx: -layout.monitorDotGlowInset, dy: -layout.monitorDotGlowInset)
        let glowPath = NSBezierPath(ovalIn: glowFrame)
        layout.monitorDotColor.withAlphaComponent(layout.monitorDotGlowAlpha).setFill()
        glowPath.fill()
        let dotPath = NSBezierPath(ovalIn: layout.monitorDotFrame)
        layout.monitorDotColor.withAlphaComponent(layout.monitorDotAlpha).setFill()
        dotPath.fill()
        layout.monitorDotStrokeColor.setStroke()
        dotPath.lineWidth = layout.monitorDotStrokeWidth
        dotPath.stroke()

        let resetAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 7.5, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.88)
        ]
        (layout.resetText as NSString).draw(in: layout.resetTextFrame, withAttributes: resetAttributes)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    static func accessibilityText(for model: QuotaPanelViewModel) -> String {
        let badgeLayout = layout(for: model)
        let running = model.isRefreshing ? "正在刷新" : model.runtimeStatus.statusText
        return "Codex \(model.statusBadgeLimitLabel)限额：\(badgeLayout.percentText)，\(badgeLayout.resetText)，\(running)"
    }

    private static func capsuleColor(for model: QuotaPanelViewModel) -> NSColor {
        guard let percent = model.statusBadgePercent else {
            return DesignColors.statusGray
        }
        return QuotaRemainingColorRule.color(for: percent)
    }

    private static func monitorDotColor(for model: QuotaPanelViewModel) -> NSColor {
        if isRefreshingStatus(for: model) {
            return DesignColors.monitorBlue
        }
        switch model.loadState {
        case .apiError, .authError, .networkTimeout:
            return DesignColors.monitorRed
        case .runtimeUndetected:
            return DesignColors.monitorYellow
        case .loading:
            return DesignColors.monitorBlue
        case .success, .staleCache:
            break
        }
        switch model.runtimeStatus.health {
        case .online:
            return DesignColors.monitorGreen
        case .refreshing:
            return DesignColors.monitorBlue
        case .apiException, .networkError, .authError:
            return DesignColors.monitorRed
        case .undetected:
            return DesignColors.monitorYellow
        }
    }

    private static func isRefreshingStatus(for model: QuotaPanelViewModel) -> Bool {
        model.isRefreshing || model.runtimeStatus.isRefreshing || model.loadState == .loading
    }

    private static func compactResetText(_ resetText: String?) -> String {
        guard let resetText, !resetText.isEmpty else {
            return "--:--"
        }
        let compact = resetText.replacingOccurrences(of: " 重置", with: "")
        return compact.split(separator: " ").last.map(String.init) ?? compact
    }

    private static func badgeResetText(for model: QuotaPanelViewModel, now: Date) -> String {
        guard model.isWeeklyOnlyLimit,
              let resetAt = model.statusBadgeWindowSummary?.resetAt else {
            return compactResetText(model.statusBadgeResetText)
        }

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = calendar.isDate(resetAt, inSameDayAs: now) ? "HH:mm" : "M/d"
        return formatter.string(from: resetAt)
    }

    private static func badgeNumberText(for percent: Int?) -> String {
        guard let percent else {
            return "--"
        }
        return "\(percent)"
    }

    private static func dotBreathingAlpha(for phase: CGFloat, refreshing: Bool = false) -> CGFloat {
        if refreshing {
            return 0.86 + dotBreathingProgress(for: phase) * 0.14
        }
        return 0.45 + dotBreathingProgress(for: phase) * 0.55
    }

    private static func dotBreathingScale(for phase: CGFloat) -> CGFloat {
        return 0.9 + dotBreathingProgress(for: phase) * 0.18
    }

    private static func dotGlowAlpha(for phase: CGFloat, refreshing: Bool) -> CGFloat {
        if refreshing {
            return 0.42 + dotBreathingProgress(for: phase) * 0.22
        }
        return dotBreathingAlpha(for: phase) * 0.34
    }

    private static func dotBreathingProgress(for phase: CGFloat) -> CGFloat {
        let normalizedPhase = phase - floor(phase)
        let angle = Double(normalizedPhase) * 2 * Double.pi - Double.pi / 2
        return CGFloat((sin(angle) + 1) / 2)
    }
}

final class QuotaPopoverViewController: NSViewController {
    private let model: QuotaPanelViewModel
    private let refreshAction: () -> Void
    private let detailsAction: () -> Void
    private let settingsAction: () -> Void
    private let copyDiagnosticAction: () -> Void
    private let pauseAutoRefreshAction: () -> Void
    private let openLogDirectoryAction: () -> Void
    private let clearLocalCacheAction: () -> Void
    private let quitAction: () -> Void

    init(
        model: QuotaPanelViewModel,
        refreshAction: @escaping () -> Void,
        detailsAction: @escaping () -> Void,
        settingsAction: @escaping () -> Void,
        copyDiagnosticAction: @escaping () -> Void,
        pauseAutoRefreshAction: @escaping () -> Void,
        openLogDirectoryAction: @escaping () -> Void,
        clearLocalCacheAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) {
        self.model = model
        self.refreshAction = refreshAction
        self.detailsAction = detailsAction
        self.settingsAction = settingsAction
        self.copyDiagnosticAction = copyDiagnosticAction
        self.pauseAutoRefreshAction = pauseAutoRefreshAction
        self.openLogDirectoryAction = openLogDirectoryAction
        self.clearLocalCacheAction = clearLocalCacheAction
        self.quitAction = quitAction
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let popover = QuotaPopoverView(
            model: model,
            refreshAction: refreshAction,
            detailsAction: detailsAction,
            settingsAction: settingsAction,
            copyDiagnosticAction: copyDiagnosticAction,
            pauseAutoRefreshAction: pauseAutoRefreshAction,
            openLogDirectoryAction: openLogDirectoryAction,
            clearLocalCacheAction: clearLocalCacheAction,
            quitAction: quitAction
        )
        view = popover
        view.translatesAutoresizingMaskIntoConstraints = false
        let minimumHeight = model.usesSingleQuotaLayout
            ? DesignTokens.panelSingleLimitMinHeight
            : DesignTokens.panelMinHeight
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: DesignTokens.panelWidth),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: minimumHeight)
        ])
    }
}

private extension NSStackView {
    func addFullWidthArrangedSubview(_ view: NSView) {
        addArrangedSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }
}

class QuotaPopoverView: GlassPanel {
    private let model: QuotaPanelViewModel
    private let refreshAction: () -> Void
    private let detailsAction: () -> Void
    private let settingsAction: () -> Void
    private let copyDiagnosticAction: () -> Void
    private let pauseAutoRefreshAction: () -> Void
    private let openLogDirectoryAction: () -> Void
    private let clearLocalCacheAction: () -> Void
    private let quitAction: () -> Void

    init(
        model: QuotaPanelViewModel,
        refreshAction: @escaping () -> Void,
        detailsAction: @escaping () -> Void,
        settingsAction: @escaping () -> Void,
        copyDiagnosticAction: @escaping () -> Void,
        pauseAutoRefreshAction: @escaping () -> Void,
        openLogDirectoryAction: @escaping () -> Void,
        clearLocalCacheAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) {
        self.model = model
        self.refreshAction = refreshAction
        self.detailsAction = detailsAction
        self.settingsAction = settingsAction
        self.copyDiagnosticAction = copyDiagnosticAction
        self.pauseAutoRefreshAction = pauseAutoRefreshAction
        self.openLogDirectoryAction = openLogDirectoryAction
        self.clearLocalCacheAction = clearLocalCacheAction
        self.quitAction = quitAction
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func configureGlass() {
        super.configureGlass()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = DesignTokens.contentSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: DesignTokens.panelSidePadding),
            stack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -DesignTokens.panelSidePadding),
            stack.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -4),
        ])
        stack.addFullWidthArrangedSubview(headerView())
        stack.addFullWidthArrangedSubview(headerQuotaSeparator())
        if model.viewModel != nil {
            stack.addFullWidthArrangedSubview(compactQuotaListCard())
        } else {
            stack.addFullWidthArrangedSubview(placeholderCard())
        }
    }

    private func headerView() -> NSView {
        let container = NSStackView()
        container.orientation = .horizontal
        container.alignment = .centerY
        container.distribution = .fill
        container.spacing = 6

        let statusDot = StatusIndicatorDotView(color: headerStatusColor())
        statusDot.identifier = NSUserInterfaceItemIdentifier("api-status-dot")
        statusDot.toolTip = headerRuntimeText()

        let title = NSTextField(labelWithString: "Codex 限额监控")
        title.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        title.textColor = DesignColors.primaryText
        title.lineBreakMode = .byTruncatingTail
        title.toolTip = "\(headerRuntimeText()) · \(headerRefreshText())"
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let titleWidth = title.widthAnchor.constraint(greaterThanOrEqualToConstant: 72)
        titleWidth.priority = .defaultHigh
        titleWidth.isActive = true

        container.addArrangedSubview(statusDot)
        container.addArrangedSubview(title)
        container.addArrangedSubview(NSView())
        container.addArrangedSubview(headerActionsView())
        return container
    }

    private func headerActionsView() -> NSView {
        let actions = NSStackView(views: [
            iconButton(
                symbolName: "arrow.clockwise",
                accessibilityDescription: "立即刷新",
                toolTip: "立即刷新",
                action: #selector(handleRefresh)
            ),
            iconButton(
                symbolName: "gearshape",
                accessibilityDescription: "设置",
                toolTip: "设置",
                action: #selector(handleOpenSettings)
            ),
            iconButton(
                symbolName: "xmark",
                accessibilityDescription: "退出",
                toolTip: "退出",
                action: #selector(handleQuit)
            )
        ])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 2
        actions.translatesAutoresizingMaskIntoConstraints = false

        if #available(macOS 26.0, *) {
            let container = NSGlassEffectContainerView()
            container.identifier = NSUserInterfaceItemIdentifier("header-action-glass-container")
            container.translatesAutoresizingMaskIntoConstraints = false
            container.spacing = 2
            container.contentView = actions
            NSLayoutConstraint.activate([
                actions.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                actions.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                actions.topAnchor.constraint(equalTo: container.topAnchor),
                actions.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
            return container
        }

        return actions
    }

    private func iconButton(
        symbolName: String,
        accessibilityDescription: String,
        toolTip: String,
        action: Selector
    ) -> NSButton {
        let button = NSButton()
        if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription) {
            button.image = image
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
        }
        button.contentTintColor = DesignColors.secondaryText
        if #available(macOS 26.0, *) {
            button.isBordered = true
            button.bezelStyle = .glass
        } else {
            button.isBordered = false
        }
        button.target = self
        button.action = action
        button.toolTip = toolTip
        button.setButtonType(.momentaryPushIn)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 20),
            button.heightAnchor.constraint(equalToConstant: 20)
        ])
        return button
    }

    private func headerQuotaSeparator() -> NSView {
        let line = NSView()
        line.identifier = NSUserInterfaceItemIdentifier("header-quota-separator")
        line.translatesAutoresizingMaskIntoConstraints = false
        line.wantsLayer = true
        line.layer?.backgroundColor = DesignColors.separatorGray.cgColor
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    @objc private func handleRefresh() {
        refreshAction()
    }

    @objc private func handleOpenSettings() {
        settingsAction()
    }

    @objc private func handleQuit() {
        quitAction()
    }

    private func headerStatusColor() -> NSColor {
        if model.isRefreshing {
            return DesignColors.statusBlue
        }
        if model.runtimeStatus.health == .online {
            return DesignColors.statusGreen
        }
        switch model.loadState {
        case .loading:
            return DesignColors.statusBlue
        case .success, .staleCache:
            return DesignColors.statusGreen
        case .runtimeUndetected:
            return DesignColors.statusGray
        case .apiError, .authError, .networkTimeout:
            return DesignColors.statusRed
        }
    }

    private func headerRuntimeText() -> String {
        if model.isRefreshing {
            return "正在刷新"
        }
        if model.runtimeStatus.errorSummary != nil && model.runtimeStatus.health != .online {
            return "状态异常"
        }
        switch model.loadState {
        case .loading:
            return "正在刷新"
        case .authError:
            return "未登录/凭据异常"
        case .apiError, .networkTimeout:
            return "接口异常"
        case .runtimeUndetected:
            return model.runtimeStatus.statusText
        case .staleCache:
            return "缓存已更新"
        case .success:
            return model.runtimeStatus.statusText
        }
    }

    private func headerRefreshText() -> String {
        if model.isRefreshing {
            return "刚刚刷新"
        }
        guard let date = model.lastUpdatedAt else {
            return "未刷新"
        }
        return RelativeTimeFormatter.string(from: date)
    }

    private func quotaWindowCards() -> NSView {
        let horizontal = NSStackView()
        horizontal.orientation = .horizontal
        horizontal.spacing = 12
        horizontal.distribution = .fillEqually
        horizontal.translatesAutoresizingMaskIntoConstraints = false
        horizontal.heightAnchor.constraint(equalToConstant: DesignTokens.quotaCardHeight).isActive = true

        let weekly = model.viewModel?.weeklyWindowSummary
        let fiveHour = model.viewModel?.fiveHourWindowSummary

        horizontal.addArrangedSubview(
            QuotaCard(
                title: "7 天限额",
                summary: weekly
            )
        )
        horizontal.addArrangedSubview(
            QuotaCard(
                title: "5 小时限额",
                summary: fiveHour
            )
        )
        return horizontal
    }

    private func compactQuotaListCard() -> NSView {
        let quotaModel = model.viewModel
        return CompactQuotaListView(
            fiveHour: quotaModel?.fiveHourWindowSummary,
            weekly: quotaModel?.weeklyWindowSummary,
            resetCredits: resetCreditsText(from: quotaModel),
            lastRefreshText: auxiliaryRefreshText()
        )
    }

    private func resetCreditsText(from vm: QuotaViewModel?) -> String {
        guard let metrics = vm?.accountMetrics,
              let value = metrics.first(where: { $0.label == "重置次数" })?.value else {
            return "—"
        }
        return value
    }

    private func auxiliaryRefreshText() -> String {
        if model.isRefreshing {
            return "刷新中"
        }
        guard let date = model.lastUpdatedAt else {
            return "未刷新"
        }
        let text = RelativeTimeFormatter.string(from: date)
        return text == "刚刚刷新" ? "刚刚" : text
    }

    private func usageOverviewCard() -> NSView {
        let usage = model.viewModel
        let totalTokens = usage?.summaryValue(for: "lifetimeTokens") ?? "—"
        let peakTokens = usage?.summaryValue(for: "peakDailyTokens") ?? "—"
        let streakDays = usage?.summaryValue(for: "currentStreakDays") ?? "—"

        let sparklinePoints = model.history.suffix(7).map(\.weeklyUsedPercent)
        return UsageOverviewCard(
            totalTokens: totalTokens,
            peakTokens: peakTokens,
            streakDays: streakDays,
            sparklineValues: sparklinePoints
        )
    }

    private func runtimeCard() -> NSView {
        CodexRuntimeStatusCard(status: model.runtimeStatus)
    }

    private func runtimeAndAccountRow() -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .top
        row.distribution = .fillEqually
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: DesignTokens.lowerCardHeight).isActive = true

        let runtime = runtimeCard()
        let account: NSView
        if let quotaModel = model.viewModel, !quotaModel.accountMetrics.isEmpty {
            account = accountCard(from: quotaModel)
        } else {
            account = accountCardFromCacheOrEmpty()
        }

        runtime.setContentHuggingPriority(.defaultLow, for: .horizontal)
        account.setContentHuggingPriority(.defaultLow, for: .horizontal)
        runtime.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        account.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        row.addArrangedSubview(runtime)
        row.addArrangedSubview(account)
        runtime.translatesAutoresizingMaskIntoConstraints = false
        account.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func accountCard(from vm: QuotaViewModel) -> NSView {
        let metrics = vm.accountMetrics
        let values = Dictionary(uniqueKeysWithValues: metrics.map { ($0.label, $0.value) })
        let plan = values["套餐"] ?? "—"
        let credits = values["余额"] ?? "—"
        let reset = values["重置次数"] ?? "—"
        return AccountSummaryCard(plan: plan, credits: credits, resetCount: reset)
    }

    private func accountCardFromCacheOrEmpty() -> NSView {
        return AccountSummaryCard(plan: "—", credits: "—", resetCount: "—")
    }

    private func placeholderCard() -> NSView {
        let card = GlassCard(title: "限额信息")
        let label = NSTextField(labelWithString: model.lastError ?? "暂无可展示的数据")
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = DesignColors.secondaryText
        card.contentStack.addArrangedSubview(label)
        return card
    }

    private func footer() -> NSView {
        FooterActionsView(
            refreshAction: refreshAction,
            detailsAction: detailsAction,
            settingsAction: settingsAction,
            copyDiagnosticAction: copyDiagnosticAction,
            pauseAutoRefreshAction: pauseAutoRefreshAction,
            openLogDirectoryAction: openLogDirectoryAction,
            clearLocalCacheAction: clearLocalCacheAction,
            quitAction: quitAction
        )
    }
}

extension QuotaViewModel {
    var accountMetrics: [QuotaMetric] {
        guard let section = detailSections.first(where: { $0.title == "账户" }) else {
            return []
        }
        return section.metrics
    }

    func summaryValue(for key: String) -> String? {
        guard let usageSection = detailSections.first(where: { $0.title == "用量" }),
              let valueLine = usageSection.lines.first(where: { $0.hasPrefix(tokenSummaryTitle(for: key)) }) else {
            return nil
        }
        let parts = valueLine.split(separator: "：")
        if parts.count == 2 {
            return String(parts[1])
        }
        return nil
    }

    private func tokenSummaryTitle(for key: String) -> String {
        switch key {
        case "lifetimeTokens":
            return "累计 tokens"
        case "peakDailyTokens":
            return "单日峰值 tokens"
        case "currentStreakDays":
            return "连续使用"
        default:
            return ""
        }
    }
}

class GlassPanel: NSView {
    let contentContainer: NSView
    private(set) var usesNativeGlassEffect = false

    override init(frame frameRect: NSRect) {
        self.contentContainer = NSView()
        super.init(frame: frameRect)
        configureGlass()
    }

    required init?(coder: NSCoder) {
        self.contentContainer = NSView()
        super.init(coder: coder)
        configureGlass()
    }

    func configureGlass() {
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = DesignTokens.panelCornerRadius
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = DesignTokens.shadowOpacity
        layer?.shadowRadius = DesignTokens.shadowRadius
        layer?.shadowOffset = CGSize(width: 0, height: -6)

        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.translatesAutoresizingMaskIntoConstraints = false
            glass.cornerRadius = DesignTokens.panelCornerRadius
            glass.style = .regular
            glass.tintColor = nil
            if #available(macOS 27.0, *) {
                glass.effectIsInteractive = false
            }
            addSubview(glass)
            glass.contentView = contentContainer
            NSLayoutConstraint.activate([
                glass.leadingAnchor.constraint(equalTo: leadingAnchor),
                glass.trailingAnchor.constraint(equalTo: trailingAnchor),
                glass.topAnchor.constraint(equalTo: topAnchor),
                glass.bottomAnchor.constraint(equalTo: bottomAnchor),
                contentContainer.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
                contentContainer.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
                contentContainer.topAnchor.constraint(equalTo: glass.topAnchor),
                contentContainer.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
            ])
            usesNativeGlassEffect = true
        } else {
            let effect = NSVisualEffectView()
            effect.translatesAutoresizingMaskIntoConstraints = false
            effect.material = .popover
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.cornerRadius = DesignTokens.panelCornerRadius
            effect.layer?.masksToBounds = true
            effect.layer?.borderWidth = DesignTokens.borderWidth
            effect.layer?.borderColor = DesignColors.cardBorder.cgColor
            effect.layer?.backgroundColor = DesignColors.cardBackground.cgColor
            addSubview(effect)
            effect.addSubview(contentContainer)
            NSLayoutConstraint.activate([
                effect.leadingAnchor.constraint(equalTo: leadingAnchor),
                effect.trailingAnchor.constraint(equalTo: trailingAnchor),
                effect.topAnchor.constraint(equalTo: topAnchor),
                effect.bottomAnchor.constraint(equalTo: bottomAnchor),
                contentContainer.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
                contentContainer.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
                contentContainer.topAnchor.constraint(equalTo: effect.topAnchor),
                contentContainer.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            ])
        }
    }
}

class QuotaGlassView: GlassPanel { }

class GlassCard: NSView {
    let contentStack = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    init(title: String = "") {
        super.init(frame: .zero)
        titleLabel.stringValue = title
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.backgroundColor = nil
        layer?.borderWidth = 0
        layer?.masksToBounds = false

        contentStack.orientation = .vertical
        contentStack.alignment = .width
        contentStack.spacing = 6
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = DesignColors.secondaryText
        titleLabel.lineBreakMode = .byTruncatingTail
        if !titleLabel.stringValue.isEmpty {
            contentStack.addArrangedSubview(titleLabel)
        }
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: DesignTokens.cardPadding),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -DesignTokens.cardPadding),
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: DesignTokens.cardPadding),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -DesignTokens.cardPadding)
        ])
    }
}

class QuotaCard: GlassCard {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    init(title: String, summary: QuotaWindowSummary?) {
        super.init(title: title)
        heightAnchor.constraint(equalToConstant: DesignTokens.quotaCardHeight).isActive = true

        let percent = summary?.remainingPercent ?? 0
        let usedPercent = 100 - percent
        let usedLabel = makeText(value: "已用 / 剩余", style: .secondary, size: 11, weight: .medium)
        let numberLabel = makeText(value: "\(usedPercent)% / \(percent)%", style: .primary, size: 20, weight: .bold)
        let resetLabelText = summary?.resetText ?? "暂无重置信息"

        let statRow = NSStackView()
        statRow.orientation = .horizontal
        statRow.alignment = .centerY
        statRow.distribution = .fill
        statRow.spacing = 10
        statRow.addArrangedSubview(usedLabel)
        statRow.addArrangedSubview(NSView())
        statRow.addArrangedSubview(numberLabel)

        let resetLabel = makeText(value: resetLabelText, style: .secondary, size: 11)
        let progress = QuotaProgressBarView(percent: percent)
        progress.heightAnchor.constraint(equalToConstant: 8).isActive = true
        progress.fillColor = UIStatusValueColor.forRemainingPercent(percent)

        let metaRow = NSStackView()
        metaRow.orientation = .horizontal
        metaRow.alignment = .centerY
        metaRow.distribution = .fill
        metaRow.spacing = 8
        metaRow.addArrangedSubview(resetLabel)
        metaRow.addArrangedSubview(NSView())
        if percent >= 95 {
            metaRow.addArrangedSubview(warningBadgeView())
        } else {
            metaRow.addArrangedSubview(makeText(value: warningLabel(for: percent), style: .secondary, size: 11, weight: .semibold))
        }

        contentStack.addArrangedSubview(statRow)
        contentStack.addArrangedSubview(progress)
        contentStack.addArrangedSubview(metaRow)
    }

    private func makeText(value: String, style: TextStyle, size: CGFloat, weight: NSFont.Weight = .regular) -> NSTextField {
        let field = NSTextField(labelWithString: value)
        field.font = NSFont.systemFont(ofSize: size, weight: weight)
        field.textColor = style == .primary ? DesignColors.primaryText : DesignColors.secondaryText
        field.lineBreakMode = .byTruncatingTail
        field.maximumNumberOfLines = 1
        field.toolTip = value
        return field
    }

    private func warningLabel(for percent: Int) -> String {
        guard percent > 0 else { return "尚无数据" }
        let text = UIStatusColorRule.label(for: percent)
        return text
    }

    private func warningBadgeView() -> NSView {
        let badge = NSTextField(labelWithString: "!")
        badge.font = NSFont.boldSystemFont(ofSize: 11)
        badge.alignment = .center
        badge.textColor = .white
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 8
        badge.layer?.backgroundColor = DesignColors.statusRed.cgColor
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.widthAnchor.constraint(equalToConstant: 16).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 16).isActive = true
        return badge
    }

    enum TextStyle {
        case primary
        case secondary
    }
}

final class StatusIndicatorDotView: NSView {
    private let color: NSColor

    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 7),
            heightAnchor.constraint(equalToConstant: 7)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = bounds.height / 2
        layer?.backgroundColor = color.cgColor
        layer?.shadowColor = color.cgColor
        layer?.shadowOpacity = 0.35
        layer?.shadowRadius = 4
        layer?.shadowOffset = .zero
    }
}

final class CompactQuotaListView: NSView {
    private let contentStack = NSStackView()

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    init(fiveHour: QuotaWindowSummary?, weekly: QuotaWindowSummary?, resetCredits: String, lastRefreshText: String) {
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier("compact-quota-list")
        translatesAutoresizingMaskIntoConstraints = false
        let quotaWindowCount = [fiveHour, weekly].compactMap { $0 }.count
        let height = quotaWindowCount == 1
            ? DesignTokens.compactSingleQuotaCardHeight
            : DesignTokens.compactQuotaCardHeight
        heightAnchor.constraint(equalToConstant: height).isActive = true
        contentStack.orientation = .vertical
        contentStack.alignment = .width
        contentStack.spacing = 4
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            contentStack.topAnchor.constraint(equalTo: topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        if let fiveHour {
            contentStack.addArrangedSubview(
                quotaRow(title: "5 小时", summary: fiveHour, identifier: "quota-row-5-hour")
            )
        }
        if let weekly {
            contentStack.addArrangedSubview(
                quotaRow(title: "7 天", summary: weekly, identifier: "quota-row-7-day")
            )
        }
        contentStack.addArrangedSubview(separator())
        contentStack.addArrangedSubview(resetCreditsRow(value: resetCredits, lastRefreshText: lastRefreshText))
    }

    private func quotaRow(title: String, summary: QuotaWindowSummary?, identifier: String) -> NSView {
        let stack = NSStackView()
        stack.identifier = NSUserInterfaceItemIdentifier(identifier)
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.heightAnchor.constraint(equalToConstant: 34).isActive = true

        let percent = summary?.remainingPercent ?? 0
        let color = QuotaRemainingColorRule.color(for: percent)
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.identifier = NSUserInterfaceItemIdentifier("quota-meta-\(identifier)-title")
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = DesignColors.primaryText
        titleLabel.lineBreakMode = .byTruncatingTail

        let percentLabel = NSTextField(labelWithString: "\(percent)%")
        percentLabel.identifier = NSUserInterfaceItemIdentifier("quota-meta-\(identifier)-percent")
        percentLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        percentLabel.textColor = color
        percentLabel.alignment = .right

        let leftLabel = NSTextField(labelWithString: "剩余")
        leftLabel.identifier = NSUserInterfaceItemIdentifier("quota-meta-\(identifier)-remaining")
        leftLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        leftLabel.textColor = DesignColors.secondaryText

        let resetLabel = NSTextField(labelWithString: summary?.resetText ?? "未提供")
        resetLabel.identifier = NSUserInterfaceItemIdentifier("quota-meta-\(identifier)-reset")
        resetLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        resetLabel.textColor = DesignColors.secondaryText
        resetLabel.lineBreakMode = .byTruncatingTail
        resetLabel.maximumNumberOfLines = 1
        resetLabel.toolTip = resetLabel.stringValue

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .firstBaseline
        header.distribution = .fill
        header.spacing = 3
        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(NSView())
        header.addArrangedSubview(percentLabel)
        header.addArrangedSubview(leftLabel)
        header.addArrangedSubview(resetLabel)

        let progress = QuotaSegmentedProgressView(percent: percent, fillColor: color)
        progress.heightAnchor.constraint(equalToConstant: 7).isActive = true

        stack.addArrangedSubview(header)
        stack.addArrangedSubview(progress)
        return stack
    }

    private func separator() -> NSView {
        let line = NSView()
        line.identifier = NSUserInterfaceItemIdentifier("quota-reset-separator")
        line.translatesAutoresizingMaskIntoConstraints = false
        line.wantsLayer = true
        line.layer?.backgroundColor = DesignColors.separatorGray.cgColor
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }

    private func resetCreditsRow(value: String, lastRefreshText: String) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 6

        let resetLabel = NSTextField(labelWithString: "重置次数：\(value)")
        resetLabel.identifier = NSUserInterfaceItemIdentifier("reset-credits-label")
        resetLabel.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        resetLabel.textColor = DesignColors.secondaryText
        resetLabel.lineBreakMode = .byTruncatingTail

        let refreshLabel = NSTextField(labelWithString: "刷新：\(lastRefreshText)")
        refreshLabel.identifier = NSUserInterfaceItemIdentifier("last-refresh-label")
        refreshLabel.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        refreshLabel.textColor = DesignColors.secondaryText
        refreshLabel.alignment = .right
        refreshLabel.lineBreakMode = .byTruncatingTail

        row.addArrangedSubview(resetLabel)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(refreshLabel)
        return row
    }
}

final class QuotaSegmentedProgressView: NSView {
    private let percent: Int
    private let fillColor: NSColor
    private let segmentCount = 16

    init(percent: Int, fillColor: NSColor) {
        self.percent = percent.clamped(to: 0...100)
        self.fillColor = fillColor
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        self.percent = 0
        self.fillColor = DesignColors.statusGray
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard bounds.width > 0, bounds.height > 0 else { return }
        let gap: CGFloat = 2
        let segmentWidth = max(2, (bounds.width - gap * CGFloat(segmentCount - 1)) / CGFloat(segmentCount))
        let filledSegments = Int((Double(segmentCount) * Double(percent) / 100.0).rounded(.toNearestOrAwayFromZero))
        for index in 0..<segmentCount {
            let x = CGFloat(index) * (segmentWidth + gap)
            let rect = NSRect(x: x, y: 1, width: segmentWidth, height: bounds.height - 2)
            let path = NSBezierPath(roundedRect: rect, xRadius: 2.5, yRadius: 2.5)
            let color = index < filledSegments
                ? fillColor
                : NSColor(calibratedWhite: 1.0, alpha: 0.18)
            color.setFill()
            path.fill()
        }
    }
}

enum QuotaRemainingColorRule {
    static func color(for remainingPercent: Int) -> NSColor {
        switch remainingPercent {
        case 20...:
            return DesignColors.statusGreen
        case 6..<20:
            return DesignColors.statusYellow
        default:
            return DesignColors.statusRed
        }
    }
}

enum UIStatusColorRule {
    static func label(for percent: Int) -> String {
        switch percent {
        case 20...:
            return "安全"
        case 6..<20:
            return "注意"
        default:
            return "高风险"
        }
    }
}

class UsageOverviewCard: GlassCard {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    init(totalTokens: String, peakTokens: String, streakDays: String, sparklineValues: [Int]) {
        super.init(title: "用量概览")
        heightAnchor.constraint(equalToConstant: DesignTokens.usageCardHeight).isActive = true

        let grid = NSStackView()
        grid.orientation = .horizontal
        grid.spacing = 8
        grid.alignment = .top
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.heightAnchor.constraint(equalToConstant: 34).isActive = true

        let lifetimeStack = metricStack(title: "累计 Tokens", value: totalTokens)
        let peakStack = metricStack(title: "今日峰值 Tokens", value: peakTokens)
        let streakStack = metricStack(title: "连续使用天数", value: streakDays)
        grid.addArrangedSubview(lifetimeStack)
        grid.addArrangedSubview(peakStack)
        grid.addArrangedSubview(streakStack)
        grid.distribution = .fillEqually

        let sparklineTitle = NSTextField(labelWithString: "7 日趋势")
        sparklineTitle.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        sparklineTitle.textColor = DesignColors.secondaryText

        contentStack.addArrangedSubview(grid)
        contentStack.addArrangedSubview(sparklineTitle)
        if sparklineValues.isEmpty {
            let placeholder = NSTextField(labelWithString: "暂无趋势数据")
            placeholder.font = NSFont.systemFont(ofSize: 12, weight: .medium)
            placeholder.textColor = DesignColors.secondaryText
            contentStack.addArrangedSubview(placeholder)
        } else {
            contentStack.addArrangedSubview(sparklineContainer(values: sparklineValues))
        }
    }

    private func metricStack(title: String, value: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        let titleView = NSTextField(labelWithString: title)
        titleView.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        titleView.textColor = DesignColors.secondaryText
        titleView.lineBreakMode = .byTruncatingTail
        let valueView = NSTextField(labelWithString: value)
        valueView.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        valueView.textColor = DesignColors.primaryText
        valueView.lineBreakMode = .byTruncatingMiddle
        valueView.maximumNumberOfLines = 1
        valueView.toolTip = value
        valueView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(titleView)
        stack.addArrangedSubview(valueView)
        return stack
    }

    private func sparklineContainer(values: [Int]) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.heightAnchor.constraint(equalToConstant: 34).isActive = true
        let sparkline = SparklineView(values: values)
        sparkline.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(sparkline)
        NSLayoutConstraint.activate([
            sparkline.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            sparkline.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            sparkline.topAnchor.constraint(equalTo: container.topAnchor),
            sparkline.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }
}

final class SparklineView: NSView {
    private let values: [Int]

    init(values: [Int]) {
        self.values = values
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        self.values = []
        super.init(coder: coder)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !values.isEmpty else { return }

        let path = NSBezierPath()
        let lineColor = DesignColors.statusBlue
        let bgColor = DesignColors.statusGreen.withAlphaComponent(0.20)
        bgColor.setFill()

        let plotRect = bounds.insetBy(dx: 8, dy: 8)
        let minY = plotRect.minY
        let maxY = plotRect.maxY
        let spacing = values.count > 1 ? plotRect.width / CGFloat(values.count - 1) : 0
        let startX = plotRect.minX
        var points: [NSPoint] = []
        for (index, value) in values.enumerated() {
            let x = spacing == 0 ? plotRect.midX : startX + CGFloat(index) * spacing
            let percent = CGFloat(value.clamped(to: 0...100)) / 100
            let y = maxY - percent * (maxY - minY)
            points.append(NSPoint(x: x, y: y))
        }
        if let first = points.first {
            path.move(to: first)
            for point in points {
                path.line(to: point)
            }
            path.line(to: NSPoint(x: points.last?.x ?? first.x, y: minY))
            path.close()
            path.fill()
            let line = NSBezierPath()
            for (index, point) in points.enumerated() {
                if index == 0 {
                    line.move(to: point)
                } else {
                    line.line(to: point)
                }
            }
            lineColor.setStroke()
            line.lineWidth = 2
            line.lineJoinStyle = .round
            line.stroke()
        }
    }
}

class CodexRuntimeStatusCard: GlassCard {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    init(status: CodexRuntimeStatusSnapshot) {
        super.init(title: "Codex 运行状态")
        heightAnchor.constraint(equalToConstant: DesignTokens.lowerCardHeight).isActive = true

        let chip = NSView()
        chip.wantsLayer = true
        chip.translatesAutoresizingMaskIntoConstraints = false
        chip.layer?.cornerRadius = 8
        chip.layer?.backgroundColor = chipColor(for: status).cgColor
        let chipText = NSTextField(labelWithString: status.statusText)
        chipText.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        chipText.textColor = .white
        chipText.translatesAutoresizingMaskIntoConstraints = false
        chipText.lineBreakMode = .byTruncatingTail
        chipText.maximumNumberOfLines = 1
        chip.addSubview(chipText)
        contentStack.addArrangedSubview(chip)

        NSLayoutConstraint.activate([
            chip.widthAnchor.constraint(equalTo: contentStack.widthAnchor),
            chip.heightAnchor.constraint(equalToConstant: 22),
            chipText.leadingAnchor.constraint(greaterThanOrEqualTo: chip.leadingAnchor, constant: 10),
            chipText.trailingAnchor.constraint(lessThanOrEqualTo: chip.trailingAnchor, constant: -10),
            chipText.centerXAnchor.constraint(equalTo: chip.centerXAnchor),
            chipText.centerYAnchor.constraint(equalTo: chip.centerYAnchor),
        ])

        let latency = status.latencyMs.map { "\($0)ms" } ?? "—"
        var metricViews: [NSView] = [
            makeMetricTile("请求延迟", value: latency),
            makeMetricTile("自动刷新", value: "\(status.autoRefreshMinutes) 分钟")
        ]

        let taskText: String
        let queueText: String
        if status.isDetected {
            taskText = status.activeTaskCount.map(String.init) ?? "—"
            queueText = status.queueCount.map(String.init) ?? "—"
        } else {
            taskText = "未检测"
            queueText = "—"
        }
        metricViews.append(makeMetricTile("任务 / 队列", value: "\(taskText) / \(queueText)"))

        if let error = status.errorSummary, !error.isEmpty {
            metricViews.append(makeMetricTile("最近错误", value: error))
        } else {
            metricViews.append(makeMetricTile("最近错误", value: "无"))
        }

        let metricsGrid = compactMetricGrid(metricViews)
        contentStack.addArrangedSubview(metricsGrid)
    }

    private func compactMetricGrid(_ metrics: [NSView]) -> NSView {
        let outer = NSStackView()
        outer.orientation = .vertical
        outer.spacing = 5
        outer.translatesAutoresizingMaskIntoConstraints = false

        var index = 0
        while index < metrics.count {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 10
            row.distribution = .fillEqually
            row.addArrangedSubview(metrics[index])
            if index + 1 < metrics.count {
                row.addArrangedSubview(metrics[index + 1])
            } else {
                row.addArrangedSubview(NSView())
            }
            outer.addArrangedSubview(row)
            index += 2
        }
        return outer
    }

    private func makeMetricTile(_ key: String, value: String) -> NSView {
        let tile = NSStackView()
        tile.translatesAutoresizingMaskIntoConstraints = false
        tile.spacing = 1
        tile.orientation = .vertical
        tile.alignment = .leading
        let keyView = NSTextField(labelWithString: key)
        keyView.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        keyView.textColor = DesignColors.secondaryText
        keyView.lineBreakMode = .byTruncatingTail
        let valueView = NSTextField(labelWithString: value)
        valueView.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        valueView.textColor = DesignColors.primaryText
        valueView.lineBreakMode = .byTruncatingMiddle
        valueView.maximumNumberOfLines = 1
        valueView.toolTip = value
        valueView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tile.addArrangedSubview(keyView)
        tile.addArrangedSubview(valueView)
        return tile
    }

    private func chipColor(for status: CodexRuntimeStatusSnapshot) -> NSColor {
        switch status.health {
        case .online:
            return DesignColors.statusGreen
        case .refreshing:
            return DesignColors.statusBlue
        case .apiException:
            return DesignColors.statusOrange
        case .networkError:
            return DesignColors.statusRed
        case .authError:
            return DesignColors.statusYellow
        case .undetected:
            return DesignColors.statusGray
        }
    }
}

class AccountSummaryCard: GlassCard {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    init(plan: String, credits: String, resetCount: String) {
        super.init(title: "账户")
        heightAnchor.constraint(equalToConstant: DesignTokens.lowerCardHeight).isActive = true
        let row = NSStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.distribution = .fillEqually
        row.alignment = .top
        row.spacing = 12
        row.addArrangedSubview(makeItem("套餐", plan))
        row.addArrangedSubview(makeItem("余额", credits))
        row.addArrangedSubview(makeItem("重置次数", resetCount))
        contentStack.addArrangedSubview(row)
    }

    private func makeItem(_ title: String, _ value: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 4
        stack.alignment = .leading
        let titleView = NSTextField(labelWithString: title)
        titleView.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleView.textColor = DesignColors.secondaryText
        titleView.lineBreakMode = .byTruncatingTail
        let valueView = NSTextField(labelWithString: value)
        valueView.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        valueView.textColor = DesignColors.primaryText
        valueView.lineBreakMode = .byTruncatingMiddle
        valueView.maximumNumberOfLines = 1
        valueView.toolTip = value
        valueView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(titleView)
        stack.addArrangedSubview(valueView)
        return stack
    }
}

final class FooterActionsView: NSView {
    init(
        refreshAction: @escaping () -> Void,
        detailsAction: @escaping () -> Void,
        settingsAction: @escaping () -> Void,
        copyDiagnosticAction: @escaping () -> Void,
        pauseAutoRefreshAction: @escaping () -> Void,
        openLogDirectoryAction: @escaping () -> Void,
        clearLocalCacheAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) {
        super.init(frame: .zero)
        configure(
            refreshAction: refreshAction,
            detailsAction: detailsAction,
            settingsAction: settingsAction,
            copyDiagnosticAction: copyDiagnosticAction,
            pauseAutoRefreshAction: pauseAutoRefreshAction,
            openLogDirectoryAction: openLogDirectoryAction,
            clearLocalCacheAction: clearLocalCacheAction,
            quitAction: quitAction
        )
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func configure(
        refreshAction: @escaping () -> Void,
        detailsAction: @escaping () -> Void,
        settingsAction: @escaping () -> Void,
        copyDiagnosticAction: @escaping () -> Void,
        pauseAutoRefreshAction: @escaping () -> Void,
        openLogDirectoryAction: @escaping () -> Void,
        clearLocalCacheAction: @escaping () -> Void,
        quitAction: @escaping () -> Void
    ) {
        translatesAutoresizingMaskIntoConstraints = false
        let row = NSStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.orientation = .horizontal
        row.spacing = 8
        row.distribution = .fill

        let refresh = button("立即刷新", width: 70, action: #selector(handleRefresh), target: self)
        refresh.target = self
        refreshActionClosure = refreshAction

        let quitButton = button("退出", width: 52, action: #selector(handleQuit), target: self)
        row.addArrangedSubview(refresh)
        row.addArrangedSubview(NSView())
        row.addArrangedSubview(quitButton)

        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
            row.heightAnchor.constraint(equalToConstant: DesignTokens.footerHeight)
        ])

        self.refreshActionClosure = refreshAction
        self.detailsActionClosure = detailsAction
        self.settingsActionClosure = settingsAction
        self.copyDiagnosticActionClosure = copyDiagnosticAction
        self.pauseAutoRefreshActionClosure = pauseAutoRefreshAction
        self.openLogDirectoryActionClosure = openLogDirectoryAction
        self.clearLocalCacheActionClosure = clearLocalCacheAction
        self.quitActionClosure = quitAction
        _ = refresh
    }

    private var refreshActionClosure: (() -> Void)?
    private var detailsActionClosure: (() -> Void)?
    private var settingsActionClosure: (() -> Void)?
    private var copyDiagnosticActionClosure: (() -> Void)?
    private var pauseAutoRefreshActionClosure: (() -> Void)?
    private var openLogDirectoryActionClosure: (() -> Void)?
    private var clearLocalCacheActionClosure: (() -> Void)?
    private var quitActionClosure: (() -> Void)?

    @objc private func handleRefresh() { refreshActionClosure?() }
    @objc private func handleDetails() { detailsActionClosure?() }
    @objc private func handleSettings() { settingsActionClosure?() }
    @objc private func handleCopyDiagnostic() { copyDiagnosticActionClosure?() }
    @objc private func handlePause() { pauseAutoRefreshActionClosure?() }
    @objc private func handleOpenLogs() { openLogDirectoryActionClosure?() }
    @objc private func handleClearCache() { clearLocalCacheActionClosure?() }
    @objc private func handleQuit() { quitActionClosure?() }
    @objc private func handleMore() { }

    @objc private func handleOpenMore() {}

    @objc private func handleDummy() {}

    private func button(_ title: String, width: CGFloat, action: Selector, target: AnyObject?) -> NSButton {
        let button = NSButton(title: title, target: target, action: action)
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        button.heightAnchor.constraint(equalToConstant: DesignTokens.footerHeight).isActive = true
        return button
    }
}

final class SettingsView: NSViewController {
    private let selectedIntervalSeconds: Int
    private let intervalChanged: (Int) -> Void

    init(
        selectedIntervalSeconds: Int = AutoRefreshIntervalOption.defaultOption.seconds,
        intervalChanged: @escaping (Int) -> Void = { _ in }
    ) {
        self.selectedIntervalSeconds = AutoRefreshIntervalOption.validatedSeconds(selectedIntervalSeconds)
        self.intervalChanged = intervalChanged
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "应用设置")
        title.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        title.alignment = .center
        title.textColor = DesignColors.primaryText
        title.translatesAutoresizingMaskIntoConstraints = false

        let refreshLabel = NSTextField(labelWithString: "自动刷新间隔")
        refreshLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        refreshLabel.textColor = DesignColors.secondaryText
        refreshLabel.translatesAutoresizingMaskIntoConstraints = false

        let intervalPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        intervalPicker.identifier = NSUserInterfaceItemIdentifier("auto-refresh-interval-picker")
        intervalPicker.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        intervalPicker.translatesAutoresizingMaskIntoConstraints = false
        for option in AutoRefreshIntervalOption.all {
            intervalPicker.addItem(withTitle: option.title)
            intervalPicker.lastItem?.tag = option.seconds
        }
        let selectedOption = AutoRefreshIntervalOption.option(forSeconds: selectedIntervalSeconds) ?? AutoRefreshIntervalOption.defaultOption
        intervalPicker.selectItem(withTitle: selectedOption.title)
        intervalPicker.target = self
        intervalPicker.action = #selector(handleIntervalChange(_:))

        let intervalRow = NSStackView(views: [refreshLabel, intervalPicker])
        intervalRow.orientation = .horizontal
        intervalRow.alignment = .centerY
        intervalRow.distribution = .fill
        intervalRow.spacing = 14
        intervalRow.translatesAutoresizingMaskIntoConstraints = false

        let hint = NSTextField(labelWithString: "选择固定间隔后立即生效。")
        hint.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        hint.textColor = DesignColors.secondaryText
        hint.maximumNumberOfLines = 2
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.alignment = .left

        let stack = NSStackView(views: [title, intervalRow, hint])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            intervalPicker.widthAnchor.constraint(equalToConstant: 120),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -18)
        ])
        self.view = view
    }

    @objc private func handleIntervalChange(_ sender: NSPopUpButton) {
        let seconds = sender.selectedItem?.tag ?? AutoRefreshIntervalOption.defaultOption.seconds
        intervalChanged(AutoRefreshIntervalOption.validatedSeconds(seconds))
    }
}

final class QuotaService {
    private let client = CodexAppServerClient()

    func fetchQuota(completion: @escaping (Result<QuotaSnapshot, Error>) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            do {
                let snapshot = try self.client.fetchSnapshot(scope: .quotaOnly)
                DispatchQueue.main.async {
                    completion(.success(snapshot))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}

enum CodexServiceFailureKind: Equatable {
    case auth
    case network
    case api
}

enum CodexServiceFailureClassifier {
    static func classify(_ error: Error) -> CodexServiceFailureKind {
        classify(message(for: error))
    }

    static func classify(_ rawMessage: String) -> CodexServiceFailureKind {
        let message = rawMessage.lowercased()
        let authTokens = [
            "auth", "unauthorized", "not logged in", "logged out", "登录失效", "登录过期",
            "凭据失效", "凭据过期", "需要登录", "login failed", "needs login",
        ]
        if authTokens.contains(where: message.contains) {
            return .auth
        }

        let networkTokens = [
            "timed out", "timeout", "超时", "error sending request", "failed to fetch codex rate limits",
            "could not resolve host", "connection reset", "connection refused", "network is unreachable",
            "tls handshake", "ssl_connect", "wham/usage",
        ]
        if networkTokens.contains(where: message.contains) {
            return .network
        }
        return .api
    }

    static func message(for error: Error) -> String {
        let described = String(describing: error)
        let localized = error.localizedDescription
        guard described != localized, !described.isEmpty else { return localized }
        return described
    }

    static func userFacingMessage(for rawMessage: String) -> String {
        switch classify(rawMessage) {
        case .auth:
            return "未登录/凭据失效"
        case .network:
            return "网络请求失败"
        case .api:
            return "限额服务响应异常"
        }
    }

    static func userFacingMessage(for error: Error) -> String {
        userFacingMessage(for: message(for: error))
    }
}

private func isAuthFailure(_ message: String) -> Bool {
    CodexServiceFailureClassifier.classify(message) == .auth
}

    final class CodexRuntimeMonitor {
    func refreshStatus(
        from viewModel: QuotaViewModel,
        refreshInProgress: Bool,
        autoRefreshMinutes: Int,
        latencyMs: Int?
    ) -> CodexRuntimeStatusSnapshot {
        let processState = detectProcessState()
        let health: CodexRuntimeStatusSnapshot.Health
        if refreshInProgress {
            health = .refreshing
        } else if processState.errorSummary != nil {
            health = .undetected
        } else if processState.isDetected {
            health = .online
        } else {
            health = .undetected
        }
        return CodexRuntimeStatusSnapshot(
            health: health,
            latencyMs: latencyMs,
            autoRefreshMinutes: autoRefreshMinutes,
            activeTaskCount: processState.activeTaskCount,
            queueCount: processState.queueCount,
            errorSummary: processState.errorSummary,
            isDetected: processState.isDetected,
            isRefreshing: refreshInProgress
        )
    }

    func failureStatus(
        autoRefreshMinutes: Int,
        latencyMs: Int,
        error: Error
    ) -> CodexRuntimeStatusSnapshot {
        let process = detectProcessState()
        let rawMessage = CodexServiceFailureClassifier.message(for: error)
        let health: CodexRuntimeStatusSnapshot.Health
        switch CodexServiceFailureClassifier.classify(rawMessage) {
        case .auth:
            health = .authError
        case .network:
            health = .networkError
        case .api:
            health = .apiException
        }
        return CodexRuntimeStatusSnapshot(
            health: health,
            latencyMs: latencyMs,
            autoRefreshMinutes: autoRefreshMinutes,
            activeTaskCount: process.activeTaskCount,
            queueCount: process.queueCount,
            errorSummary: CodexServiceFailureClassifier.userFacingMessage(for: rawMessage),
            isDetected: process.isDetected,
            isRefreshing: false
        )
    }

    func accountAuthAmbiguousState(
        autoRefreshMinutes: Int,
        latencyMs: Int?
    ) -> CodexRuntimeStatusSnapshot {
        let process = detectProcessState()
        return CodexRuntimeStatusSnapshot(
            health: .apiException,
            latencyMs: latencyMs,
            autoRefreshMinutes: autoRefreshMinutes,
            activeTaskCount: process.activeTaskCount,
            queueCount: process.queueCount,
            errorSummary: "凭据状态提示：已返回账户信息但仍提示需凭据校验",
            isDetected: process.isDetected,
            isRefreshing: false
        )
    }

    func authErrorState(autoRefreshMinutes: Int, latencyMs: Int?) -> CodexRuntimeStatusSnapshot {
        let process = detectProcessState()
        return CodexRuntimeStatusSnapshot(
            health: .authError,
            latencyMs: latencyMs,
            autoRefreshMinutes: autoRefreshMinutes,
            activeTaskCount: process.activeTaskCount,
            queueCount: process.queueCount,
            errorSummary: "未登录/凭据失效",
            isDetected: process.isDetected,
            isRefreshing: false
        )
    }

    private func detectProcessState() -> (isDetected: Bool, activeTaskCount: Int?, queueCount: Int?, errorSummary: String?) {
        let applications = NSWorkspace.shared.runningApplications
        let codexApps = applications.filter {
            let name = $0.localizedName?.lowercased() ?? ""
            let bundle = $0.bundleIdentifier?.lowercased() ?? ""
            return name.contains("codex") || bundle.contains("codex")
        }
        if codexApps.isEmpty {
            return (false, nil, nil, "未检测到运行中任务")
        }
        return (true, max(0, codexApps.count), 0, nil)
    }

}

final class RefreshScheduler {
    private var interval: TimeInterval
    private let tick: () -> Void
    private var timer: Timer?
    private var pausedUntil: Date?

    init(interval: TimeInterval, tick: @escaping () -> Void) {
        self.interval = interval
        self.tick = tick
    }

    var currentInterval: TimeInterval {
        interval
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(fire), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pause(for duration: TimeInterval) {
        pausedUntil = Date().addingTimeInterval(duration)
    }

    func updateInterval(_ interval: TimeInterval) {
        let wasRunning = timer != nil
        self.interval = interval
        if wasRunning {
            start()
        }
    }

    @objc private func fire() {
        if let pausedUntil, pausedUntil > Date() {
            return
        }
        tick()
    }
}

enum RelativeTimeFormatter {
    static func string(from date: Date) -> String {
        let delta = max(0, Int(Date().timeIntervalSince(date)))
        if delta < 60 { return "刚刚刷新" }
        if delta < 3600 { return "\(delta / 60) 分钟前" }
        return "\(delta / 3600) 小时前"
    }
}

final class QuotaProgressBarView: NSView {
    private var percent: CGFloat
    fileprivate var fillColor: NSColor = DesignColors.statusGreen {
        didSet {
            fillLayer.backgroundColor = fillColor.cgColor
            setNeedsDisplay(bounds)
        }
    }
    private let fillLayer = CALayer()

    init(percent: Int) {
        self.percent = CGFloat(max(0, min(100, percent))) / 100
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.18).cgColor
        layer?.masksToBounds = true
        fillLayer.backgroundColor = fillColor.cgColor
        layer?.addSublayer(fillLayer)
    }

    required init?(coder: NSCoder) {
        self.percent = 0
        super.init(coder: coder)
    }

    override func layout() {
        super.layout()
        let radius = bounds.height / 2
        layer?.cornerRadius = radius
        fillLayer.cornerRadius = radius
        fillLayer.frame = CGRect(x: 0, y: 0, width: bounds.width * percent, height: bounds.height)
    }
}

enum QuotaColors {
    @available(*, deprecated, message: "legacy alias; use DesignColors")
    static let primaryText = DesignColors.primaryText
    @available(*, deprecated, message: "legacy alias; use DesignColors")
    static let secondaryText = DesignColors.secondaryText
    @available(*, deprecated, message: "legacy alias; use DesignColors")
    static let sectionTitle = DesignColors.secondaryText
    @available(*, deprecated, message: "legacy alias; use DesignColors")
    static let importantText = DesignColors.statusGreen
    @available(*, deprecated, message: "legacy alias; use DesignColors")
    static let accentText = DesignColors.accentText
    @available(*, deprecated, message: "legacy alias; use DesignColors")
    static let errorText = DesignColors.statusRed
    @available(*, deprecated, message: "legacy alias; use DesignColors")
    static let progressFill = DesignColors.statusGreen
    @available(*, deprecated, message: "legacy alias; use DesignColors")
    static let progressTrack = NSColor(calibratedWhite: 1.0, alpha: 0.18)
    @available(*, deprecated, message: "legacy alias; use DesignColors")
    static let cardBackground = DesignColors.cardBackground
    @available(*, deprecated, message: "legacy alias; use DesignColors")
    static let cardBorder = DesignColors.cardBorder
    @available(*, deprecated, message: "legacy alias; use DesignColors")
    static let windowCardBackground = NSColor(calibratedRed: 0.78, green: 1.00, blue: 0.88, alpha: 0.10)
    @available(*, deprecated, message: "legacy alias; use DesignColors")
    static let windowCardBorder = NSColor(calibratedRed: 0.35, green: 0.86, blue: 0.50, alpha: 0.20)
}

enum StatusBadgeRenderer {
    static func statusItemLength(for image: NSImage) -> CGFloat {
        DesignTokens.statusBadgeWidth
    }

    static func image(text: String, isLoading: Bool = false, isError: Bool = false) -> NSImage {
        let displayText = isLoading ? "..." : text
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let textSize = (displayText as NSString).size(withAttributes: textAttributes)
        let width = max(34, ceil(textSize.width) + 10)
        let height: CGFloat = 20
        let image = NSImage(size: NSSize(width: width, height: height))

        image.lockFocus()
        let rect = NSRect(x: 0, y: 0, width: width, height: height)
        let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 2), xRadius: 8, yRadius: 8)

        let color: NSColor
        if isError {
            color = NSColor(calibratedRed: 0.78, green: 0.18, blue: 0.18, alpha: 1)
        } else if isLoading {
            color = NSColor(calibratedWhite: 0.38, alpha: 1)
        } else {
            color = NSColor(calibratedRed: 0.10, green: 0.43, blue: 0.78, alpha: 1)
        }
        color.setFill()
        path.fill()

        let border = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 2.5), xRadius: 7.5, yRadius: 7.5)
        NSColor(calibratedWhite: 1, alpha: 0.22).setStroke()
        border.lineWidth = 1
        border.stroke()

        let textRect = NSRect(
            x: (width - textSize.width) / 2,
            y: (height - textSize.height) / 2 - 0.5,
            width: textSize.width,
            height: textSize.height
        )
        (displayText as NSString).draw(in: textRect, withAttributes: textAttributes)
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}

struct QuotaDiagnosticFormatter {
    static func text(for model: QuotaPanelViewModel) -> String {
        let percentText = UIStatusValueColor.badgeText(for: model.statusBadgePercent)
        let updated = QuotaDiagnosticFormatter.relativeDate(model.lastUpdatedAt)
        var lines = [
            "Codex 限额监控诊断信息",
            "百分比：\(percentText)",
            "运行状态：\(model.runtimeStatus.statusText)",
            "最近刷新：\(updated)"
        ]
        if let state = model.lastError {
            lines.append("错误：\(CodexServiceFailureClassifier.userFacingMessage(for: state))")
        }
        if model.isRefreshing {
            lines.append("正在刷新：是")
        }
        if let vm = model.viewModel, let five = vm.fiveHourWindowSummary {
            lines.append("5 小时余量：\(five.remainingPercent)%")
        }
        if let vm = model.viewModel, let weekly = vm.weeklyWindowSummary {
            lines.append("7 天余量：\(weekly.remainingPercent)%")
        }
        return lines.joined(separator: "\n")
    }

    private static func relativeDate(_ date: Date?) -> String {
        guard let date else { return "未刷新" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}

#if !PREVIEW_RENDERER
@main
enum CodexQuotaBarMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = CodexQuotaBarDelegate()
        app.delegate = delegate
        app.run()
        _ = delegate
    }
}
#endif
