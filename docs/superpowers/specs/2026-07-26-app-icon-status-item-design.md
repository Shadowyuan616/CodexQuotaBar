# App Icon and Compact Status Item Design

## Scope

This change introduces a branded application icon and removes unnecessary
horizontal transparency from the menu bar status item. It does not alter quota
selection, refresh behavior, reset-time formatting, status colors, panel
positioning, or popover content.

## App Icon

### Visual Direction

The selected concept is **Intelligent Orbit**:

- three intersecting elliptical paths around a central status point;
- a graphite rounded-square background;
- emerald-green orbit strokes;
- a brighter central point with a restrained glow;
- no text, letters, or direct reproduction of the Codex or ChatGPT marks.

The paths communicate interconnected computation while the center point ties
the mark to the app's monitoring role. The geometry must remain recognizable at
16 and 32 pixels, so the final design uses uniform strokes, generous internal
spacing, and no fine decorative detail.

### Asset Production

The icon will be generated deterministically with AppKit vector paths rather
than an AI-generated raster image. The repository will contain:

- a reproducible icon-generation script;
- the generated `Resources/AppIcon.icns` bundle resource;
- a 1024-pixel PNG master for documentation and review.

The icon set will include standard macOS 1x and 2x sizes from 16 through 512
points. `Resources/Info.plist` will declare the icon, and `scripts/build.sh`
will copy it into the app bundle.

## Menu Bar Status Item

### Current Geometry

The status image and `NSStatusItem` are 48 points wide. The visible rounded
rectangle is inset by one point on each horizontal side, producing an
approximately 46-point-wide capsule plus two transparent pixels.

### Target Geometry

The visible capsule remains approximately 46 by 20 points. The image canvas and
`NSStatusItem` become 46 points wide, and the rounded rectangle no longer uses a
horizontal inset. Vertical geometry remains unchanged:

- status image height: 24 points;
- visible capsule height: 20 points;
- quota number, health light, and reset time retain their existing sizes;
- content is centered in the 46-point canvas without clipping.

This is the smallest safe reduction that preserves the visible capsule and its
click target. Further reduction would crop the capsule or change its requested
size.

## Code Changes

- Add icon assets and a deterministic generation script under `Resources/`
  and `scripts/`.
- Add `CFBundleIconFile` to `Resources/Info.plist`.
- Copy `AppIcon.icns` in `scripts/build.sh`.
- Change the shared menu bar width token from 48 to 46 points.
- Draw the capsule across the full horizontal canvas while retaining the
  existing one-point vertical and stroke-safe geometry.
- Recenter the quota number, status light, and reset time from measured text
  widths.

## Validation

Automated checks will verify:

- the status item and image are 46 points wide;
- the visible capsule width remains the previous 46 points;
- all menu bar content frames remain inside the image bounds;
- existing five-hour and weekly-only states still render correctly;
- the built app contains `Contents/Resources/AppIcon.icns`;
- `Info.plist` resolves the icon resource;
- the generated icon contains the required macOS sizes.

Visual review will cover the 16, 32, 128, 512, and 1024-pixel icon renders and
the menu bar badge at its native 46 by 24-point size.
