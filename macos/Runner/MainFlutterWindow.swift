import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    
    // Set window level
    self.level = .statusBar  // Higher than floating
    
    // Additional window behaviors
    self.collectionBehavior = [
      .canJoinAllSpaces,     // Window appears in all spaces
      .stationary,         // Uncomment to keep window in fixed position when spaces change
      //.ignoresCycle        // Uncomment to exclude from Cmd+Tab cycling
    ]
    
    RegisterGeneratedPlugins(registry: flutterViewController)
    
    super.awakeFromNib()
  }
}
