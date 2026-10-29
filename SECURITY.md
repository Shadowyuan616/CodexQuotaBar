# Security and Privacy

CodexQuotaBar reads quota data from the locally installed ChatGPT or legacy
Codex application. It launches the bundled `codex app-server --stdio` process
and requests `account/rateLimits/read` plus throttled `account/usage/read` samples.
`account/rateLimitResetCredit/consume` is sent only after an explicit two-click
inline confirmation. Preview and automated tests never consume real cards.

## Authentication boundary

- The app does not read `~/.codex/auth.json`, browser cookies, Keychain items,
  access tokens, refresh tokens, or API keys.
- Authentication is handled by the official local Codex app-server process.
- The app does not request `account/read`. Token totals come from `account/usage/read`.
- The child process receives an allowlisted environment containing only basic
  process settings, Codex data locations, proxy settings, and TLS certificate
  locations. Unrelated API keys and cloud credentials are not inherited.

## Local data

The app stores the latest quota response and reset-card details, fetch times,
daily quota history, a cumulative Token baseline, and daily Token/quota increments.
Trend account/plan scopes are SHA-256 hashes. Pending redemptions persist an
idempotency key, optional card ID, and hashed account scope before sending. They
are retained on uncertain errors and reused after restart; a fresh account check
must match before redemption. Raw account IDs are excluded from quota caches.
The app does not persist email, credentials, conversations, or raw service errors.

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
