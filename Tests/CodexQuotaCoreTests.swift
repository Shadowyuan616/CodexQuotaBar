import Foundation

@discardableResult
func expect(_ condition: @autoclosure () -> Bool, _ message: String) -> Bool {
    if !condition() {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
    return true
}

func decode<T: Decodable>(_ type: T.Type, _ json: String) -> T {
    let data = Data(json.utf8)
    do {
        return try JSONDecoder().decode(T.self, from: data)
    } catch {
        fputs("FAIL: decode \(T.self): \(error)\n", stderr)
        exit(1)
    }
}

@main
struct CodexQuotaCoreTests {
    static func main() {
        let rateLimitJSON = """
        {
          "rateLimits": {
            "limitId": "codex",
            "limitName": null,
            "primary": {
              "usedPercent": 23,
              "windowDurationMins": 300,
              "resetsAt": 1783254522
            },
            "secondary": {
              "usedPercent": 55,
              "windowDurationMins": 10080,
              "resetsAt": 1783411403
            },
            "credits": {
              "hasCredits": false,
              "unlimited": false,
              "balance": "0"
            },
            "individualLimit": null,
            "planType": "prolite",
            "rateLimitReachedType": null
          },
          "rateLimitsByLimitId": {
            "codex": {
              "limitId": "codex",
              "limitName": null,
              "primary": {
                "usedPercent": 23,
                "windowDurationMins": 300,
                "resetsAt": 1783254522
              },
              "secondary": {
                "usedPercent": 55,
                "windowDurationMins": 10080,
                "resetsAt": 1783411403
              },
              "credits": {
                "hasCredits": false,
                "unlimited": false,
                "balance": "0"
              },
              "individualLimit": null,
              "planType": "prolite",
              "rateLimitReachedType": null
            }
          },
          "rateLimitResetCredits": {
            "availableCount": 4
          }
        }
        """

        let rateLimits = decode(AccountRateLimitsResponse.self, rateLimitJSON)
        let snapshot = QuotaSnapshot(rateLimits: rateLimits, fetchedAt: Date(timeIntervalSince1970: 1783238502))
        let viewModel = QuotaViewModel(snapshot: snapshot, calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)

        let sensitiveSnapshot = QuotaSnapshot(
            rateLimits: rateLimits,
            fetchedAt: Date(timeIntervalSince1970: 1783238502)
        )
        let encodedSensitiveSnapshot = String(
            data: try! JSONEncoder().encode(sensitiveSnapshot),
            encoding: .utf8
        ) ?? ""
        expect(!encodedSensitiveSnapshot.contains("private@example.com"), "persisted quota snapshots must not encode account email")
        expect(!encodedSensitiveSnapshot.contains("\"account\""), "persisted quota snapshots must not encode account metadata")
        expect(!encodedSensitiveSnapshot.contains("\"usage\""), "persisted quota snapshots must not encode token usage")

        expect(snapshot.primaryRemainingPercent == 77, "23 used percent should format as 77 remaining")
        expect(viewModel.statusTitle == "77%", "status title should only show the remaining percent")
        expect(!viewModel.statusTitle.lowercased().contains("codex"), "status title should not include Codex")
        expect(viewModel.detailLines.contains("5 小时窗口：剩余 77%，重置时间 2026-07-05 20:28"), "5h detail should be localized and include reset time")
        expect(viewModel.detailLines.contains("7 天窗口：剩余 45%，重置时间 2026-07-07 16:03"), "7d detail should be localized and include reset time")
        expect(viewModel.detailLines.contains("套餐：prolite"), "plan should be present in Chinese")
        expect(viewModel.detailLines.contains("重置次数：4"), "reset credits should be present in Chinese")
        expect(viewModel.detailSections.map(\.title) == ["限额窗口", "账户", "刷新"], "details should contain only quota-derived sections")
        expect(viewModel.detailSections[0].lines.contains("5 小时窗口：剩余 77%，重置时间 2026-07-05 20:28"), "window section should contain primary window")
        expect(viewModel.detailSections[0].presentation == .quotaWindows, "window section should request dashboard presentation")
        expect(viewModel.detailSections[0].windowSummaries.count == 2, "window section should expose two quota window summaries")
        expect(viewModel.detailSections[0].windowSummaries[0].label == "5 小时", "primary window summary should use a compact label")
        expect(viewModel.detailSections[0].windowSummaries[0].remainingPercent == 77, "primary window summary should keep remaining percent")
        expect(viewModel.detailSections[0].windowSummaries[0].resetText == "20:28 重置", "same-day reset should be compact")
        expect(viewModel.detailSections[0].windowSummaries[1].label == "7 天", "secondary window summary should use a compact label")
        expect(viewModel.detailSections[0].windowSummaries[1].remainingPercent == 45, "secondary window summary should keep remaining percent")
        expect(viewModel.detailSections[0].windowSummaries[1].resetText == "07-07 16:03", "future reset should include compact date and time")
        expect(viewModel.detailSections[1].lines.contains("套餐：prolite"), "account section should contain plan")
        expect(viewModel.detailSections[1].presentation == .metricColumns, "account section should request metric columns")
        expect(viewModel.detailSections[1].metrics.map(\.label) == ["套餐", "余额", "重置次数"], "account metrics should be ready for a three-column row")
        expect(viewModel.detailSections[1].metrics.map(\.value) == ["prolite", "0", "4"], "account metric values should be preserved")
        expect(viewModel.detailSections[2].lines.contains("上次刷新：2026-07-05 16:01"), "refresh section should contain last refresh")

        let weeklyOnlyJSON = """
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
              "balance": "0"
            },
            "planType": "prolite"
          },
          "rateLimitResetCredits": {
            "availableCount": 4
          }
        }
        """
        let weeklyOnlyRateLimits = decode(AccountRateLimitsResponse.self, weeklyOnlyJSON)
        let weeklyOnlySnapshot = QuotaSnapshot(
            rateLimits: weeklyOnlyRateLimits,
            fetchedAt: Date(timeIntervalSince1970: 1783933200)
        )
        let weeklyOnlyViewModel = QuotaViewModel(
            snapshot: weeklyOnlySnapshot,
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 8 * 3600)!
        )
        expect(weeklyOnlyViewModel.fiveHourWindowSummary == nil, "weekly-only payload should not synthesize a 5-hour limit")
        expect(weeklyOnlyViewModel.weeklyWindowSummary?.remainingPercent == 58, "weekly-only payload should preserve weekly remaining quota")
        expect(weeklyOnlyViewModel.statusTitle == "58%", "weekly-only payload should use weekly remaining quota as the status title")
        expect(weeklyOnlyViewModel.detailSections[0].windowSummaries.count == 1, "weekly-only payload should expose exactly one quota summary")
        expect(weeklyOnlyViewModel.detailSections[0].windowSummaries[0].label == "7 天", "weekly-only quota summary should keep the weekly label")

        let empty = QuotaSnapshot(rateLimits: nil, fetchedAt: Date(timeIntervalSince1970: 1783238502))
        let emptyViewModel = QuotaViewModel(snapshot: empty, calendar: Calendar(identifier: .gregorian), timeZone: TimeZone(secondsFromGMT: 8 * 3600)!)
        expect(emptyViewModel.statusTitle == "--", "missing data should show placeholder status without Codex")
        expect(emptyViewModel.detailLines.contains("暂无限额数据。"), "missing data should explain absence in Chinese")

        do {
            let responseLine = #"{"id":3,"result":{"rateLimits":{"limitId":"codex","primary":{"usedPercent":10}}}}"#
            let resultData = try JSONRPCResultEnvelope.extractResultData(from: responseLine, expectedId: 3)
            let object = try JSONSerialization.jsonObject(with: resultData) as? [String: Any]
            let result = object?["rateLimits"] as? [String: Any]
            expect(result?["limitId"] as? String == "codex", "JSON-RPC result helper should return only result payload")
        } catch {
            fputs("FAIL: JSON-RPC result helper threw \(error)\n", stderr)
            exit(1)
        }

        expect(CodexQuotaFetchScope.quotaOnly.requestMethods == ["account/rateLimits/read"], "quota refresh should only request rate limits")
        expect(!CodexQuotaFetchScope.quotaOnly.includesUsage, "quota-only refresh should skip account/usage/read")
        expect(CodexQuotaFetchScope.full.requestMethods == ["account/rateLimits/read"], "full refresh must not request account or token usage data")

        let unifiedAppSnapshot = QuotaSnapshot(
            rateLimits: rateLimits,
            fetchedAt: Date(timeIntervalSince1970: 1783238502)
        )
        expect(
            QuotaRefreshSuccessClassifier.classify(
                snapshot: unifiedAppSnapshot
            ) == .success,
            "valid rate limits should remain successful when the unified app omits account metadata"
        )

        let missingQuotaSnapshot = QuotaSnapshot(
            rateLimits: nil,
            fetchedAt: Date(timeIntervalSince1970: 1783238502)
        )
        expect(
            QuotaRefreshSuccessClassifier.classify(
                snapshot: missingQuotaSnapshot
            ) == .invalidQuotaPayload,
            "a successful response without quota data should be classified as an invalid API payload"
        )

        let executableCandidates = CodexExecutableLocator.defaultCandidatePaths(homeDirectory: "/Users/tester")
        expect(
            executableCandidates.first == "/Applications/ChatGPT.app/Contents/Resources/codex",
            "the unified ChatGPT app should be the first Codex executable candidate"
        )
        expect(
            executableCandidates.contains("/Applications/Codex.app/Contents/Resources/codex"),
            "the legacy Codex app should remain a supported fallback"
        )
        expect(executableCandidates.count == 2, "default executable lookup should only trust system Applications bundles")
        expect(!executableCandidates.contains("/opt/homebrew/bin/codex"), "default executable lookup should not execute Homebrew PATH candidates implicitly")

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexExecutableLocatorTests-\(UUID().uuidString)", isDirectory: true)
        let missingPath = temporaryDirectory.appendingPathComponent("missing-codex").path
        let executablePath = temporaryDirectory.appendingPathComponent("codex").path
        do {
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            try Data("#!/bin/sh\n".utf8).write(to: URL(fileURLWithPath: executablePath))
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executablePath)
            defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

            expect(
                CodexExecutableLocator.firstExecutablePath(
                    in: [missingPath, executablePath],
                    fileManager: .default
                ) == executablePath,
                "the locator should select the first executable candidate"
            )
        } catch {
            fputs("FAIL: executable locator fixture setup failed: \(error)\n", stderr)
            exit(1)
        }

        let childEnvironment = CodexProcessEnvironment.sanitized(from: [
            "HOME": "/Users/tester",
            "CODEX_HOME": "/Users/tester/.codex",
            "CODEX_SANDBOX": "seatbelt",
            "CODEX_SANDBOX_NETWORK_DISABLED": "1",
            "HTTPS_PROXY": "http://127.0.0.1:7890",
            "NO_PROXY": "localhost,127.0.0.1",
            "OPENAI_API_KEY": "must-not-be-inherited",
            "AWS_SECRET_ACCESS_KEY": "must-not-be-inherited",
        ])
        expect(childEnvironment["CODEX_HOME"] == "/Users/tester/.codex", "Codex app-server should inherit CODEX_HOME")
        expect(childEnvironment["CODEX_SANDBOX"] == "seatbelt", "Codex app-server should inherit its runtime sandbox context")
        expect(childEnvironment["HTTPS_PROXY"] == "http://127.0.0.1:7890", "Codex app-server should inherit proxy settings")
        expect(childEnvironment["OPENAI_API_KEY"] == nil, "Codex app-server must not inherit unrelated API keys")
        expect(childEnvironment["AWS_SECRET_ACCESS_KEY"] == nil, "Codex app-server must not inherit unrelated cloud secrets")

        let storageFixture = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexQuotaStorageTests-\(UUID().uuidString)", isDirectory: true)
        let cacheURL = storageFixture.appendingPathComponent("cache/quota-cache.json")
        let historyURL = storageFixture.appendingPathComponent("history/quota-history.json")
        defer { try? FileManager.default.removeItem(at: storageFixture) }

        let cache = QuotaCache(fileURL: cacheURL)
        cache.save(snapshot: sensitiveSnapshot)
        expect(cache.load()?.primaryRemainingPercent == 77, "secured quota cache should remain readable")

        let historyStore = QuotaHistoryStore(fileURL: historyURL)
        _ = historyStore.record(snapshot: sensitiveSnapshot, at: sensitiveSnapshot.fetchedAt)

        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: cacheURL.path)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cacheURL.deletingLastPathComponent().path)
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: historyURL.path)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: historyURL.deletingLastPathComponent().path)
        _ = cache.load()
        _ = historyStore.load()

        do {
            let cacheText = try String(contentsOf: cacheURL, encoding: .utf8)
            expect(!cacheText.contains("private@example.com"), "quota cache must not contain account email")
            expect(!cacheText.contains("lifetimeTokens"), "quota cache must not contain token usage")

            let historyText = try String(contentsOf: historyURL, encoding: .utf8)
            expect(!historyText.contains("totalTokens"), "quota history must not persist total token usage")
            expect(!historyText.contains("dailyPeakTokens"), "quota history must not persist daily token usage")

            let cacheMode = try FileManager.default.attributesOfItem(atPath: cacheURL.path)[.posixPermissions] as? NSNumber
            let historyMode = try FileManager.default.attributesOfItem(atPath: historyURL.path)[.posixPermissions] as? NSNumber
            let cacheDirectoryMode = try FileManager.default.attributesOfItem(atPath: cacheURL.deletingLastPathComponent().path)[.posixPermissions] as? NSNumber
            let historyDirectoryMode = try FileManager.default.attributesOfItem(atPath: historyURL.deletingLastPathComponent().path)[.posixPermissions] as? NSNumber
            expect(cacheMode?.intValue == 0o600, "quota cache file must use 0600 permissions")
            expect(historyMode?.intValue == 0o600, "quota history file must use 0600 permissions")
            expect(cacheDirectoryMode?.intValue == 0o700, "quota cache directory must use 0700 permissions")
            expect(historyDirectoryMode?.intValue == 0o700, "quota history directory must use 0700 permissions")
        } catch {
            fputs("FAIL: secured local storage verification failed: \(error)\n", stderr)
            exit(1)
        }

        print("CodexQuotaCoreTests passed")
    }
}
