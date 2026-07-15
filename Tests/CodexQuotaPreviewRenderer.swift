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
            "availableCount": 4
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
            let snapshot: QuotaSnapshot
            do {
                snapshot = try CodexAppServerClient().fetchSnapshot()
            } catch {
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
                refreshIntervalMinutes: 5
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
