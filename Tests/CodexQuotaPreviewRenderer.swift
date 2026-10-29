import AppKit
import Foundation

@main
struct CodexQuotaPreviewRenderer {
    private static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func fallbackSnapshot() throws -> QuotaSnapshot {
        let rateLimitJSON = """
        {
          "rateLimits": {
            "limitId": "codex",
            "primary": {
              "usedPercent": 42,
              "windowDurationMins": 10080,
              "resetsAt": 1784538720
            },
            "secondary": null,
            "credits": {
              "hasCredits": false,
              "unlimited": false,
              "balance": "12,345"
            },
            "planType": "prolite",
            "rateLimitReachedType": null
          },
          "rateLimitResetCredits": {
            "availableCount": 4,
            "credits": [
              {"id":"preview-later","resetType":"codexRateLimits","status":"available","expiresAt":1800000000,"title":"重置卡","description":"预览卡片"},
              {"id":"preview-earliest","resetType":"codexRateLimits","status":"available","expiresAt":1795000000,"title":"重置卡","description":"预览卡片"},
              {"id":"preview-last","resetType":"codexRateLimits","status":"available","expiresAt":null,"title":"重置卡","description":"预览卡片"},
              {"id":"preview-middle","resetType":"codexRateLimits","status":"available","expiresAt":1798000000,"title":"重置卡","description":"预览卡片"}
            ]
          }
        }
        """

        let rateLimits = try decode(AccountRateLimitsResponse.self, from: rateLimitJSON)
        return QuotaSnapshot(
            rateLimits: rateLimits,
            fetchedAt: Date()
        )
    }

    static func main() {
        let outputPath = CommandLine.arguments.dropFirst().first ?? "outputs/codex-quota-popover-preview.png"
        do {
            _ = NSApplication.shared
            NSApp.appearance = NSAppearance(named: ProcessInfo.processInfo.environment["QUOTA_PREVIEW_DARK"] == "1" ? .darkAqua : .aqua)
            let snapshot: QuotaSnapshot
            if ProcessInfo.processInfo.environment["QUOTA_PREVIEW_LIVE"] == "1" {
                snapshot = try CodexAppServerClient().fetchSnapshot()
            } else {
                snapshot = try fallbackSnapshot()
            }
            let viewModel = QuotaViewModel(snapshot: snapshot)
            let state = QuotaPanelViewModel(
                loadState: .success,
                isRefreshing: false,
                viewModel: viewModel,
                runtimeStatus: .idle,
                history: [],
                lastError: nil,
                lastUpdatedAt: snapshot.fetchedAt,
                refreshIntervalMinutes: 5,
                tokenTrend: TokenQuotaTrend(days: (0..<7).map { offset in
                    TokenQuotaDay(day: Calendar.current.date(byAdding: .day, value: offset - 6, to: Calendar.current.startOfDay(for: Date()))!,
                                  tokens: [720000, 910000, 840000, 1050000, 930000, 1180000, 1100000][offset], percentagePoints: 2)
                })
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
            let panelController = QuotaPanelWindowController()
            panelController.updateContent(controller)
            guard let panel = panelController.window else {
                throw PreviewError.renderFailed
            }
            let view = controller.view
            view.frame = NSRect(origin: .zero, size: panel.contentLayoutRect.size)
            view.layoutSubtreeIfNeeded()

            func armPreviewConfirmation(_ candidate: NSView) {
                if let button = candidate as? NSButton, button.identifier?.rawValue == "use-reset-credit" { button.performClick(nil) }
                candidate.subviews.forEach(armPreviewConfirmation)
            }
            if ProcessInfo.processInfo.environment["QUOTA_PREVIEW_CONFIRM"] == "1" { armPreviewConfirmation(view) }

            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
                throw PreviewError.renderFailed
            }
            view.cacheDisplay(in: view.bounds, to: rep)
            guard let data = rep.representation(using: .png, properties: [:]) else {
                throw PreviewError.pngEncodingFailed
            }
            try data.write(to: URL(fileURLWithPath: outputPath))
            print(outputPath)
        } catch {
            fputs("预览渲染失败：\(error)\n", stderr)
            exit(1)
        }
    }
}

enum PreviewError: Error {
    case renderFailed
    case pngEncodingFailed
}
