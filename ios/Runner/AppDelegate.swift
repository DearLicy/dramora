import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.guomu.huangguo/share",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "share" else {
          result(FlutterMethodNotImplemented)
          return
        }

        let args = call.arguments as? [String: Any]
        let title = args?["title"] as? String ?? ""
        let text = args?["text"] as? String ?? ""
        let url = args?["url"] as? String ?? ""
        let shareText = [title, text, url]
          .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
          .joined(separator: "\n")

        let activity = UIActivityViewController(
          activityItems: [shareText],
          applicationActivities: nil
        )
        if let popover = activity.popoverPresentationController {
          popover.sourceView = controller.view
          popover.sourceRect = CGRect(
            x: controller.view.bounds.midX,
            y: controller.view.bounds.maxY - 40,
            width: 1,
            height: 1
          )
        }
        self?.window?.rootViewController?.present(activity, animated: true) {
          result(true)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
