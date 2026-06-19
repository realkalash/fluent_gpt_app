import Carbon.HIToolbox
import Cocoa
import FlutterMacOS
import Foundation
import AVFoundation
import Quartz
import Vision
// This is required for calling FlutterLocalNotificationsPlugin.setPluginRegistrantCallback method.
// import flutter_local_notifications

@main
class AppDelegate: FlutterAppDelegate {
  var overlayWindow: NSWindow?
  var methodChannel: FlutterMethodChannel?
  var regionCaptureManager: RegionCaptureManager?
  // let customTimer = CustomTimer()

  override func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
    return false
  }
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
      if !flag {
          for window in NSApp.windows {
              if !window.isVisible {
                  window.setIsVisible(true)
              }
              window.makeKeyAndOrderFront(self)
              NSApp.activate(ignoringOtherApps: true)
          }
      }
      return true
  }
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationWillTerminate(_: Notification) {
    // customTimer.stopTimer()
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      fatalError("[Swift] Flutter view controller not found")
    }

    methodChannel = FlutterMethodChannel(name: "com.realk.fluent_gpt", binaryMessenger: controller.engine.binaryMessenger)

    regionCaptureManager = RegionCaptureManager(methodChannel: methodChannel)

    setupMethodCallHandler()
    
    // TODO: Uncomment when accessibility features are needed
    // First check if accessibility is already granted without showing prompt
    // if !checkAccessibilityPermissions() {
    //   print("[Swift] please allow accessibility API access to this app.")
    //   // Only show prompt if permissions are not granted
    //   requestAccessibilityPermissions()
    //   // open the accessibility settings in macos
    //   NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
    // }
    // setupEventMonitoring()

    // customTimer.startTimer(interval: 3.0) {
    // print("[Swift] Timer fired")
    // self.methodChannel?.invokeMethod("onTimerFired", arguments: nil)
    // }
    super.applicationDidFinishLaunching(notification)
  }

  func setupMethodCallHandler() {
    methodChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }

      switch call.method {
      case "testResultFromSwift":
        result(["Result from Swift": "Hello from Swift"])
      case "getSelectedText":
        // Return nil since accessibility features are disabled
        result(nil)
      case "showOverlay":
        self.handleShowOverlay(call: call, result: result)
      case "requestNativePermissions":
        // Accessibility features are disabled, return without requesting permissions
        print("[Swift] Accessibility features are disabled. Skipping permission request.")
        result(nil)
      case "requestMicrophonePermissions":
        print("[Swift] requestMicrophonePermissions called")
        self.requestMicrophonePermissions { granted in
        print("[Swift] Permission granted: \(granted)")
        result(granted)
      }
      case "isAccessabilityGranted":
        // Return false since accessibility features are disabled
        result(false)
      case "initAccessibility":
        print("[Swift] initAccessibility called - accessibility features disabled")
        // Return that accessibility is not available since features are disabled
        result(["isAccessible": false])
      case "getScreenSize":
        self.handleGetScreenSize(result: result)
      case "getMousePosition":
        let cursorPosition = getCurrentCursorPosition()
        result(["positionX": cursorPosition.x, "positionY": cursorPosition.y])
      case "startRegionCaptureService":
        // Installs the global Cmd+Option+drag event tap. Returns false if Accessibility
        // is not yet granted (and triggers the system prompt in that case).
        let started = self.regionCaptureManager?.startService() ?? false
        result(started)
      case "stopRegionCaptureService":
        self.regionCaptureManager?.stopService()
        result(nil)
      case "isRegionCaptureAccessibilityGranted":
        result(AXIsProcessTrusted())
      case "isScreenRecordingGranted":
        result(self.regionCaptureManager?.isScreenRecordingGranted() ?? false)
      case "requestScreenRecordingAccess":
        result(self.regionCaptureManager?.requestScreenRecordingAccess() ?? false)
      case "captureActiveScreen":
        if let image = self.captureActiveScreen(),
           let imageData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: imageData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
          let base64String = pngData.base64EncodedString(options: [])
          result(base64String)
        } else {
          result(FlutterError(code: "UNAVAILABLE", message: "Image conversion failed", details: nil))
        }
      case "captureDisplayUnderCursor":
        result(self.captureDisplayUnderCursor())
      case "recognizeText":
        guard let args = call.arguments as? [String: Any],
              let data = (args["imageBytes"] as? FlutterStandardTypedData)?.data else {
          result(FlutterError(code: "BAD_ARGS", message: "imageBytes (Uint8List) required", details: nil))
          return
        }
        let languages = args["languages"] as? [String]
        let fast = (args["fast"] as? Bool) ?? false
        self.recognizeText(imageData: data, languages: languages, fast: fast, result: result)
      case "enterLensMode":
        self.enterLensMode()
        result(true)
      case "exitLensMode":
        self.exitLensMode()
        result(nil)
      case "performHaptic":
        // Trackpad haptic (Force Touch). `pattern`: "generic" | "alignment" |
        // "levelChange"; no-op on hardware without a haptic trackpad.
        let pattern = (call.arguments as? [String: Any])?["pattern"] as? String ?? "generic"
        let feedback: NSHapticFeedbackManager.FeedbackPattern
        switch pattern {
        case "alignment":   feedback = .alignment
        case "levelChange": feedback = .levelChange
        default:            feedback = .generic
        }
        NSHapticFeedbackManager.defaultPerformer.perform(feedback, performanceTime: .now)
        result(nil)
      default:
        result("not implemented")
      }
    }
  }
  /// Request mic permission and return result(true) if granted
  func requestMicrophonePermissions(completion: @escaping (Bool) -> Void) {
    let mediaType = AVMediaType.audio
    AVCaptureDevice.requestAccess(for: mediaType) { granted in
        if granted {
            print("[Swift] Microphone permission granted")
        } else {
            print("[Swift] Microphone permission denied")
        }
        completion(granted)
    }
}
  

  func handleShowOverlay(call _: FlutterMethodCall, result: @escaping FlutterResult) {
    // Implementation of showOverlay
    print("[Swift] showOverlay called")
    result(nil)
  }

  /// Handles the initialization of accessibility features.
  /// Checks for accessibility permissions and sets up event monitoring if permissions are granted.
  /// - Parameter result: A closure that returns a dictionary indicating whether accessibility is enabled.
  func handleInitAccessibility(result: @escaping FlutterResult) {
    if checkAccessibilityPermissions() {
      setupEventMonitoring()
      result(["isAccessible": true])
    } else {
      informUserAboutPermissions()
      result(["isAccessible": false])
    }
  }

  func handleGetScreenSize(result: @escaping FlutterResult) {
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect.zero
    result(["width": screenFrame.width, "height": screenFrame.height])
  }

  func requestAccessibilityPermissions() {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    AXIsProcessTrustedWithOptions(options)
  }

  func setupEventMonitoring() {
    NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
      print("[Swift] leftMouseUp")
      self?.handleMouseUp(event: event)
    }
  }

  func checkAccessibilityPermissions() -> Bool {
    return AXIsProcessTrusted()
  }

  func informUserAboutPermissions() {
    print("[Swift] Accessibility permissions are restricted. Please enable them in System Preferences.")
  }

  func getSelectedTextFromReader() -> String? {
    let focusedElement = AXUIElement.focusedElement
    return focusedElement?.selectedText
  }

  // Function to get current mouse cursor position on screen
  func getCurrentCursorPosition() -> NSPoint {
    let mouseLocation = NSEvent.mouseLocation
    return mouseLocation
  }

  // I should find a better way to get the selected text
  // This method is causing too many unnecessary clipboard changes for each mouse click event
  func getSelectedTextOverrideClipboard(completion: @escaping (String?) -> Void) {
    // Get initial clipboard text
    let initialClipboardText = NSPasteboard.general.readObjects(forClasses: [NSString.self], options: nil)?.first as? String ?? ""

    // Perform the global copy shortcut
    performGlobalCopyShortcut()

    // Define the delay
    let delay = DispatchTime.now() + 0.05

    // Schedule the task with asyncAfter
    DispatchQueue.main.asyncAfter(deadline: delay) {
      // Get the clipboard text after the delay
      let clipboardText = NSPasteboard.general.readObjects(forClasses: [NSString.self], options: nil)?.first as? String ?? ""

      // Restore the original clipboard text if it is not empty or nil
      if !clipboardText.isEmpty {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(initialClipboardText, forType: .string)
      }

      // Call the completion handler with the selected text
      completion(clipboardText)
    }
  }

  func handleMouseUp(event: NSEvent) {
    let cursorPosition = event.locationInWindow
    let nameApp = AXUIElement.focusedElement?.applicationName
    print("[Swift] Cursor position: \(cursorPosition)")
    let focusedElement = AXUIElement.focusedElement
    let selectedText = focusedElement?.selectedText
    print("[Swift] Selected text: \(selectedText ?? "No text selected")")
    // if selectedText is not nil then send it to flutter
    if let selectedText = selectedText {
      methodChannel?.invokeMethod("onTextSelected", arguments: [
        "selectedText": selectedText,
        "positionX": cursorPosition.x,
        "positionY": cursorPosition.y,
        "focusedApp": nameApp ?? "",
      ])
    } else {
      // print("[Swift] No text finded via reader. Trying to get text from clipboard.")
      // getSelectedTextOverrideClipboard { selectedText in
      //   print("[Swift] Selected text from clipboard: \(selectedText ?? "No text selected")")
      //   // if selected text in clipboard is the same as previous

      //   // if selectedText is not nil then send it to flutter
      //   if let selectedText = selectedText {
      //     self.methodChannel?.invokeMethod("onTextSelected", arguments: [
      //       "selectedText": selectedText,
      //       "positionX": cursorPosition.x,
      //       "positionY": cursorPosition.y,
      //       "focusedApp": nameApp ?? "",
      //     ])
      //   }
      // }
    }

    // old code
    // methodChannel?.invokeMethod("onMouseUp", arguments: [
    //   "positionX": cursorPosition.x,
    //   "positionY": cursorPosition.y,
    // ])
  }

  func captureActiveScreen() -> NSImage? {
    // Get the active application
    guard let activeApp = NSWorkspace.shared.frontmostApplication else {
        return nil
    }

    // Get all on-screen windows
    guard let windowListInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as NSArray? as? [[String: Any]] else {
        return nil
    }

    // Find the active window of the active application
    let activeWindows = windowListInfo.filter { windowInfo in
        if let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
           let isOnscreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool,
           isOnscreen,
           ownerPID == activeApp.processIdentifier {
            return true
        }
        return false
    }

    guard let activeWindow = activeWindows.first,
          let boundsDict = activeWindow[kCGWindowBounds as String] as? [String: Any],
          let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else {
        return nil
    }

    // Get displays that intersect with the active window's bounds
    let maxDisplays: UInt32 = 16
    var displayCount: UInt32 = 0
    var displays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))

    let error = CGGetDisplaysWithRect(bounds, maxDisplays, &displays, &displayCount)
    if error == .success, displayCount > 0 {
        // Use the first display that matches
        let displayID = displays[0]

        // Capture the screenshot of the display
        guard let cgImage = CGDisplayCreateImage(displayID) else {
            return nil
        }

        let screenSize = CGSize(width: CGFloat(CGDisplayPixelsWide(displayID)), height: CGFloat(CGDisplayPixelsHigh(displayID)))
        return NSImage(cgImage: cgImage, size: screenSize)
    } else {
        print("No displays found for the active window.")
        return nil
    }
}

  // MARK: - OCR (Vision framework)

  /// On-device text recognition via Vision. Accepts encoded image bytes (PNG/JPEG),
  /// runs `VNRecognizeTextRequest`, and returns the joined text plus per-line blocks
  /// with their bounding boxes normalized 0..1 in **top-left** origin (flipped from
  /// Vision's bottom-left) so the Flutter side can position a Live-Text overlay
  /// directly. Runs off the main thread; `result` is always called exactly once.
  private func recognizeText(imageData: Data, languages: [String]?, fast: Bool, result: @escaping FlutterResult) {
    guard let nsImage = NSImage(data: imageData),
          let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      result(FlutterError(code: "DECODE_FAILED", message: "Could not decode image bytes", details: nil))
      return
    }

    let request = VNRecognizeTextRequest { req, error in
      if let error = error {
        DispatchQueue.main.async {
          result(FlutterError(code: "OCR_FAILED", message: error.localizedDescription, details: nil))
        }
        return
      }
      let observations = (req.results as? [VNRecognizedTextObservation]) ?? []
      var blocks: [[String: Any]] = []
      var lines: [String] = []
      for obs in observations {
        guard let candidate = obs.topCandidates(1).first else { continue }
        let bb = obs.boundingBox // normalized, bottom-left origin
        blocks.append([
          "text": candidate.string,
          "x": bb.minX,
          "y": 1.0 - bb.maxY, // flip to top-left origin for Flutter
          "w": bb.width,
          "h": bb.height,
          "confidence": candidate.confidence,
        ])
        lines.append(candidate.string)
      }
      let payload: [String: Any] = [
        "text": lines.joined(separator: "\n"),
        "blocks": blocks,
      ]
      DispatchQueue.main.async { result(payload) }
    }

    request.recognitionLevel = fast ? .fast : .accurate
    request.usesLanguageCorrection = true
    if let languages = languages, !languages.isEmpty {
      request.recognitionLanguages = languages
    } else if #available(macOS 13.0, *) {
      request.automaticallyDetectsLanguage = true
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try handler.perform([request])
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "OCR_FAILED", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  // MARK: - AI Lens (fullscreen frozen-frame mode)

  private var lensSavedFrame: NSRect?
  private var lensSavedLevel: NSWindow.Level?
  private var lensSavedCollectionBehavior: NSWindow.CollectionBehavior?

  // Snapshot of the world taken just before the lens window steals focus, so
  // the captured frame/metadata reflect what the user was actually looking at
  // (our own window must not be the frontmost app or appear in the screenshot).
  private var lensFrontApp: NSRunningApplication?
  private var lensFrontWindowTitle: String = ""
  private var lensCursorGlobal: NSPoint = .zero
  private var lensScreen: NSScreen?

  /// Captures the display currently under the cursor as a JPEG, plus that
  /// display's geometry, the cursor position within it (top-left origin, points),
  /// and the frontmost app/window — everything the Flutter lens needs to freeze
  /// the frame, position itself, and map a selection back to pixels.
  private func captureDisplayUnderCursor() -> [String: Any]? {
    // Use the snapshot taken in enterLensMode (before our window stole focus).
    // Fall back to live values if the lens wasn't entered first.
    let mouse = lensCursorGlobal != .zero ? lensCursorGlobal : NSEvent.mouseLocation
    let screen = lensScreen
      ?? NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
      ?? NSScreen.main
    guard let screen = screen,
          let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    else {
      return nil
    }

    // Capture the desktop strictly BELOW our lens window so our own dark backdrop
    // (and the dock drawn over it) is excluded — otherwise the frozen frame is just
    // our black window. CGDisplayBounds gives the display rect in CG global (top-left)
    // coordinates, exactly what CGWindowListCreateImage expects.
    let winNum = CGWindowID(mainFlutterWindow?.windowNumber ?? 0)
    let cgImage: CGImage?
    if winNum != 0 {
      cgImage = CGWindowListCreateImage(CGDisplayBounds(displayID), .optionOnScreenBelowWindow,
                                        winNum, [.boundsIgnoreFraming, .bestResolution])
    } else {
      cgImage = CGDisplayCreateImage(displayID)
    }
    guard let cgImage = cgImage else { return nil }

    // Return raw JPEG bytes (FlutterStandardTypedData) rather than base64 — far
    // cheaper to transfer a multi-megapixel frame across the channel.
    let rep = NSBitmapImageRep(cgImage: cgImage)
    let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) ?? Data()

    // Cursor within the display, top-left origin, in points (matches Flutter).
    let cursorInDisplayX = mouse.x - screen.frame.minX
    let cursorInDisplayY = screen.frame.maxY - mouse.y

    // The display's global top-left origin, in points — same space window_manager's
    // setPosition uses (primary display top-left = 0,0). Lets the Flutter side map a
    // display-local selection back to a global window position on multi-monitor.
    let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
    let originX = screen.frame.minX
    let originY = primaryHeight - screen.frame.maxY

    return [
      "imageBytes": FlutterStandardTypedData(bytes: jpeg),
      "pxWidth": cgImage.width,
      "pxHeight": cgImage.height,
      "pointWidth": screen.frame.width,
      "pointHeight": screen.frame.height,
      "scale": screen.backingScaleFactor,
      "cursorX": cursorInDisplayX,
      "cursorY": cursorInDisplayY,
      "originX": originX,
      "originY": originY,
      "focusedApp": lensFrontApp?.localizedName ?? "",
      "bundleId": lensFrontApp?.bundleIdentifier ?? "",
      "windowTitle": lensFrontWindowTitle,
    ]
  }

  /// Expands the main window to cover the display under the cursor and raises it
  /// above the menu bar / dock for the fullscreen lens. Prior state is saved so
  /// `exitLensMode` can restore it exactly.
  private func enterLensMode() {
    guard let window = mainFlutterWindow else { return }
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
    guard let screen = screen else { return }
    if lensSavedFrame == nil {
      lensSavedFrame = window.frame
      lensSavedLevel = window.level
      lensSavedCollectionBehavior = window.collectionBehavior
    }

    // Snapshot the real frontmost app + window title + cursor BEFORE we steal
    // focus. captureDisplayUnderCursor() uses these instead of re-querying, since
    // by then our lens window is the frontmost app.
    lensScreen = screen
    lensCursorGlobal = mouse
    lensFrontApp = NSWorkspace.shared.frontmostApplication
    lensFrontWindowTitle = ""
    if let pid = lensFrontApp?.processIdentifier,
       let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
         as NSArray? as? [[String: Any]] {
      for info in list {
        guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
              (info[kCGWindowLayer as String] as? Int) == 0 else { continue }
        if let name = info[kCGWindowName as String] as? String, !name.isEmpty {
          lensFrontWindowTitle = name
          break
        }
      }
    }

    window.setFrame(screen.frame, display: true)
    window.level = .screenSaver
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    regionCaptureManager?.isLensActive = true // don't let the snip tap fire inside the lens
  }

  /// Restores the window's pre-lens frame, level, and collection behavior.
  private func exitLensMode() {
    regionCaptureManager?.isLensActive = false
    guard let window = mainFlutterWindow else { return }
    if let f = lensSavedFrame { window.setFrame(f, display: true) }
    if let l = lensSavedLevel { window.level = l }
    if let cb = lensSavedCollectionBehavior { window.collectionBehavior = cb }
    lensSavedFrame = nil
    lensSavedLevel = nil
    lensSavedCollectionBehavior = nil
    lensFrontApp = nil
    lensFrontWindowTitle = ""
    lensCursorGlobal = .zero
    lensScreen = nil
  }
}

// Will be removed in the future
func performGlobalCopyShortcut() {
  func keyEvents(forPressAndReleaseVirtualKey virtualKey: Int) -> [CGEvent] {
    let eventSource = CGEventSource(stateID: .hidSystemState)
    return [
      CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(virtualKey), keyDown: true)!,
      CGEvent(keyboardEventSource: eventSource, virtualKey: CGKeyCode(virtualKey), keyDown: false)!,
    ]
  }

  let tapLocation = CGEventTapLocation.cghidEventTap
  let events = keyEvents(forPressAndReleaseVirtualKey: kVK_ANSI_C)

  for event in events {
    event.flags = .maskCommand
    event.post(tap: tapLocation)
  }
}

class CustomTimer {
  private var timer: Timer?
  private var customFunction: (() -> Void)?

  func startTimer(interval: TimeInterval, customFunction: @escaping () -> Void) {
    self.customFunction = customFunction

    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      self?.executeCustomFunction()
    }
  }

  private func executeCustomFunction() {
    customFunction?()
  }

  func stopTimer() {
    timer?.invalidate()
    timer = nil
    customFunction = nil
  }
}

extension AXUIElement {
  // Get the focused element
  static var focusedElement: AXUIElement? {
    systemWide.element(for: kAXFocusedUIElementAttribute)
  }

  // Get the selected text from the focused element
  var selectedText: String? {
    rawValue(for: kAXSelectedTextAttribute) as? String
  }

  // Get the name of the application
  var applicationName: String? {
    element(for: kAXParentAttribute)?.rawValue(for: kAXTitleAttribute) as? String
  }

  private static var systemWide = AXUIElementCreateSystemWide()

  private func element(for attribute: String) -> AXUIElement? {
    guard let rawValue = rawValue(for: attribute), CFGetTypeID(rawValue) == AXUIElementGetTypeID() else { return nil }
    return (rawValue as! AXUIElement)
  }

  private func rawValue(for attribute: String) -> AnyObject? {
    var rawValue: AnyObject?
    let error = AXUIElementCopyAttributeValue(self, attribute as CFString, &rawValue)
    return error == .success ? rawValue : nil
  }
}

// MARK: - Region snip-to-chat (Phase 0)

/// Seam that lets us swap the overlay's renderer later (e.g. a Metal "AI Lens" view)
/// without touching the event-tap / window / capture plumbing. Points are in the
/// overlay view's coordinate space (bottom-left origin).
protocol SelectionRenderer: AnyObject {
  func update(start: CGPoint?, end: CGPoint?)
}

/// Dims the whole desktop and punches a transparent hole with a red border for the
/// current selection. Pure Core Graphics for now; a future `MetalLensOverlayView`
/// can implement the same `SelectionRenderer` seam.
final class SnipOverlayView: NSView, SelectionRenderer {
  private var startPoint: CGPoint?
  private var endPoint: CGPoint?

  func update(start: CGPoint?, end: CGPoint?) {
    startPoint = start
    endPoint = end
    needsDisplay = true
  }

  private var selectionRect: NSRect? {
    guard let s = startPoint, let e = endPoint else { return nil }
    return NSRect(x: min(s.x, e.x), y: min(s.y, e.y),
                  width: abs(s.x - e.x), height: abs(s.y - e.y))
  }

  override func draw(_ dirtyRect: NSRect) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    ctx.setFillColor(NSColor.black.withAlphaComponent(0.3).cgColor)
    ctx.fill(bounds)
    guard let rect = selectionRect else { return }
    ctx.clear(rect) // punch a transparent hole so the real content shows through
    ctx.setStrokeColor(NSColor.systemRed.cgColor)
    ctx.setLineWidth(2)
    ctx.stroke(rect)
  }
}

/// Borderless, transparent, click-through panel that never steals focus.
/// `ignoresMouseEvents = true` because the event tap is the geometry source.
final class SnipOverlayWindow: NSPanel {
  init(frame: NSRect) {
    super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
               backing: .buffered, defer: false)
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    level = .screenSaver
    ignoresMouseEvents = true
    isReleasedWhenClosed = false
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
  }
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

/// Owns the global Cmd+Option+drag event tap, the selection overlay, the metadata
/// grab, and the capture-below-overlay screenshot. Sends the finished payload to
/// Flutter via `onRegionCaptured`.
final class RegionCaptureManager {
  private weak var methodChannel: FlutterMethodChannel?

  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?

  private var overlayWindow: SnipOverlayWindow?
  private var overlayView: SnipOverlayView?

  private var isSnipping = false
  private var cursorPushed = false
  /// True while the fullscreen AI Lens owns the screen. The lens has its own
  /// (Flutter-side) selection, so the tap must not also fire a Cmd+Shift snip.
  var isLensActive = false
  // CG global coordinates (top-left origin), taken straight from the events.
  private var startCG: CGPoint?
  private var lastCG: CGPoint?
  private var moveEventCount = 0

  // Metadata grabbed at mouse-down, before the overlay steals frontmost.
  private var frontAppName: String?
  private var frontBundleId: String?
  private var frontWindowTitle: String?

  init(methodChannel: FlutterMethodChannel?) {
    self.methodChannel = methodChannel
  }

  /// Routes native diagnostics to the Dart `[log]` stream (and stdout) so they are
  /// visible while debugging the gesture. Called on the main thread from the tap callback.
  private func sendDebug(_ message: String) {
    print("[Swift][RegionCapture] \(message)")
    methodChannel?.invokeMethod("onRegionCaptureDebug", arguments: message)
  }

  // MARK: Permissions

  func isScreenRecordingGranted() -> Bool {
    return CGPreflightScreenCaptureAccess()
  }

  func requestScreenRecordingAccess() -> Bool {
    return CGRequestScreenCaptureAccess()
  }

  // MARK: Service lifecycle

  /// Returns false (and triggers the system prompt) if Accessibility is not granted yet.
  func startService() -> Bool {
    if eventTap != nil { return true }

    if !AXIsProcessTrusted() {
      let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
      AXIsProcessTrustedWithOptions(options)
      print("[Swift] Region capture needs Accessibility permission.")
      return false
    }

    let mask = (1 << CGEventType.leftMouseDown.rawValue)
      | (1 << CGEventType.leftMouseDragged.rawValue)
      | (1 << CGEventType.mouseMoved.rawValue)
      | (1 << CGEventType.leftMouseUp.rawValue)
      | (1 << CGEventType.keyDown.rawValue)

    guard let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: CGEventMask(mask),
      callback: { _, type, event, refcon in
        guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
        let manager = Unmanaged<RegionCaptureManager>.fromOpaque(refcon).takeUnretainedValue()
        return manager.handle(type: type, event: event)
      },
      userInfo: Unmanaged.passUnretained(self).toOpaque()
    ) else {
      print("[Swift] Failed to create event tap for region capture.")
      return false
    }

    eventTap = tap
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    runLoopSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    sendDebug("service started, tap enabled (Cmd+Option or Cmd+Shift + drag).")
    return true
  }

  func stopService() {
    if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
    if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    eventTap = nil
    runLoopSource = nil
    cancelSnip()
    print("[Swift] Region capture service stopped.")
  }

  // MARK: Event handling (runs on the main run loop)

  private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
      if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
      return Unmanaged.passUnretained(event)

    case .keyDown:
      if isSnipping, event.getIntegerValueField(.keyboardEventKeycode) == 53 { // Escape
        cancelSnip()
        return nil
      }
      return Unmanaged.passUnretained(event)

    case .leftMouseDown:
      let flags = event.flags
      let cmd = flags.contains(.maskCommand)
      let opt = flags.contains(.maskAlternate)
      let shift = flags.contains(.maskShift)
      if cmd {
        sendDebug("mouseDown cmd=\(cmd) opt=\(opt) shift=\(shift) flagsRaw=\(flags.rawValue)")
      }
      // Activation gesture: Cmd+Shift+drag. (Cmd+Option was dropped — it collides
      // with window repositioning in some apps.) Suppressed while the lens is open.
      if !isSnipping, !isLensActive, cmd, shift {
        beginSnip(combo: "Cmd+Shift", atCG: event.location)
        return nil // consume so the app underneath never sees the gesture
      }
      return Unmanaged.passUnretained(event)

    case .leftMouseDragged, .mouseMoved:
      // After we consume the mouse-down, the window server treats motion as mouseMoved
      // (it never saw a button-down), so we must track both. Don't consume mouseMoved —
      // consuming it would freeze the visible cursor.
      if isSnipping {
        updateSnip(toCG: event.location)
        return type == .mouseMoved ? Unmanaged.passUnretained(event) : nil
      }
      return Unmanaged.passUnretained(event)

    case .leftMouseUp:
      if isSnipping {
        endSnip()
        return nil
      }
      return Unmanaged.passUnretained(event)

    default:
      return Unmanaged.passUnretained(event)
    }
  }

  // MARK: Snip session

  private func beginSnip(combo: String, atCG cg: CGPoint) {
    isSnipping = true
    startCG = cg
    lastCG = cg
    moveEventCount = 0
    sendDebug("beginSnip via \(combo) atCG=(\(cg.x), \(cg.y))")
    grabMetadata() // BEFORE the overlay shows, while the target app is still frontmost
    showOverlay()
    overlayView?.update(start: cgToViewPoint(cg), end: cgToViewPoint(cg))
    NSCursor.crosshair.push()
    cursorPushed = true
  }

  private func updateSnip(toCG cg: CGPoint) {
    guard let start = startCG else { return }
    lastCG = cg
    moveEventCount += 1
    overlayView?.update(start: cgToViewPoint(start), end: cgToViewPoint(cg))
  }

  private func endSnip() {
    guard let start = startCG, let end = lastCG else { cancelSnip(); return }
    isSnipping = false

    let rectCG = CGRect(x: min(start.x, end.x), y: min(start.y, end.y),
                        width: abs(start.x - end.x), height: abs(start.y - end.y))

    // Capture BELOW the overlay (excludes the dim tint) while it is still on screen.
    let windowNumber = CGWindowID(overlayWindow?.windowNumber ?? 0)
    let image: CGImage? = (rectCG.width >= 5 && rectCG.height >= 5)
      ? captureBelowCG(rectCG: rectCG, windowNumber: windowNumber)
      : nil

    teardownOverlay()
    let cursorEnd = end
    let moves = moveEventCount
    startCG = nil
    lastCG = nil

    sendDebug("endSnip rectCG=(\(rectCG.width)x\(rectCG.height)) moves=\(moves) windowNum=\(windowNumber) imageNil=\(image == nil)")
    if image == nil {
      return
    }
    sendResultCG(image: image, rectCG: rectCG, cursorCG: cursorEnd)
  }

  private func cancelSnip() {
    isSnipping = false
    startCG = nil
    lastCG = nil
    teardownOverlay()
  }

  // MARK: Overlay

  private func unionFrame() -> NSRect {
    return NSScreen.screens.reduce(NSRect.zero) { $0.union($1.frame) }
  }

  private func showOverlay() {
    let frame = unionFrame()
    if overlayWindow == nil {
      let window = SnipOverlayWindow(frame: frame)
      let view = SnipOverlayView(frame: NSRect(origin: .zero, size: frame.size))
      view.autoresizingMask = [.width, .height]
      window.contentView = view
      overlayWindow = window
      overlayView = view
    } else {
      overlayWindow?.setFrame(frame, display: false)
    }
    overlayView?.update(start: nil, end: nil)
    overlayWindow?.orderFrontRegardless()
    sendDebug("overlay shown frame=\(overlayWindow?.frame ?? .zero) visible=\(overlayWindow?.isVisible ?? false)")
  }

  private func teardownOverlay() {
    if cursorPushed {
      NSCursor.pop()
      cursorPushed = false
    }
    overlayView?.update(start: nil, end: nil)
    overlayWindow?.orderOut(nil)
  }

  /// CG global point (top-left origin) -> overlay view coordinates (bottom-left origin).
  private func cgToViewPoint(_ cg: CGPoint) -> CGPoint {
    let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
    let origin = overlayWindow?.frame.origin ?? .zero
    return CGPoint(x: cg.x - origin.x, y: (primaryHeight - cg.y) - origin.y)
  }

  // MARK: Capture + metadata

  private func grabMetadata() {
    let app = NSWorkspace.shared.frontmostApplication
    frontAppName = app?.localizedName
    frontBundleId = app?.bundleIdentifier
    frontWindowTitle = nil
    guard let pid = app?.processIdentifier else { return }

    if let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
      as NSArray? as? [[String: Any]] {
      for info in list {
        guard (info[kCGWindowOwnerPID as String] as? pid_t) == pid,
              (info[kCGWindowLayer as String] as? Int) == 0 else { continue }
        if let name = info[kCGWindowName as String] as? String, !name.isEmpty {
          frontWindowTitle = name
          break
        }
      }
    }
  }

  private func captureBelowCG(rectCG: CGRect, windowNumber: CGWindowID) -> CGImage? {
    // rectCG is already CG global (top-left). Captures everything below our overlay
    // window, so the dim tint is excluded. CGWindowListCreateImage is deprecated on
    // macOS 14+; swap to ScreenCaptureKit later.
    return CGWindowListCreateImage(rectCG, .optionOnScreenBelowWindow, windowNumber,
                                   [.boundsIgnoreFraming, .bestResolution])
  }

  private func sendResultCG(image: CGImage?, rectCG: CGRect, cursorCG: CGPoint) {
    var base64 = ""
    if let cg = image {
      let rep = NSBitmapImageRep(cgImage: cg)
      if let png = rep.representation(using: .png, properties: [:]) {
        base64 = png.base64EncodedString()
      }
    }
    let args: [String: Any] = [
      "imageBase64": base64,
      "focusedApp": frontAppName ?? "",
      "bundleId": frontBundleId ?? "",
      "windowTitle": frontWindowTitle ?? "",
      "rectX": rectCG.minX,
      "rectY": rectCG.minY,
      "rectW": rectCG.width,
      "rectH": rectCG.height,
      "cursorX": cursorCG.x,
      "cursorY": cursorCG.y,
    ]
    methodChannel?.invokeMethod("onRegionCaptured", arguments: args)
  }
}
