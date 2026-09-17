import Flutter
import UIKit
import WidgetKit
import UserNotifications
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
public struct ScheduleActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var statusTitle: String
        public var subject: String
        public var room: String
        public var teacher: String
        public var endTimeEpoch: Double
        public var isBreak: Bool
        public var nextPara: String
    }
    public var groupName: String
}
#endif

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

      let liveChannel = FlutterMethodChannel(name: "com.yearnings.rii/live_activity", binaryMessenger: messenger)
      liveChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if #available(iOS 16.1, *) {
          #if canImport(ActivityKit)
          if call.method == "startOrUpdateLive" {
            if let args = call.arguments as? [String: Any] {
              let title = args["title"] as? String ?? ""
              let subject = args["subject"] as? String ?? ""
              let room = args["room"] as? String ?? ""
              let teacher = args["teacher"] as? String ?? ""
              let endTimeEpoch = args["endTimeEpoch"] as? Double ?? 0.0
              let isBreak = args["isBreak"] as? Bool ?? false
              let nextPara = args["nextPara"] as? String ?? ""
              let groupName = args["groupName"] as? String ?? "РИИ"

              let state = ScheduleActivityAttributes.ContentState(
                statusTitle: title,
                subject: subject,
                room: room,
                teacher: teacher,
                endTimeEpoch: endTimeEpoch,
                isBreak: isBreak,
                nextPara: nextPara
              )

              if ActivityAuthorizationInfo().areActivitiesEnabled {
                Task {
                  if let existing = Activity<ScheduleActivityAttributes>.activities.first {
                    await existing.update(using: state)
                  } else {
                    let attrs = ScheduleActivityAttributes(groupName: groupName)
                    _ = try? Activity<ScheduleActivityAttributes>.request(attributes: attrs, contentState: state)
                  }
                }
              }
            }
            result(true)
          } else if call.method == "stopLive" {
            Task {
              for activity in Activity<ScheduleActivityAttributes>.activities {
                await activity.end(dismissalPolicy: .immediate)
              }
            }
            result(true)
          } else {
            result(FlutterMethodNotImplemented)
          }
          #else
          result(false)
          #endif
        } else {
          result(false)
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
