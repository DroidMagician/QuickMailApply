import Flutter
import MessageUI
import UIKit

@objc class MailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
  func mailComposeController(
    _ controller: MFMailComposeViewController,
    didFinishWith result: MFMailComposeResult,
    error: Error?
  ) {
    controller.dismiss(animated: true)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let mailDelegate = MailComposeDelegate()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.quickmail.apply/email",
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "openMailCompose" else {
          result(FlutterMethodNotImplemented)
          return
        }

        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
          return
        }

        let email = args["email"] as? String ?? ""
        let subject = args["subject"] as? String ?? ""
        let body = args["body"] as? String ?? ""
        let attachmentPath = args["attachmentPath"] as? String

        self?.openMailCompose(
          email: email,
          subject: subject,
          body: body,
          attachmentPath: attachmentPath,
          result: result
        )
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func openMailCompose(
    email: String,
    subject: String,
    body: String,
    attachmentPath: String?,
    result: @escaping FlutterResult
  ) {
    guard MFMailComposeViewController.canSendMail() else {
      if openMailtoFallback(email: email, subject: subject, body: body) {
        result(true)
      } else {
        result(FlutterError(code: "NO_MAIL", message: "No mail account configured.", details: nil))
      }
      return
    }

    let mail = MFMailComposeViewController()
    mail.mailComposeDelegate = mailDelegate
    mail.setToRecipients([email])
    mail.setSubject(subject)
    mail.setMessageBody(body, isHTML: false)

    if let attachmentPath, !attachmentPath.isEmpty {
      let fileURL = URL(fileURLWithPath: attachmentPath)
      if let data = try? Data(contentsOf: fileURL) {
        let mimeType = Self.mimeType(for: fileURL.pathExtension)
        mail.addAttachmentData(data, mimeType: mimeType, fileName: fileURL.lastPathComponent)
      }
    }

    window?.rootViewController?.present(mail, animated: true)
    result(true)
  }

  private func openMailtoFallback(email: String, subject: String, body: String) -> Bool {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = email
    components.queryItems = [
      URLQueryItem(name: "subject", value: subject),
      URLQueryItem(name: "body", value: body),
    ]

    guard let url = components.url else { return false }
    UIApplication.shared.open(url)
    return true
  }

  private static func mimeType(for pathExtension: String) -> String {
    switch pathExtension.lowercased() {
    case "pdf":
      return "application/pdf"
    case "doc":
      return "application/msword"
    case "docx":
      return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
    default:
      return "application/octet-stream"
    }
  }
}
