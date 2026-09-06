import Flutter
import UIKit
import WidgetKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as? FlutterViewController
    if let messenger = controller?.binaryMessenger {
      let channel = FlutterMethodChannel(name: "com.yearnings.rii/widget", binaryMessenger: messenger)
      channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "updateWidget" {
          let defaults = UserDefaults(suiteName: "group.com.yearnings.riiSchedule") ?? UserDefaults.standard
          if let args = call.arguments as? [String: Any] {
            for (key, val) in args {
              defaults.set(val, forKey: key)
            }
          }
          defaults.synchronize()
          
          if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadAllTimelines()
          }
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }

      let notifChannel = FlutterMethodChannel(name: "com.yearnings.rii/notifications", binaryMessenger: messenger)
      notifChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "checkPermission" {
          if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
              result(settings.authorizationStatus == .authorized)
            }
          } else {
            result(true)
          }
        } else if call.method == "requestPermission" {
          if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
              result(granted)
            }
          } else {
            result(true)
          }
        } else if call.method == "showNotification" {
          if #available(iOS 10.0, *) {
            let content = UNMutableNotificationContent()
            if let args = call.arguments as? [String: Any] {
              content.title = args["title"] as? String ?? "РИИ Расписание"
              content.body = args["message"] as? String ?? ""
            }
            content.sound = .default
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(req)
          }
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
