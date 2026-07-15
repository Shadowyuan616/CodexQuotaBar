import Foundation

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

        var stderrText = ""
        stderr.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                stderrText += text
            }
        }

        try process.run()
        let reader = FileHandleLineReader(fileHandle: stdout.fileHandleForReading)
        let writer = stdin.fileHandleForWriting
        var nextId = 1

        func sendRequest(method: String, params: Any) throws -> Data {
            let id = nextId
            nextId += 1
            try writeJSONLine(["id": id, "method": method, "params": params], to: writer)
            return try readResult(expectedId: id, reader: reader, process: process, stderrText: stderrText)
        }

        func sendNotification(method: String, params: Any) throws {
            try writeJSONLine(["method": method, "params": params], to: writer)
        }

        defer {
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

        let rateLimitData = try sendRequest(method: "account/rateLimits/read", params: NSNull())
        let rateLimits = try decoder.decode(AccountRateLimitsResponse.self, from: rateLimitData)
        return QuotaSnapshot(rateLimits: rateLimits, fetchedAt: Date())
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
