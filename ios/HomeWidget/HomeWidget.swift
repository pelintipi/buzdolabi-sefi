import SwiftUI
import WidgetKit

/// iPhone ana ekran (ve kilit ekranı) aracı: "Bugün ne pişirsem?" ve bozulmak
/// üzere olan malzemeler. Veriyi uygulama yazar (AppDelegate.swift →
/// updateWidget, lib/state/digest.dart → Digest.widgetData); araç yalnızca
/// okur. Dokununca uygulama ilgili ekranda açılır (lib/deep_links.dart).

struct WidgetRecipe: Decodable, Hashable {
  let title: String
  let emoji: String
  let minutes: Int
  let kcal: Int
}

struct WidgetExpiring: Decodable, Hashable {
  let name: String
  let days: Int
}

/// Bozulmak üzere olan malzemeyi kullanan tarif önerisi.
struct WidgetUseUp: Decodable, Hashable {
  let ingredient: String
  let title: String
  let emoji: String
  let ready: Bool
}

struct WidgetData: Decodable {
  let readyCount: Int
  let recipes: [WidgetRecipe]
  let expiring: [WidgetExpiring]
  // Eski sürümün yazdığı veride yok; isteğe bağlı.
  let expiringCount: Int?
  let useUp: WidgetUseUp?

  var expiringTotal: Int { expiringCount ?? expiring.count }

  static let empty = WidgetData(
    readyCount: 0, recipes: [], expiring: [], expiringCount: 0, useUp: nil)
  static let sample = WidgetData(
    readyCount: 4,
    recipes: [
      WidgetRecipe(title: "Menemen", emoji: "🍳", minutes: 15, kcal: 287),
      WidgetRecipe(title: "Mercimek Çorbası", emoji: "🍲", minutes: 30, kcal: 210),
    ],
    expiring: [WidgetExpiring(name: "Kıyma", days: 1), WidgetExpiring(name: "Ispanak", days: 2)],
    expiringCount: 2,
    useUp: WidgetUseUp(ingredient: "Kıyma", title: "Kıymalı Pilav", emoji: "🍚", ready: true))

  static func load() -> WidgetData {
    var id = Bundle.main.bundleIdentifier ?? ""
    let suffix = ".HomeWidget"
    if id.hasSuffix(suffix) { id.removeLast(suffix.count) }
    guard let raw = UserDefaults(suiteName: "group.\(id)")?.data(forKey: "widgetData"),
          let data = try? JSONDecoder().decode(WidgetData.self, from: raw) else {
      return .empty
    }
    return data
  }
}

/// Uygulamanın açılacağı ekranlar (Info.plist → CFBundleURLSchemes).
enum WidgetLink {
  static let whatToCook = URL(string: "buzdolabisefi://app/ne-pisirsem")!
  static let pantry = URL(string: "buzdolabisefi://app/dolap")!
}

struct DigestEntry: TimelineEntry {
  let date: Date
  let data: WidgetData
}

struct DigestProvider: TimelineProvider {
  func placeholder(in context: Context) -> DigestEntry {
    DigestEntry(date: .now, data: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (DigestEntry) -> Void) {
    completion(DigestEntry(date: .now, data: context.isPreview ? .sample : WidgetData.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<DigestEntry>) -> Void) {
    // Uygulama her değişiklikte yeniler; yine de saatte bir kendisi bakar.
    let entry = DigestEntry(date: .now, data: WidgetData.load())
    completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600))))
  }
}

private let basil = Color(red: 0x1F / 255, green: 0x3B / 255, blue: 0x2D / 255)
private let butter = Color(red: 1, green: 0xCB / 255, blue: 0x45 / 255)

private func expiringText(_ d: WidgetData) -> String? {
  let n = d.expiringTotal
  guard n > 0 else { return nil }
  if n == 1, let e = d.expiring.first {
    return e.days <= 0 ? "\(e.name) bugün bozuluyor" : "\(e.name) \(e.days) gün içinde bozuluyor"
  }
  return "\(n) malzeme bozulmak üzere"
}

struct DigestView: View {
  let entry: DigestEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    if #available(iOSApplicationExtension 16.0, *), family == .accessoryInline {
      inline
    } else if #available(iOSApplicationExtension 16.0, *), family == .accessoryRectangular {
      rectangular
    } else {
      home
    }
  }

  // MARK: Kilit ekranı

  /// Saatin üstündeki tek satır.
  private var inline: some View {
    let d = entry.data
    let ready = d.readyCount > 0 ? "\(d.readyCount) tarif hazır" : "Ne pişirsem?"
    let text = d.expiringTotal > 0 ? "\(ready) · \(d.expiringTotal) bozuluyor" : ready
    return Text("🧑‍🍳 \(text)")
      .widgetURL(WidgetLink.whatToCook)
      .widgetBackground(.clear)
  }

  private var rectangular: some View {
    let d = entry.data
    return VStack(alignment: .leading, spacing: 1) {
      Text(d.readyCount > 0 ? "\(d.readyCount) tarif hazır" : "Ne pişirsem?")
        .font(.headline)
      if let first = d.recipes.first {
        Text("\(first.emoji) \(first.title)").font(.caption).lineLimit(1)
      }
      if let warn = expiringText(d) {
        Text("⚠︎ \(warn)").font(.caption2).lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .widgetURL(d.expiringTotal > 0 && d.recipes.isEmpty ? WidgetLink.pantry : WidgetLink.whatToCook)
    .widgetBackground(.clear)
  }

  // MARK: Ana ekran

  private var home: some View {
    let d = entry.data
    let small = family == .systemSmall
    return VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 4) {
        Text("🧑‍🍳")
        VStack(alignment: .leading, spacing: 0) {
          Text("Bugün ne pişirsem?")
            .font(.system(size: small ? 13 : 15, weight: .heavy, design: .rounded))
            .lineLimit(1)
          if d.readyCount > 0 {
            Text("\(d.readyCount) tarif dolabınla hazır")
              .font(.system(size: 11, weight: .semibold, design: .rounded))
              .opacity(0.8)
          }
        }
      }
      .foregroundStyle(.white)

      if d.recipes.isEmpty && d.useUp == nil {
        Text("Dolabına malzeme ekle, yapabileceklerini burada göster.")
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .foregroundStyle(.white.opacity(0.85))
      }

      // Orta boyutta: bozulacak malzemeyi değerlendiren tarif önce.
      if !small, let u = d.useUp {
        HStack(spacing: 6) {
          Text(u.emoji)
          VStack(alignment: .leading, spacing: 0) {
            Text("\(u.ingredient) değerlendir")
              .font(.system(size: 10, weight: .heavy, design: .rounded))
              .foregroundStyle(butter)
            Text(u.ready ? u.title : "\(u.title) · 1 eksik")
              .font(.system(size: 13, weight: .bold, design: .rounded))
              .foregroundStyle(.white)
              .lineLimit(1)
          }
        }
      }

      ForEach(d.recipes.filter { $0.title != d.useUp?.title }
                .prefix(small ? 2 : (d.useUp == nil ? 3 : 2)), id: \.self) { r in
        HStack(spacing: 6) {
          Text(r.emoji)
          VStack(alignment: .leading, spacing: 0) {
            Text(r.title)
              .font(.system(size: 13, weight: .bold, design: .rounded))
              .lineLimit(1)
            if !small {
              Text("\(r.minutes) dk · \(r.kcal) kcal")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .opacity(0.8)
            }
          }
        }
        .foregroundStyle(.white)
      }

      Spacer(minLength: 0)

      if let warn = expiringText(d) {
        // Orta boyutta uyarıya dokununca Dolabım açılır; küçükte tüm araç
        // tek bağlantıdır (iOS küçük araçta ayrı bağlantıya izin vermez).
        let badge = Text("⚠︎ \(warn)")
          .font(.system(size: 11, weight: .heavy, design: .rounded))
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(Capsule().fill(butter))
          .foregroundStyle(.black)
          .lineLimit(1)
        if small {
          badge
        } else {
          Link(destination: WidgetLink.pantry) { badge }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    // Küçük araçta, hazır tarif yok ama bozulacak varsa Dolabım açılır.
    .widgetURL(small && d.recipes.isEmpty && d.expiringTotal > 0
               ? WidgetLink.pantry : WidgetLink.whatToCook)
    .widgetBackground(basil)
  }
}

private extension View {
  /// iOS 17'de araç arka planı containerBackground ile verilmeli.
  @ViewBuilder func widgetBackground(_ color: Color) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(color, for: .widget)
    } else {
      padding().background(color)
    }
  }
}

@main
struct HomeWidget: Widget {
  private var families: [WidgetFamily] {
    if #available(iOSApplicationExtension 16.0, *) {
      return [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline]
    }
    return [.systemSmall, .systemMedium]
  }

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "BuzdolabiSefiDigest", provider: DigestProvider()) { entry in
      DigestView(entry: entry)
    }
    .configurationDisplayName("Bugün ne pişirsem?")
    .description("Dolabındakilerle yapabileceğin tarifler ve bozulmak üzere olanlar.")
    .supportedFamilies(families)
  }
}
