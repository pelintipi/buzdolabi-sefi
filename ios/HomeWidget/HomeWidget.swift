import SwiftUI
import WidgetKit

/// iPhone ana ekran aracı: "Bugün yapabileceğin tarifler" ve bozulmak üzere
/// olanlar. Veriyi uygulama yazar (AppDelegate.swift → updateWidget,
/// lib/state/digest.dart → Digest.widgetData); araç yalnızca okur.

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

struct WidgetData: Decodable {
  let readyCount: Int
  let recipes: [WidgetRecipe]
  let expiring: [WidgetExpiring]

  static let empty = WidgetData(readyCount: 0, recipes: [], expiring: [])
  static let sample = WidgetData(
    readyCount: 4,
    recipes: [
      WidgetRecipe(title: "Menemen", emoji: "🍳", minutes: 15, kcal: 287),
      WidgetRecipe(title: "Mercimek Çorbası", emoji: "🍲", minutes: 30, kcal: 210),
    ],
    expiring: [WidgetExpiring(name: "Kıyma", days: 1)])

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

private let basil = Color(red: 0x1F / 255, green: 0x7A / 255, blue: 0x55 / 255)
private let butter = Color(red: 1, green: 0xCB / 255, blue: 0x45 / 255)
private let tomato = Color(red: 0xF2 / 255, green: 0x55 / 255, blue: 0x3A / 255)

struct DigestView: View {
  let entry: DigestEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    let d = entry.data
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 4) {
        Text("🧑‍🍳")
        Text(d.readyCount > 0 ? "\(d.readyCount) tarif hazır" : "Ne pişirsem?")
          .font(.system(size: 15, weight: .heavy, design: .rounded))
          .foregroundStyle(.white)
      }
      if d.recipes.isEmpty {
        Text("Dolabına malzeme ekle, yapabileceklerini burada göster.")
          .font(.system(size: 12, weight: .semibold, design: .rounded))
          .foregroundStyle(.white.opacity(0.85))
      }
      ForEach(d.recipes.prefix(family == .systemSmall ? 2 : 3), id: \.self) { r in
        HStack(spacing: 6) {
          Text(r.emoji)
          VStack(alignment: .leading, spacing: 0) {
            Text(r.title)
              .font(.system(size: 13, weight: .bold, design: .rounded))
              .lineLimit(1)
            if family != .systemSmall {
              Text("\(r.minutes) dk · \(r.kcal) kcal")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .opacity(0.8)
            }
          }
        }
        .foregroundStyle(.white)
      }
      Spacer(minLength: 0)
      if let e = d.expiring.first {
        Text(e.days <= 0 ? "\(e.name) bugün bozuluyor" : "\(e.name) \(e.days) gün içinde bozuluyor")
          .font(.system(size: 11, weight: .heavy, design: .rounded))
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(Capsule().fill(butter))
          .foregroundStyle(.black)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "BuzdolabiSefiDigest", provider: DigestProvider()) { entry in
      DigestView(entry: entry)
    }
    .configurationDisplayName("Bugün ne pişirsem?")
    .description("Dolabındakilerle yapabileceğin tarifler ve bozulmak üzere olanlar.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
