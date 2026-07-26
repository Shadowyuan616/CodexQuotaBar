# App Icon and Compact Status Item Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the approved Intelligent Orbit app icon and reduce the status item from 48 to 46 points without shrinking its visible capsule.

**Architecture:** A standalone AppKit script deterministically renders all macOS icon sizes and assembles `AppIcon.icns`. The existing menu bar renderer keeps its 24-point height and content measurements, while the canvas and status item share a new 46-point width and the capsule drops its horizontal drawing inset.

**Tech Stack:** Swift 6, AppKit, Core Graphics, `iconutil`, Bash, existing command-line Swift test harness.

## Global Constraints

- Keep quota selection, refresh behavior, reset-time formatting, status colors, panel positioning, and popover content unchanged.
- Use the approved Intelligent Orbit mark: three intersecting ellipses, central status point, graphite background, emerald strokes, no text.
- Keep the visible menu bar capsule approximately 46 by 20 points.
- Keep the status image height at 24 points.
- Preserve macOS 14 runtime compatibility.
- Add no third-party dependencies.

---

### Task 1: Lock the Compact Status Geometry with Tests

**Files:**
- Modify: `Tests/CodexQuotaUITests.swift`

**Interfaces:**
- Consumes: `DesignTokens.statusBadgeWidth`, `DesignTokens.statusBadgeCapsuleWidth`, `MenuBarStatusView.layout(for:)`
- Produces: assertions defining a 46-point image/status item and in-bounds content frames

- [ ] **Step 1: Change the width assertions to the approved target**

Add assertions equivalent to:

```swift
uiExpect(DesignTokens.statusBadgeWidth == 46, "menu bar status item should remove the old two-point transparent margin")
uiExpect(DesignTokens.statusBadgeCapsuleWidth == 46, "visible capsule width should remain 46 points")
uiExpect(menuBarLayout.capsuleFrame.width == 46, "capsule frame should preserve its visible width")
```

- [ ] **Step 2: Add content-bound assertions**

```swift
let statusImageBounds = NSRect(origin: .zero, size: menuBarBadge.size)
uiExpect(statusImageBounds.contains(menuBarLayout.percentTextFrame), "quota number must remain inside the compact status image")
uiExpect(statusImageBounds.contains(menuBarLayout.monitorDotFrame), "monitor light must remain inside the compact status image")
uiExpect(statusImageBounds.contains(menuBarLayout.resetTextFrame), "reset time must remain inside the compact status image")
```

- [ ] **Step 3: Run the UI tests and confirm the new contract fails**

Run: `bash scripts/test.sh`

Expected: `CodexQuotaUITests` fails because the current width is 48 points.

- [ ] **Step 4: Commit the failing test contract**

```bash
git add Tests/CodexQuotaUITests.swift
git commit -m "test: require compact menu bar status item"
```

### Task 2: Implement the 46-Point Status Item

**Files:**
- Modify: `Sources/CodexQuotaBarApp.swift`
- Test: `Tests/CodexQuotaUITests.swift`

**Interfaces:**
- Consumes: the geometry contract from Task 1
- Produces: `DesignTokens.statusBadgeWidth == 46`, a 46-point capsule frame, unchanged 24-point height

- [ ] **Step 1: Update the shared geometry tokens**

```swift
static let statusBadgeWidth: CGFloat = 46
static let statusBadgeCapsuleWidth: CGFloat = 46
```

- [ ] **Step 2: Remove only the horizontal drawing inset**

Replace the capsule path rectangle with:

```swift
let capsuleDrawingRect = layout.capsuleFrame.insetBy(dx: 0, dy: 2)
let capsulePath = NSBezierPath(
    roundedRect: capsuleDrawingRect,
    xRadius: layout.capsuleCornerRadius,
    yRadius: layout.capsuleCornerRadius
)
```

Keep the text fonts, dot size, vertical coordinates, reset-time formatting,
fill opacity, corner radius, and colors unchanged.

- [ ] **Step 3: Run the test suite**

Run: `bash scripts/test.sh`

Expected: `CodexQuotaCoreTests passed` and `CodexQuotaUITests passed`.

- [ ] **Step 4: Commit the implementation**

```bash
git add Sources/CodexQuotaBarApp.swift
git commit -m "fix: remove status item horizontal padding"
```

### Task 3: Add the Deterministic Intelligent Orbit Icon Generator

**Files:**
- Create: `scripts/generate-app-icon.swift`
- Create: `scripts/generate-app-icon.sh`
- Generate: `Resources/AppIcon.iconset/*`
- Generate: `Resources/AppIcon.icns`
- Generate: `docs/images/app-icon-1024.png`

**Interfaces:**
- Produces: `renderIcon(pixelSize: CGFloat) -> NSImage`
- Produces: a valid iconset and `Resources/AppIcon.icns`

- [ ] **Step 1: Add the AppKit renderer**

The Swift script must:

```swift
import AppKit

func renderIcon(pixelSize: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    image.lockFocus()
    defer { image.unlockFocus() }

    // Rounded graphite background.
    let outer = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    let radius = pixelSize * 0.22
    NSBezierPath(roundedRect: outer.insetBy(dx: pixelSize * 0.035, dy: pixelSize * 0.035),
                 xRadius: radius, yRadius: radius).fill()

    // Three equal elliptical paths rotated by 0, +60, and -60 degrees.
    // Use an emerald stroke about 8.5% of pixelSize with round caps.
    // Add a small bright center point and a restrained radial glow.
    return image
}
```

The final implementation must use `NSGraphicsContext.saveGraphicsState()`,
rotate around the icon center for each orbit, and export PNG representations
with `NSBitmapImageRep`.

- [ ] **Step 2: Add the shell wrapper**

`scripts/generate-app-icon.sh` must create the standard files:

```text
icon_16x16.png
icon_16x16@2x.png
icon_32x32.png
icon_32x32@2x.png
icon_128x128.png
icon_128x128@2x.png
icon_256x256.png
icon_256x256@2x.png
icon_512x512.png
icon_512x512@2x.png
```

Then run:

```bash
iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
```

Copy the 1024-pixel render to `docs/images/app-icon-1024.png`.

- [ ] **Step 3: Run the generator**

Run: `bash scripts/generate-app-icon.sh`

Expected: `Resources/AppIcon.icns` and all ten iconset PNG files exist.

- [ ] **Step 4: Validate the generated assets**

Run:

```bash
iconutil -c iconset Resources/AppIcon.icns -o /tmp/CodexQuotaBar-AppIcon.iconset
sips -g pixelWidth -g pixelHeight docs/images/app-icon-1024.png
```

Expected: iconutil succeeds and the documentation master reports 1024 by 1024 pixels.

- [ ] **Step 5: Commit the generator and assets**

```bash
git add scripts/generate-app-icon.swift scripts/generate-app-icon.sh Resources/AppIcon.iconset Resources/AppIcon.icns docs/images/app-icon-1024.png
git commit -m "feat: add intelligent orbit app icon"
```

### Task 4: Integrate the Icon into the App Bundle

**Files:**
- Modify: `Resources/Info.plist`
- Modify: `scripts/build.sh`
- Modify: `Tests/CodexQuotaUITests.swift`

**Interfaces:**
- Consumes: `Resources/AppIcon.icns`
- Produces: `CFBundleIconFile = AppIcon` and `Contents/Resources/AppIcon.icns`

- [ ] **Step 1: Add bundle assertions**

Extend the UI test harness with static source checks or add post-build shell
validation that requires:

```text
CFBundleIconFile -> AppIcon
Contents/Resources/AppIcon.icns exists
```

- [ ] **Step 2: Declare the icon in Info.plist**

```xml
<key>CFBundleIconFile</key>
<string>AppIcon</string>
```

- [ ] **Step 3: Copy the icon during builds**

After copying `Info.plist`, add:

```bash
cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
```

- [ ] **Step 4: Build and validate**

Run:

```bash
bash scripts/build.sh
test -f dist/CodexQuotaBar.app/Contents/Resources/AppIcon.icns
/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" dist/CodexQuotaBar.app/Contents/Info.plist
codesign --verify --deep --strict dist/CodexQuotaBar.app
```

Expected: the icon exists, PlistBuddy prints `AppIcon`, and codesign verification succeeds.

- [ ] **Step 5: Commit bundle integration**

```bash
git add Resources/Info.plist scripts/build.sh Tests/CodexQuotaUITests.swift
git commit -m "build: bundle the application icon"
```

### Task 5: Final Visual and Regression Verification

**Files:**
- Modify only if verification finds a defect

**Interfaces:**
- Consumes: all previous tasks
- Produces: verified icon assets and menu bar geometry

- [ ] **Step 1: Run all tests**

Run: `bash scripts/test.sh`

Expected: both test executables pass.

- [ ] **Step 2: Render the panel preview**

Run: `bash scripts/render-preview.sh`

Expected: `dist/codex-quota-popover-preview.png` renders without layout regressions.

- [ ] **Step 3: Inspect icon sizes**

Open or render a contact sheet containing the 16, 32, 128, 512, and 1024-pixel
assets. Verify the orbits remain separated and the center point remains visible.

- [ ] **Step 4: Inspect native status badge output**

Render the 46 by 24-point `MenuBarStatusView.image` at 2x and verify:

- no horizontal clipping;
- unchanged capsule height and corner radius;
- readable quota number and reset time;
- visible breathing status light.

- [ ] **Step 5: Check repository state**

Run:

```bash
git diff --check
git status --short
```

Expected: no whitespace errors and no accidental build artifacts.
