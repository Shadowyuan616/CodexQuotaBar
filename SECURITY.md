# Security and Privacy

CodexQuotaBar reads quota data from the locally installed ChatGPT or legacy
Codex application. It launches the bundled `codex app-server --stdio` process
and requests only `account/rateLimits/read`.

## Authentication boundary

- The app does not read `~/.codex/auth.json`, browser cookies, Keychain items,
  access tokens, refresh tokens, or API keys.
- Authentication is handled by the official local Codex app-server process.
- The app does not request `account/read` or `account/usage/read`.
- The child process receives an allowlisted environment containing only basic
  process settings, Codex data locations, proxy settings, and TLS certificate
  locations. Unrelated API keys and cloud credentials are not inherited.

## Local data

The app stores only the latest quota response, its fetch time, and daily quota
percentages used for local history. It does not persist account email, token
usage, credentials, or raw service errors.

Data is stored under `~/Library/Application Support/CodexQuotaBar` with `0700`
directory permissions and `0600` file permissions. Diagnostic text contains
only sanitized status categories.

## Distribution

Local development builds are ad-hoc signed. Public releases should be built
with `scripts/release-build.sh`, a Developer ID Application identity, Hardened
Runtime, timestamping, and optional Apple notarization.

App Sandbox is intentionally not enabled because the utility must launch the
official local Codex app-server. Hardened Runtime and the narrow executable and
environment allowlists provide the release boundary for this architecture.

Please report security issues privately to the repository owner before opening
a public issue.
