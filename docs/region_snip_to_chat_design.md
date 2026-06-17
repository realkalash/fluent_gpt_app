# Region Snip → Chat (macOS) — Design

A "snip-to-chat" feature: **Cmd+Option+drag** anywhere on screen draws a selection
rectangle; on release, a compact chat opens near the cursor pre-loaded with the
selected region as a screenshot plus the focused app + window title.

## Locked decisions
- **Activation:** `Cmd+Option+drag` via a global **active `CGEventTap`** (Cmd+Option chosen to
  avoid conflicts with the very common Cmd+drag). Tap *consumes* the gesture so the app
  underneath never reacts. Fallback if we want to skip the Accessibility prompt: a passive
  `NSEvent.addGlobalMonitorForEvents` (cannot suppress underlying app).
- **Capture API:** Legacy `CGWindowListCreateImage` (synchronous, works on current macOS,
  matches existing `captureActiveScreen`). Abstracted behind one function so a future swap to
  ScreenCaptureKit is a single-spot change.
- **Chat surface:** Reuse the single main window via a new overlay mode (mirrors the existing
  Search/Sidebar/Overlay modes), repositioned near the selection. No multi-window.

## Permissions (MVP)
- **Screen Recording** — required for capture *and* for `kCGWindowName` window titles.
- **Accessibility** — required for the active `CGEventTap`.
- Sandbox is already OFF (`app-sandbox = false` in both entitlements), so no entitlement work.
- Extend the existing macOS-only Permissions settings page to show both statuses + a deep link
  to System Settings → Privacy & Security.

## The critical sequence (avoid stealing focus before metadata grab)
At trigger time the *target* app is still frontmost (a tap doesn't change focus), so:
```
Cmd+Option+leftMouseDown (seen by tap)
  1. record start point (global)
  2. grab metadata NOW:
       NSWorkspace.shared.frontmostApplication -> localizedName, bundleIdentifier, pid
       window title via CGWindowList for that pid (layer 0, frontmost). Fallback: AX title
         only if Accessibility already granted.
  3. show passive overlay window(s) (ignoresMouseEvents = true), crosshair cursor
leftMouseDragged (seen by tap)  -> update end point, redraw selection rect in overlay
leftMouseUp (seen by tap)
  4. compute rect; if too small -> cancel
  5. capture region BELOW the overlay (excludes the dim tint):
       CGWindowListCreateImage(rectPx, .optionOnScreenBelowWindow, overlayWindowID, .boundsIgnoreFraming)
  6. order out overlay, send result to Flutter
Escape at any point -> cancel + tear down overlay
```
While "snipping" is active the tap returns `nil` for down/drag/up (consumes them); otherwise it
returns the event untouched so normal mouse behavior is preserved.

## Capturing without the dim tint
The overlay draws a dimmed full-screen layer with a clear selection rect (like the old PyQt
script). Capturing with `.optionOnScreenBelowWindow` relative to the overlay's window number
grabs only what's beneath it — no flash, no `orderOut` race, dim tint excluded automatically.

## Coordinate math (the main footgun)
- `NSEvent.mouseLocation` / `NSScreen` = bottom-left origin, **points**.
- `CGWindowListCreateImage` rect = top-left origin, and capture output is **pixels**.
- Convert: flip Y against the containing screen, then multiply the rect by that screen's
  `backingScaleFactor` for the capture rect. Centralize in one helper (existing code already
  does ad-hoc Y-flips like `resHeight - positionY`).
- Retina output is 2x — pass through the existing image shrinker (`AppCache.imageShrinker*`)
  before sending to the model.

## Multi-monitor
- Overlay must cover the **union** of `NSScreen.screens` frames (one spanning borderless window,
  or one passive overlay per screen).
- Capture rect maps to the display under the selection (current `captureActiveScreen` only
  handles a single display — region capture must pick the right one).

## Native API surface (AppDelegate.swift / new RegionCapture.swift)
New method channel methods on `com.realk.fluent_gpt`:
- `startRegionCaptureService` — install the CGEventTap (called once after permissions granted).
- `stopRegionCaptureService` — remove the tap.
- `isAccessibilityGranted` / `isScreenRecordingGranted` — for the Permissions page.

Result pushed Flutter-ward when a capture completes:
```
methodChannel.invokeMethod("onRegionCaptured", [
  "imageBase64": <png base64>,
  "focusedApp":  "Safari",
  "bundleId":    "com.apple.Safari",
  "windowTitle": "GitHub - ...",
  "rectX","rectY","rectW","rectH": <global points>,
  "cursorX","cursorY": <global points>,
])
```

## Flutter changes
- `OverlayStatus` (`lib/overlay/overlay_manager.dart`): add `isShowingRegionChatOverlay`
  + update `isEnabled`, `==`, `hashCode`, and add a `regionChatEnabled` const.
- `OverlayManager.showRegionChatOverlay(x, y)`: resize to a compact size, reposition near the
  selection (reuse the Y-flip/clamp logic from `showOverlay`), `overlayVisibility.add(...)`.
- `main.dart` `setupMethodChannel`: handle `onRegionCaptured` — reposition window, flip overlay
  mode, attach screenshot + metadata.
- `main.dart` `_GlobalPageState.build` StreamBuilder: add a 4th branch ->
  `const RegionChatOverlayUI()`.
- New `lib/overlay/region_chat_overlay_ui.dart` (mirror `SearchOverlayUI`) — compact chat with
  the screenshot attached and a context line like `Focused: Safari — "GitHub …"`.
- Attach via existing `addAttachmentToInput([Attachment.fromInternalScreenshot(imageBase64)])`.
- Register/unregister the native service on app start + when the user toggles the feature.

## Cancel / edge cases
- Escape, zero/tiny drag, or click-without-drag → cancel and tear down overlay.
- Crosshair cursor while snipping.
- Never capture our own overlay (handled by `.optionOnScreenBelowWindow`).
- Chat window placement: prefer below-right of the selection; clamp to the visible frame
  (place above if the selection is near the screen bottom).

## Phasing
- **Phase 0 (native, isolated):** `CGEventTap` + passive overlay + drag rect + capture-below +
  metadata grab → return base64 + metadata. Test from the existing `DebugPage` button.
- **Phase 1 (Flutter handoff):** `onRegionCaptured` → reposition + new overlay mode + compact
  chat + attach.
- **Phase 2 (activation polish):** wire the service on/off, settings toggle, consume-vs-passive.
- **Phase 3 (UX):** Permissions page (both statuses + deep link), multi-monitor, image shrink,
  cancel polish.

## Future: AI Lens (Tier 2) & shader extensibility
The overlay window / event-tap / capture-below layer is **rendering-agnostic** — the content
view is a pluggable renderer. This keeps a richer "AI Lens" experience fully open:

- **Two tiers, one foundation.**
  - *Tier 1 — Fast snip* (`Cmd+Option+drag`): native overlay, simple rect, capture, Flutter chat.
  - *Tier 2 — AI Lens* (`Cmd+Shift+6`, future): reuses the activation layer, overlay infra,
    capture-below, metadata grab, and Flutter handoff. Adds only a richer renderer + detection.
- **Renderer is swappable** with no change to the surrounding architecture:
  - Now: `NSView.draw(_:)` (Core Graphics) — the red rect.
  - Later: `MTKView` (custom Metal `.metal` shaders — scan shimmer, sweep, glow, particles),
    `CALayer` + Core Image filters (blur/glow/color), or SwiftUI `.layerEffect`/`.colorEffect`
    (macOS 14+).
- **Detection:** run macOS **Vision** on the captured frame (OCR `VNRecognizeTextRequest`,
  rectangle/object/saliency) → draw highlight chips natively, and/or feed the interactive lens
  panel in Flutter.
- **Split mirrors Tier 1:** native does real-time over-live-content visuals; Flutter does the
  interactive panel afterward.
- **Effect cost classes:**
  - *Composited on top* (shimmer, glow, dim, chips, gradients) — cheap, no need to sample behind
    the overlay. Covers most of the "Lens" look.
  - *Distorting the real pixels behind the overlay* — needs continuous capture
    (`SCStream` -> Metal view -> shader). Heavier tier; only if a specific effect requires it.
- **Phase 0 hook:** put rect drawing behind a minimal `SelectionRenderer` seam
  (`update(start:end:)` + draw) so a future `MetalLensOverlayView` is a drop-in swap.

## Open risks
- Active CGEventTap requires Accessibility; if denied, the gesture silently no-ops — needs a
  clear in-app prompt. (Passive `NSEvent` monitor is the lighter fallback.)
- `kCGWindowName` is often empty for some apps even with Screen Recording; AX title is the
  fallback but pulls in the Accessibility dependency we already need anyway.
- macOS may briefly show the "app is recording your screen" indicator on each capture.
