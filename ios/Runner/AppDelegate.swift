import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SocialAuthConfigPlugin") {
      SocialAuthConfigPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "LiveFacePlugin") {
      LiveFacePlugin.register(with: registrar)
    }
  }
}

/// The camera stream is upright BGRA, mirrored by camera_avfoundation for selfies.
/// Frames stay on device; Vision runs away from the UI thread.
final class LiveFacePlugin: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "hair.live-face", qos: .userInitiated)

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "hair_app/live_face", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(LiveFacePlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "detect" else { result(FlutterMethodNotImplemented); return }
    guard let args = call.arguments as? [String: Any],
      let width = args["width"] as? Int, let height = args["height"] as? Int,
      let planes = args["planes"] as? [[String: Any]], let plane = planes.first,
      let stride = plane["rowStride"] as? Int,
      let bytes = plane["bytes"] as? FlutterStandardTypedData,
      width > 0, height > 0, stride >= width * 4, bytes.data.count >= stride * height
    else { result(FlutterError(code: "frame", message: "Invalid BGRA frame", details: nil)); return }

    queue.async {
      autoreleasepool {
        do {
          let image = CIImage(bitmapData: bytes.data, bytesPerRow: stride,
            size: CGSize(width: width, height: height), format: .BGRA8,
            colorSpace: CGColorSpaceCreateDeviceRGB())
          let request = VNDetectFaceRectanglesRequest()
          try VNImageRequestHandler(ciImage: image, orientation: .up).perform([request])
          let faces: [[String: Any]] = (request.results ?? []).map { face in
            let box = face.boundingBox
            let top = 1 - box.maxY
            var luma = 0.0
            var samples = 0
            // Sample only the face interior so a bright background cannot hide it.
            bytes.data.withUnsafeBytes { raw in
              let pixels = raw.bindMemory(to: UInt8.self)
              for sy in 0..<16 {
                for sx in 0..<16 {
                  let x = min(width - 1, max(0, Int((box.minX + box.width * (0.2 + Double(sx) / 15 * 0.6)) * Double(width))))
                  let y = min(height - 1, max(0, Int((top + box.height * (0.2 + Double(sy) / 15 * 0.6)) * Double(height))))
                  let i = y * stride + x * 4
                  luma += 0.2126 * Double(pixels[i + 2]) + 0.7152 * Double(pixels[i + 1]) + 0.0722 * Double(pixels[i])
                  samples += 1
                }
              }
            }
            var angles: [String: Any] = [:]
            if let yaw = face.yaw { angles["yaw"] = yaw.doubleValue * 180 / .pi }
            if let roll = face.roll { angles["roll"] = roll.doubleValue * 180 / .pi }
            if #available(iOS 15.0, *), let pitch = face.pitch {
              angles["pitch"] = pitch.doubleValue * 180 / .pi
            }
            return angles.merging([
              "x": box.minX, "y": top, "width": box.width, "height": box.height,
              "brightness": luma / Double(max(samples, 1)) / 255
            ]) { _, new in new }
          }
          DispatchQueue.main.async { result(["width": width, "height": height, "faces": faces]) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "detection", message: "Face guidance unavailable", details: nil))
          }
        }
      }
    }
  }
}

/// Validate Google callback setup before the SDK can raise an Obj-C exception.
final class SocialAuthConfigPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "hair_app/social_auth_config", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(SocialAuthConfigPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "googleConfigured" else { result(FlutterMethodNotImplemented); return }
    let info = Bundle.main.infoDictionary ?? [:]
    guard let clientID = info["GIDClientID"] as? String, clientID.hasSuffix(".apps.googleusercontent.com") else {
      result(false); return
    }
    let reversed = clientID.split(separator: ".").reversed().joined(separator: ".")
    let types = info["CFBundleURLTypes"] as? [[String: Any]] ?? []
    let schemes = types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    result(schemes.contains(reversed))
  }
}
