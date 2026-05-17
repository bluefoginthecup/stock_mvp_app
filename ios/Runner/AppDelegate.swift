import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let appGroupId = "group.com.bluefog.chalstock"
  private let widgetKind = "TodayScheduleWidget"
  private var widgetChannel: FlutterMethodChannel?
  private var pendingWidgetAction: String?
  private var widgetChannelConfigureAttempts = 0

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    configureWidgetChannel()
    return launched
  }

  private func configureWidgetChannel() {
    widgetChannelConfigureAttempts += 1

    guard let registrar = self.registrar(forPlugin: "ChalstockWidgetBridge") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "chalstock/widget",
      binaryMessenger: registrar.messenger()
    )
    widgetChannel = channel

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "AppDelegate missing", details: nil))
        return
      }

      switch call.method {
      case "saveTodaySchedules":
        guard let payload = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "Invalid schedule payload", details: nil))
          return
        }
        do {
          let data = try JSONSerialization.data(withJSONObject: payload, options: [])
          let json = String(data: data, encoding: .utf8) ?? "{}"
          guard let defaults = UserDefaults(suiteName: self.appGroupId) else {
            result(FlutterError(code: "app_group_unavailable", message: "App Group storage is unavailable", details: self.appGroupId))
            return
          }
          defaults.set(json, forKey: "todaySchedulesJson")
          defaults.synchronize()
          WidgetCenter.shared.reloadTimelines(ofKind: self.widgetKind)
          result(nil)
        } catch {
          result(FlutterError(code: "encode_failed", message: error.localizedDescription, details: nil))
        }
      case "saveTodaySchedulesJson":
        guard let json = call.arguments as? String else {
          result(FlutterError(code: "bad_args", message: "Invalid schedule JSON payload", details: nil))
          return
        }
        guard let defaults = UserDefaults(suiteName: self.appGroupId) else {
          result(FlutterError(code: "app_group_unavailable", message: "App Group storage is unavailable", details: self.appGroupId))
          return
        }
        defaults.set(json, forKey: "todaySchedulesJson")
        defaults.synchronize()

        if let containerUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.appGroupId) {
          do {
            let fileUrl = containerUrl.appendingPathComponent("todaySchedules.json")
            try json.write(to: fileUrl, atomically: true, encoding: .utf8)
          } catch {
            result(FlutterError(code: "file_write_failed", message: error.localizedDescription, details: nil))
            return
          }
        } else {
          result(FlutterError(code: "app_group_container_unavailable", message: "App Group file container is unavailable", details: self.appGroupId))
          return
        }

        WidgetCenter.shared.reloadTimelines(ofKind: self.widgetKind)
        result(nil)
      case "getInitialAction":
        result(self.consumePendingWidgetAction())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    if url.scheme == "chalstock" {
      handleWidgetUrl(url)
      return true
    }

    return super.application(app, open: url, options: options)
  }

  private func handleWidgetUrl(_ url: URL) {
    let action: String?
    switch url.host {
    case "home":
      action = "home"
    case "memo":
      action = "memo"
    case "stock":
      action = "stock"
    case "schedules":
      if url.path == "/new" {
        action = "newSchedule"
      } else if url.path == "/detail" {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let id = components?.queryItems?.first(where: { $0.name == "id" })?.value
        action = id == nil ? nil : "schedule:\(id!)"
      } else {
        action = "todaySchedules"
      }
    default:
      action = nil
    }

    guard let action else { return }

    pendingWidgetAction = action
    if let channel = widgetChannel {
      channel.invokeMethod("widgetAction", arguments: action)
    }
  }

  private func consumePendingWidgetAction() -> String? {
    let action = pendingWidgetAction
    pendingWidgetAction = nil
    return action
  }
}
