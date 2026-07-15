import Foundation

@main
struct CodexQuotaLiveProbe {
    static func main() {
        do {
            let snapshot = try CodexAppServerClient().fetchSnapshot()
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
