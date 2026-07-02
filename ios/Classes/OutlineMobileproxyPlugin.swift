import Flutter
import UIKit
import Mobileproxy

/// Flutter plugin bridging to the Outline SDK's Mobileproxy Go Mobile library
/// (golang.getoutline.org/sdk/x/mobileproxy), bundled as
/// `Frameworks/Mobileproxy.xcframework`.
///
/// All state mutations (starting/stopping the proxy) run serialized on
/// `proxyQueue` so that concurrent method calls from Dart can't race each
/// other. `FlutterResult` is always invoked back on the main thread, as
/// required by the Flutter iOS embedder.
public class OutlineMobileproxyPlugin: NSObject, FlutterPlugin {
  private let proxyQueue = DispatchQueue(label: "org.outline.mobileproxy.queue")
  private var runningProxy: MobileproxyProxy?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "outline_mobileproxy", binaryMessenger: registrar.messenger())
    let instance = OutlineMobileproxyPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "start":
      handleStart(call, result: result)
    case "startSmart":
      handleStartSmart(call, result: result)
    case "stop":
      handleStop(call, result: result)
    case "isRunning":
      proxyQueue.async {
        let running = self.runningProxy != nil
        DispatchQueue.main.async { result(running) }
      }
    case "currentProxy":
      proxyQueue.async {
        let address = self.runningProxy?.address()
        DispatchQueue.main.async { result(address) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleStart(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let transportConfig = args["transportConfig"] as? String, !transportConfig.isEmpty
    else {
      result(FlutterError(code: "INVALID_CONFIG", message: "transportConfig must not be empty", details: nil))
      return
    }
    let localAddress = args["localAddress"] as? String ?? "127.0.0.1:0"

    proxyQueue.async {
      self.stopLocked(timeoutSeconds: 0)

      let dialer: MobileproxyStreamDialer
      do {
        dialer = try Self.newStreamDialer(fromConfig: transportConfig)
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "INVALID_CONFIG", message: error.localizedDescription, details: nil))
        }
        return
      }

      self.startLocked(localAddress: localAddress, dialer: dialer, result: result)
    }
  }

  private func handleStartSmart(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let testDomains = args["testDomains"] as? [String], !testDomains.isEmpty,
      let strategiesConfig = args["strategiesConfig"] as? String, !strategiesConfig.isEmpty
    else {
      result(
        FlutterError(
          code: "INVALID_CONFIG", message: "testDomains and strategiesConfig must not be empty", details: nil))
      return
    }
    let enableLogging = args["enableLogging"] as? Bool ?? false
    let localAddress = args["localAddress"] as? String ?? "127.0.0.1:0"

    proxyQueue.async {
      self.stopLocked(timeoutSeconds: 0)

      guard let domainList = MobileproxyNewListFromLines(testDomains.joined(separator: "\n")) else {
        DispatchQueue.main.async {
          result(FlutterError(code: "INVALID_CONFIG", message: "Failed to build test domain list", details: nil))
        }
        return
      }
      guard let options = MobileproxyNewSmartDialerOptions(domainList, strategiesConfig) else {
        DispatchQueue.main.async {
          result(FlutterError(code: "INVALID_CONFIG", message: "Invalid strategies config", details: nil))
        }
        return
      }
      if enableLogging {
        options.setLogWriter(MobileproxyNewStderrLogWriter())
      }

      let dialer: MobileproxyStreamDialer
      do {
        dialer = try options.newStreamDialer()
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "INVALID_CONFIG", message: error.localizedDescription, details: nil))
        }
        return
      }

      self.startLocked(localAddress: localAddress, dialer: dialer, result: result)
    }
  }

  private func handleStop(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    let timeoutSeconds = args?["timeoutSeconds"] as? Int ?? 5
    proxyQueue.async {
      self.stopLocked(timeoutSeconds: timeoutSeconds)
      DispatchQueue.main.async { result(nil) }
    }
  }

  /// Must be called on `proxyQueue`. Starts a new proxy; assumes none is running.
  private func startLocked(localAddress: String, dialer: MobileproxyStreamDialer, result: @escaping FlutterResult) {
    do {
      let proxy = try Self.runProxy(localAddress: localAddress, dialer: dialer)
      self.runningProxy = proxy
      let address = proxy.address()
      DispatchQueue.main.async { result(address) }
    } catch {
      DispatchQueue.main.async {
        result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
      }
    }
  }

  /// Must be called on `proxyQueue`. No-op if no proxy is running.
  private func stopLocked(timeoutSeconds: Int) {
    runningProxy?.stop(timeoutSeconds)
    runningProxy = nil
  }

  /// The Mobileproxy header exposes `NewStreamDialerFromConfig` as a plain C
  /// function taking a trailing `NSError **`, which Swift only auto-bridges
  /// to `throws` for Objective-C methods, not free functions. Wrap it by hand.
  private static func newStreamDialer(fromConfig config: String) throws -> MobileproxyStreamDialer {
    var error: NSError?
    guard let dialer = MobileproxyNewStreamDialerFromConfig(config, &error) else {
      throw error ?? unknownNativeError()
    }
    return dialer
  }

  /// Same trailing-`NSError**` free-function situation as
  /// `newStreamDialer(fromConfig:)` above.
  private static func runProxy(localAddress: String, dialer: MobileproxyStreamDialer) throws -> MobileproxyProxy {
    var error: NSError?
    guard let proxy = MobileproxyRunProxy(localAddress, dialer, &error) else {
      throw error ?? unknownNativeError()
    }
    return proxy
  }

  private static func unknownNativeError() -> NSError {
    NSError(
      domain: "OutlineMobileproxyPlugin", code: -1,
      userInfo: [NSLocalizedDescriptionKey: "Unknown Mobileproxy error"])
  }
}
