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

      if #available(iOS 10.0, *) {
        UNUserNotificationCenter.current().delegate = self
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
        } else if call.method == "scheduleNotification" {
          if #available(iOS 10.0, *) {
            if let args = call.arguments as? [String: Any] {
              let title = args["title"] as? String ?? "РИИ Расписание"
              let message = args["message"] as? String ?? ""
              let epochMillis = args["epochMillis"] as? Double ?? 0
              let id = args["id"] as? String ?? UUID().uuidString

              let triggerDate = Date(timeIntervalSince1970: epochMillis / 1000.0)
              let interval = triggerDate.timeIntervalSinceNow
              let content = UNMutableNotificationContent()
              content.title = title
              content.body = message
              content.sound = .default

              if interval <= 1.0 {
                let req = UNNotificationRequest(identifier: id, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(req)
              } else {
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(req)
              }
            }
          }
          result(true)
        } else if call.method == "openNotificationSettings" {
          if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
          }
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Гарантированное отображение баннера уведомлений, даже если приложение открыто на переднем плане
  @available(iOS 10.0, *)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge, .list])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
