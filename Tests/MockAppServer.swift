import Foundation

@main
struct MockAppServer {
    static func main() throws {
        while let line = readLine() {
            guard let request = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let id = request["id"] else { continue }
            let method = request["method"] as? String
            var result: [String: Any] = [:]
            switch method {
            case "initialize": break
            case "account/rateLimits/read":
                result = ["accountId": "fixture-account", "rateLimits": ["limitId": "codex", "primary": ["usedPercent": 95, "windowDurationMins": 10080, "resetsAt": 2_000_000_000]], "rateLimitResetCredits": ["availableCount": 2]]
            case "account/usage/read":
                result = ["summary": ["lifetimeTokens": 1234567]]
            case "account/rateLimitResetCredit/consume":
                let params = request["params"] as? [String: Any]
                guard params?["idempotencyKey"] as? String == "fixture-key",
                      params?["creditId"] as? String == "fixture-credit" else { exit(2) }
                result = ["outcome": "alreadyRedeemed"]
            default: exit(3)
            }
            let data = try JSONSerialization.data(withJSONObject: ["id": id, "result": result])
            FileHandle.standardOutput.write(data + Data([10]))
        }
    }
}
