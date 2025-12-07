import Cocoa
import FlutterMacOS
import GoogleSignIn
// import FirebaseCore  // Dart에서 initializeApp() 하므로 불필요

@main
class AppDelegate: FlutterAppDelegate {

  // ✅ Obj-C 셀렉터로 확실히 노출
  @objc
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
  }

  // ✅ Google Sign-In 콜백 (macOS)
  @objc
  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      print("🔁 URL callback -> \(url.absoluteString)")
      if GIDSignIn.sharedInstance.handle(url) { return }
    }
    super.application(application, open: urls)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}

