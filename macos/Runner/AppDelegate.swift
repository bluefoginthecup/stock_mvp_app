import Cocoa
import FlutterMacOS
import GoogleSignIn
// import FirebaseCore  // Dart에서 initializeApp() 하므로 불필요

@main
class AppDelegate: FlutterAppDelegate {
  private var appBadgeChannel: FlutterMethodChannel?

  // ✅ Obj-C 셀렉터로 확실히 노출
  @objc
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    configureAppBadgeChannel()
  }

  private func configureAppBadgeChannel() {
    guard let registrar = registrar(forPlugin: "ChalstockAppBadge") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "chalstock/app_badge",
      binaryMessenger: registrar.messenger
    )
    appBadgeChannel = channel

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setBadgeCount":
        guard
          let arguments = call.arguments as? [String: Any],
          let count = arguments["count"] as? Int
        else {
          result(FlutterError(code: "bad_args", message: "Invalid badge payload", details: nil))
          return
        }

        DispatchQueue.main.async {
          NSApp.dockTile.badgeLabel = count > 0 ? "\(count)" : nil
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
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
