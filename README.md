# CodexQuotaBar

[![CI](https://github.com/Shadowyuan616/CodexQuotaBar/actions/workflows/ci.yml/badge.svg)](https://github.com/Shadowyuan616/CodexQuotaBar/actions/workflows/ci.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black)](https://www.apple.com/macos/)
[![Apple Silicon](https://img.shields.io/badge/architecture-Apple%20Silicon-black)](#requirements)
[![MIT License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**English** | [简体中文](docs/README.zh-CN.md)

CodexQuotaBar is a lightweight macOS menu bar utility that displays your Codex
quota, reset time, and refresh health through the official local ChatGPT/Codex
app-server.

> This is an independent community project. It is not affiliated with or
> endorsed by OpenAI. Codex, ChatGPT, and related names are trademarks of their
> respective owners.

![CodexQuotaBar preview](docs/images/preview.png)

Preview uses demo data. The app's interface labels are currently in Chinese.

## Features

- Compact menu bar status with remaining quota, reset time, and an API health indicator.
- Supports both 5-hour plus weekly limits and accounts with a weekly limit only.
- Automatically switches the menu bar value and reset label when no 5-hour limit is returned.
- Fixed auto-refresh choices: 10 seconds, 30 seconds, 1 minute, 5 minutes, and 15 minutes.
- Keeps the last quota value visible while refreshing; only the health indicator turns blue.
- Expiry-sorted reset-card list with inline confirmation and cancellation; only the earliest-expiring card can be used.
- Daily estimated weekly Token-capacity trend, displayed in the same 250pt-wide panel.
- Native Liquid Glass on macOS 26 and later.
- `NSVisualEffectView` compatibility fallback on macOS 14-25.
- Local cache for the latest successful quota response, with sanitized error states.
- Readable in both light and dark appearance.

## Requirements

### Running the app

| Requirement | Supported configuration |
| --- | --- |
| macOS | macOS 14.0 or later |
| Processor | Apple Silicon (`arm64`) |
| ChatGPT | `/Applications/ChatGPT.app`, signed in to a Codex-enabled account |
| Legacy fallback | `/Applications/Codex.app` is still recognized |

macOS 14-25 uses the compatibility visual effect. macOS 26 and later uses
native Liquid Glass. macOS 13 and earlier are not supported.

### Building from source

- Xcode 26 or later, or Command Line Tools containing the macOS 26+ SDK.
- Git.

The source needs a recent SDK to compile the Liquid Glass types. The generated
application still has a minimum runtime target of macOS 14.0.

## Installation

### Current option: build from source

This repository does not currently distribute an unsigned binary. This avoids
asking users to bypass Gatekeeper warnings.

```bash
git clone https://github.com/Shadowyuan616/CodexQuotaBar.git
cd CodexQuotaBar
bash scripts/test.sh
bash scripts/build.sh
open dist/CodexQuotaBar.app
```

The app is written to `dist/CodexQuotaBar.app`. To install the local build in
Applications:

```bash
ditto dist/CodexQuotaBar.app /Applications/CodexQuotaBar.app
open /Applications/CodexQuotaBar.app
```

Set `OUTPUT_DIR` to choose another build destination:

```bash
OUTPUT_DIR="$HOME/Desktop/CodexQuotaBar-build" bash scripts/build.sh
```

## Usage

1. Install and sign in to the official ChatGPT app for macOS.
2. Launch `CodexQuotaBar.app`.
3. Click the quota capsule in the menu bar to open the panel.
4. Use the refresh icon to query immediately, the gear icon to select an
   automatic refresh interval, and the close icon to quit.

The menu bar number displays the 5-hour remaining quota when that limit exists.
If the account has no 5-hour limit, it displays the weekly remaining quota.

The health indicator is green when online, blue while refreshing, red on an
error, and gray when unavailable. Quota colors are based on the amount
remaining: green for 20%-100%, yellow for 5%-20%, and red for 0%-5%.

## Reset cards and Token trend

The 250pt popover also shows earned reset cards and their expiry dates when
provided, in a list sorted by expiry. Each row shows its expiry date and time;
only the earliest-expiring available card enables **使用** (Use).

1. Click **使用** to arm confirmation. No card is redeemed on this first click.
2. Click the red **确认使用？** (Confirm use?) within eight seconds to redeem it.
3. To back out, click **取消** (Cancel) to its left. Closing the panel, a refresh,
   or letting the eight-second window expire also cancels confirmation.

![Inline reset confirmation and cancel button, using demo data](docs/images/reset-confirmation.png)

More than three rows scroll within the list. Incomplete
card details disable redemption until the earliest card can be determined.
The server decides whether your quota is eligible.
An uncertain result can be retried with the same persisted request ID without
consuming a second card; retries are bound to the original account.

The daily **周额度折算** chart estimates full weekly Token capacity as
`observed Token increase / (weekly used-percentage-point increase / 100)`.
For example, 100,000 Tokens using 2% gives an estimated 5 million Tokens/week.
It shows the last 14 days using daily weighted totals, not averages of ratios.
Sampling occurs after successful refreshes, at most once every five minutes.
Only paired observations within the same day and quota window are included.
Resets, account/plan switches, and counter rollbacks break the baseline.
The chart starts empty until a measurable change is observed; old percentage-only
history cannot be backfilled. Account-wide Token activity and quota billing may
have different scopes, so this is an observation-based estimate, not an official
fixed allowance. Hover the chart for daily values.

If the usage endpoint is unavailable, existing trend points remain visible and
quota refreshes continue independently. The underlying methods are documented in
the [official OpenAI App Server documentation](https://learn.chatgpt.com/docs/app-server).

## Privacy and security

CodexQuotaBar does not directly read `~/.codex/auth.json`, Keychain items,
browser cookies, access tokens, refresh tokens, or API keys. Authentication is
delegated to the official local `codex app-server` process.

The app uses these local app-server methods:

```text
account/rateLimits/read
account/usage/read
account/rateLimitResetCredit/consume  # only after two-click confirmation
```

It does not request `account/read`. Local data includes quota snapshots, reset-card
details, one cumulative Token baseline, daily Token/quota increments, and a hashed
account/plan scope. Pending reset attempts store an idempotency key, selected card
ID, and hashed account scope. Raw account IDs, email, credentials, and raw service
errors are not stored. See
[SECURITY.md](SECURITY.md) for the complete security boundary.

## Development

```bash
# Core and UI tests
bash scripts/test.sh

# Render a panel preview
bash scripts/render-preview.sh

# Build a local app bundle
bash scripts/build.sh
```

The project intentionally uses a small shell-based Swift/AppKit build rather
than requiring an Xcode project.

## Known limitations

- The app relies on the local ChatGPT/Codex app-server protocol. Upstream
  protocol changes may require updates.
- Current builds target Apple Silicon only; Intel Macs are not supported.
- Launch at Login is not built in yet. Add the app manually in macOS Login Items
  if needed.

## Contributing

Issues and pull requests are welcome. Please include the macOS version, ChatGPT
app version, and a sanitized error summary when reporting a quota refresh issue.
Never attach credentials, tokens, `auth.json`, or raw private logs.

## License

[MIT](LICENSE)
