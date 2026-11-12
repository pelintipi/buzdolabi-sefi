import AppIntents
import AVFoundation
import Flutter
import Speech
import UIKit
import Vision
import WidgetKit

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ShareInboxPlugin") {
      ShareInboxPlugin.register(with: registrar)
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "NativeBridgePlugin") {
      NativeBridgePlugin.register(with: registrar)
    }
  }
}

/// Uygulama ile eklentilerin (paylaşım, ana ekran aracı) ortak kutusu.
enum AppGroup {
  static var id: String { "group.\(Bundle.main.bundleIdentifier ?? "")" }
  static var defaults: UserDefaults? { UserDefaults(suiteName: id) }
}

/// Paylaşım eklentisinin (ios/ShareExtension) ortak kutuya bıraktığı
/// paylaşımları Flutter'a verir ve kutuyu boşaltır.
/// Dart tarafı: lib/services/video_import.dart → ShareInbox.
final class ShareInboxPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "buzdolabi_sefi/share", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ShareInboxPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "takePending" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let defaults = AppGroup.defaults else {
      result([])
      return
    }
    let pending = defaults.array(forKey: "pendingShares") ?? []
    defaults.removeObject(forKey: "pendingShares")
    result(pending)
  }
}

/// Dart tarafı: lib/services/device_services.dart → NativeBridge.
final class NativeBridgePlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "buzdolabi_sefi/native", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(NativeBridgePlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "recognizeText":
      guard let data = (args["image"] as? FlutterStandardTypedData)?.data else {
        result(FlutterError(code: "args", message: "Görüntü yok", details: nil))
        return
      }
      recognizeText(data, result: result)
    case "transcribeVideo":
      guard let path = args["path"] as? String else {
        result(FlutterError(code: "args", message: "Video yolu yok", details: nil))
        return
      }
      transcribe(path: path, locale: args["locale"] as? String ?? "tr-TR", result: result)
    case "updateWidget":
      updateWidget(args, result: result)
    case "shareInstagramStory":
      guard let data = (args["image"] as? FlutterStandardTypedData)?.data else {
        result(false)
        return
      }
      shareInstagramStory(data, appId: args["appId"] as? String ?? "", result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Fişten yazı (cihaz üstünde, Apple Vision)

  private func recognizeText(_ data: Data, result: @escaping FlutterResult) {
    guard let image = UIImage(data: data)?.cgImage else {
      result(FlutterError(code: "image", message: "Görüntü okunamadı", details: nil))
      return
    }
    let request = VNRecognizeTextRequest { request, error in
      let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
        // Fiş satırları yukarıdan aşağı sıralanır.
        .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        .compactMap { $0.topCandidates(1).first?.string }
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(code: "vision", message: error.localizedDescription, details: nil))
        } else {
          result(lines.joined(separator: "\n"))
        }
      }
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    // Türkçe desteklenmiyorsa (eski iOS) desteklenenlerle devam edilir.
    let wanted = ["tr-TR", "en-US"]
    if let supported = try? request.supportedRecognitionLanguages() {
      let usable = wanted.filter { supported.contains($0) }
      if !usable.isEmpty { request.recognitionLanguages = usable }
    }
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "vision", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  // MARK: - Videodaki konuşma (Apple Speech, mümkünse cihazda)

  private func transcribe(path: String, locale: String, result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { status in
      guard status == .authorized else {
        DispatchQueue.main.async {
          result(FlutterError(code: "permission", message: "Konuşma tanıma izni yok", details: nil))
        }
        return
      }
      self.extractAudio(from: URL(fileURLWithPath: path)) { audioURL in
        guard let audioURL,
              let recognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)),
              recognizer.isAvailable else {
          DispatchQueue.main.async {
            result(FlutterError(code: "speech", message: "Ses çözümlenemedi", details: nil))
          }
          return
        }
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition {
          request.requiresOnDeviceRecognition = true
        }
        recognizer.recognitionTask(with: request) { res, error in
          if let res, res.isFinal {
            try? FileManager.default.removeItem(at: audioURL)
            DispatchQueue.main.async { result(res.bestTranscription.formattedString) }
          } else if let error {
            try? FileManager.default.removeItem(at: audioURL)
            DispatchQueue.main.async {
              result(FlutterError(code: "speech", message: error.localizedDescription, details: nil))
            }
          }
        }
      }
    }
  }

  /// Videonun ses izini geçici bir m4a dosyasına çıkarır.
  private func extractAudio(from video: URL, completion: @escaping (URL?) -> Void) {
    let asset = AVURLAsset(url: video)
    guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
      completion(nil)
      return
    }
    let out = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
    export.outputURL = out
    export.outputFileType = .m4a
    export.exportAsynchronously {
      completion(export.status == .completed ? out : nil)
    }
  }

  // MARK: - Instagram hikâyesi
  // Görsel panoya Instagram'ın beklediği anahtarla konur, Instagram hikâye
  // düzenleyicisi doğrudan açılır. Instagram yüklü değilse false döner.

  private func shareInstagramStory(_ image: Data, appId: String, result: @escaping FlutterResult) {
    guard let url = URL(string: "instagram-stories://share?source_application=\(appId)"),
          UIApplication.shared.canOpenURL(url) else {
      result(false)
      return
    }
    UIPasteboard.general.setItems(
      [[
        "com.instagram.sharedSticker.backgroundImage": image,
        "com.instagram.sharedSticker.backgroundTopColor": "#1F3B2D",
        "com.instagram.sharedSticker.backgroundBottomColor": "#1F3B2D",
      ]],
      options: [.expirationDate: Date().addingTimeInterval(300)])
    UIApplication.shared.open(url, options: [:]) { ok in result(ok) }
  }

  // MARK: - Ana ekran aracı

  private func updateWidget(_ data: [String: Any], result: @escaping FlutterResult) {
    guard let defaults = AppGroup.defaults,
          let json = try? JSONSerialization.data(withJSONObject: data) else {
      result(false)
      return
    }
    defaults.set(json, forKey: "widgetData")
    WidgetCenter.shared.reloadAllTimelines()
    result(true)
  }
}

// MARK: - Siri / Kısayollar (iOS 16+)
// "Hey Siri, 6 yumurta ekle Buzdolabı Şefi" → uygulamayı
// buzdolabisefi://app/ekle?metin=6%20yumurta ile açar (lib/deep_links.dart).

@available(iOS 16.0, *)
struct AddToPantryIntent: AppIntent {
  static var title: LocalizedStringResource = "Dolaba malzeme ekle"
  static var description = IntentDescription(
    "Buzdolabı Şefi dolabına miktar ve malzeme ekler.")

  @Parameter(title: "Miktar")
  var quantity: Double?

  @Parameter(title: "Malzeme")
  var ingredient: String

  static var parameterSummary: some ParameterSummary {
    Summary("Dolabıma \(\.$quantity) \(\.$ingredient) ekle") {
      \.$quantity
      \.$ingredient
    }
  }

  func perform() async throws -> some IntentResult & OpensIntent & ProvidesDialog {
    let name = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty else {
      throw $ingredient.needsValueError("Hangi malzemeyi ekleyeyim?")
    }
    let phrase: String
    if let quantity {
      let amount = quantity == quantity.rounded()
        ? String(Int(quantity))
        : String(quantity)
      phrase = "\(amount) \(name)"
    } else {
      phrase = name
    }
    var parts = URLComponents()
    parts.scheme = "buzdolabisefi"
    parts.host = "app"
    parts.path = "/ekle"
    parts.queryItems = [URLQueryItem(name: "metin", value: phrase)]
    guard let url = parts.url else {
      throw NSError(
        domain: "BuzdolabiSefi", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Bağlantı oluşturulamadı"])
    }
    return .result(
      dialog: IntentDialog("Tamam, \(phrase) dolaba ekleniyor."),
      opensIntent: OpenURLIntent(url))
  }
}

@available(iOS 16.0, *)
struct BuzdolabiSefiShortcuts: AppShortcutsProvider {
  static var shortcutTileColor: ShortcutTileColor { .mint }

  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: AddToPantryIntent(),
      phrases: [
        "Dolabıma \(\.$quantity) \(\.$ingredient) ekle \(.applicationName)",
        "\(\.$quantity) \(\.$ingredient) ekle \(.applicationName)",
        "\(\.$ingredient) ekle \(.applicationName)",
        "Dolabıma \(\.$ingredient) ekle \(.applicationName)",
      ],
      shortTitle: "Dolaba ekle",
      systemImageName: "refrigerator")
  }
}
