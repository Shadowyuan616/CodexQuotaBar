import Foundation
import CryptoKit

enum CodexAppServerClientError: Error, CustomStringConvertible {
    case codexBinaryMissing(String)
    case invalidJSONRPCLine
    case missingJSONRPCResult
    case serverError(String)
    case appServerExited
    case unexpectedEOF

    var description: String {
        switch self {
        case .codexBinaryMissing(let path):
            return "未找到 Codex 可执行文件：\(path)"
        case .invalidJSONRPCLine:
            return "无法解析限额服务返回数据"
        case .missingJSONRPCResult:
            return "限额服务返回数据缺少结果"
        case .serverError(let message):
            return message
        case .appServerExited:
            return "限额服务在请求完成前退出"
        case .unexpectedEOF:
            return "限额服务连接意外关闭"
        }
    }
}

enum CodexQuotaFetchScope {
    case quotaOnly
    case full

    var includesUsage: Bool {
        false
    }

    var requestMethods: [String] {
        ["account/rateLimits/read"]
    }
}

struct CodexExecutableLocator {
    static func defaultCandidatePaths(homeDirectory: String = NSHomeDirectory()) -> [String] {
        [
            "/Applications/ChatGPT.app/Contents/Resources/codex-cli/bin/codex",
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
        ]
    }

    static func firstExecutablePath(
        in candidates: [String],
        fileManager: FileManager = .default
    ) -> String? {
        candidates.first { fileManager.isExecutableFile(atPath: $0) }
    }

    static func resolveExecutablePath(
        fileManager: FileManager = .default,
        homeDirectory: String = NSHomeDirectory()
    ) -> String? {
        firstExecutablePath(in: defaultCandidatePaths(homeDirectory: homeDirectory), fileManager: fileManager)
    }
}

struct CodexProcessEnvironment {
    private static let allowedKeys: Set<String> = [
        "HOME", "TMPDIR", "USER", "LOGNAME", "PATH", "SHELL", "LANG", "LC_ALL",
        "LC_CTYPE", "COMMAND_MODE", "__CF_USER_TEXT_ENCODING",
        "CODEX_HOME", "CODEX_SQLITE_HOME", "CODEX_CI",
        "CODEX_SANDBOX", "CODEX_SANDBOX_NETWORK_DISABLED", "CODEX_PERMISSION_PROFILE",
        "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY",
        "WSS_PROXY", "http_proxy", "https_proxy", "all_proxy", "no_proxy", "wss_proxy",
        "SSL_CERT_FILE", "SSL_CERT_DIR",
    ]

    static func sanitized(from source: [String: String]) -> [String: String] {
        source.filter { allowedKeys.contains($0.key) }
    }
}

struct JSONRPCResultEnvelope {
    static func extractResultData(from line: String, expectedId: Int) throws -> Data {
        let data = Data(line.utf8)
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            responseId(from: object["id"]) == expectedId
        else {
            throw CodexAppServerClientError.invalidJSONRPCLine
        }

        if let error = object["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "限额服务返回未知错误"
            throw CodexAppServerClientError.serverError(message)
        }

        guard let result = object["result"] else {
            throw CodexAppServerClientError.missingJSONRPCResult
        }
        return try JSONSerialization.data(withJSONObject: result)
    }

    static func responseId(from value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let string = value as? String { return Int(string) }
        if let number = value as? NSNumber { return number.intValue }
        return nil
    }
}

final class CodexAppServerClient {
    private let codexPath: String
    private let decoder = JSONDecoder()

    init(codexPath: String? = nil) {
        self.codexPath = codexPath
            ?? CodexExecutableLocator.resolveExecutablePath()
            ?? CodexExecutableLocator.defaultCandidatePaths()[0]
    }

    func fetchSnapshot(scope: CodexQuotaFetchScope = .quotaOnly) throws -> QuotaSnapshot {
        try withSession { request in
            let data = try request("account/rateLimits/read", NSNull())
            return QuotaSnapshot(rateLimits: try self.decoder.decode(AccountRateLimitsResponse.self, from: data), fetchedAt: Date())
        }
    }

    func consumeReset(_ attempt: ResetAttempt) throws -> ResetOutcome {
        try withSession { request in
            let current = try self.decoder.decode(AccountRateLimitsResponse.self, from: request("account/rateLimits/read", NSNull()))
            guard let account = current.accountId, Self.accountScope(account) == attempt.accountScope else {
                throw CodexAppServerClientError.serverError("账户已变化，请切回发起重置的账户")
            }
            var params: [String: Any] = ["idempotencyKey": attempt.key]
            if let creditId = attempt.creditId { params["creditId"] = creditId }
            let data = try request("account/rateLimitResetCredit/consume", params)
            return try self.decoder.decode(ResetResponse.self, from: data).outcome
        }
    }

    static func accountScope(_ accountID: String) -> String {
        SHA256.hash(data: Data(accountID.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func fetchTrendSample() throws -> TokenQuotaSample {
        try withSession { request in
            let before = try self.decoder.decode(AccountRateLimitsResponse.self, from: request("account/rateLimits/read", NSNull()))
            let usage = try self.decoder.decode(TokenUsageResponse.self, from: request("account/usage/read", NSNull()))
            let after = try self.decoder.decode(AccountRateLimitsResponse.self, from: request("account/rateLimits/read", NSNull()))
            let first = QuotaSnapshot(rateLimits: before, fetchedAt: Date()).quotaWindow(matching: 10080)
            let last = QuotaSnapshot(rateLimits: after, fetchedAt: Date()).quotaWindow(matching: 10080)
            guard let account = after.accountId, before.accountId == account,
                  let window = last, let resetAt = window.resetsAt,
                  first?.usedPercent == window.usedPercent, first?.resetsAt == resetAt,
                  let tokens = usage.summary.lifetimeTokens, tokens >= 0 else {
                throw CodexAppServerClientError.serverError("暂未取得一致的 Token 与周额度样本")
            }
            let scope = account + "|" + (after.rateLimits?.planType ?? "")
            let fingerprint = Self.accountScope(scope)
            return TokenQuotaSample(timestamp: Date(), accountScope: fingerprint, totalTokens: tokens,
                                    usedPercent: window.usedPercent, resetsAt: resetAt)
        }
    }

    private func withSession<T>(_ body: (_ request: (String, Any) throws -> Data) throws -> T) throws -> T {
        guard FileManager.default.isExecutableFile(atPath: codexPath) else {
            throw CodexAppServerClientError.codexBinaryMissing(codexPath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: codexPath)
        process.arguments = ["app-server", "--stdio"]
        process.environment = CodexProcessEnvironment.sanitized(from: ProcessInfo.processInfo.environment)

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        // Drain diagnostics without retaining credentials or unbounded subprocess output.
        stderr.fileHandleForReading.readabilityHandler = { _ = $0.availableData }

        try process.run()
        let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
        DispatchQueue.global().asyncAfter(deadline: .now() + 45, execute: deadline)
        let reader = FileHandleLineReader(fileHandle: stdout.fileHandleForReading)
        let writer = stdin.fileHandleForWriting
        var nextId = 1

        func sendRequest(method: String, params: Any) throws -> Data {
            let id = nextId
            nextId += 1
            try writeJSONLine(["id": id, "method": method, "params": params], to: writer)
            return try readResult(expectedId: id, reader: reader, process: process, stderrText: "限额服务返回未知错误")
        }

        func sendNotification(method: String, params: Any) throws {
            try writeJSONLine(["method": method, "params": params], to: writer)
        }

        defer {
            deadline.cancel()
            stderr.fileHandleForReading.readabilityHandler = nil
            try? writer.close()
            if process.isRunning {
                process.terminate()
            }
        }

        _ = try sendRequest(method: "initialize", params: [
            "clientInfo": ["name": "限额栏", "version": "0.1.0"],
            "capabilities": ["experimentalApi": true],
        ])
        try sendNotification(method: "initialized", params: NSNull())

        return try body(sendRequest)
    }

    private func readResult(expectedId: Int, reader: FileHandleLineReader, process: Process, stderrText: String) throws -> Data {
        while process.isRunning {
            let line = try reader.readLine()
            guard let data = line.data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                continue
            }
            guard let id = JSONRPCResultEnvelope.responseId(from: object["id"]) else {
                continue
            }
            guard id == expectedId else {
                continue
            }
            if let error = object["error"] as? [String: Any] {
                let message = error["message"] as? String ?? stderrText
                throw CodexAppServerClientError.serverError(message)
            }
            guard let result = object["result"] else {
                throw CodexAppServerClientError.missingJSONRPCResult
            }
            return try JSONSerialization.data(withJSONObject: result)
        }
        throw CodexAppServerClientError.appServerExited
    }

    private func writeJSONLine(_ object: [String: Any], to handle: FileHandle) throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        var line = data
        line.append(0x0A)
        try handle.write(contentsOf: line)
    }
}

final class FileHandleLineReader {
    private let fileHandle: FileHandle
    private var buffer = Data()

    init(fileHandle: FileHandle) {
        self.fileHandle = fileHandle
    }

    func readLine() throws -> String {
        while true {
            if let newline = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer[..<newline]
                buffer.removeSubrange(...newline)
                return String(data: lineData, encoding: .utf8) ?? ""
            }

            let chunk = fileHandle.readData(ofLength: 1)
            if chunk.isEmpty {
                throw CodexAppServerClientError.unexpectedEOF
            }
            buffer.append(chunk)
        }
    }
}
