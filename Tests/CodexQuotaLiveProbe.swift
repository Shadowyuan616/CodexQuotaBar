import Foundation

@main
struct CodexQuotaLiveProbe {
    static func main() {
        do {
            let snapshot = try CodexAppServerClient().fetchSnapshot()
            if CommandLine.arguments.contains("--features") {
                print("reset count available: \(snapshot.rateLimits?.rateLimitResetCredits != nil)")
                print("reset detail rows: \(snapshot.rateLimits?.rateLimitResetCredits?.credits?.count ?? 0)")
                let sample = try CodexAppServerClient().fetchTrendSample()
                print("paired token/quota sample valid: \(sample.totalTokens >= 0 && !sample.accountScope.isEmpty)")
                return
            }
            let viewModel = QuotaViewModel(snapshot: snapshot)
            print(viewModel.statusTitle)
            for line in viewModel.detailLines {
                print(line)
            }
        } catch {
            fputs("CodexQuotaLiveProbe failed: \(error)\n", stderr)
            exit(1)
        }
    }
}
