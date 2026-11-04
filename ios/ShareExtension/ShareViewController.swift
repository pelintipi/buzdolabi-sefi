import UIKit
import UniformTypeIdentifiers

/// TikTok → Paylaş → Buzdolabı Şefi.
///
/// Paylaşılan linki (ve varsa metni) uygulama grubunun ortak kutusuna bırakır,
/// "Kaydedildi" kartını gösterip kapanır. Uygulama açılınca
/// (AppDelegate.swift → ShareInboxPlugin) kutu boşaltılır; tarif açıklamadan
/// çıkarılıp kaydedilir ve dolapla karşılaştırılmış halde gösterilir.
final class ShareViewController: UIViewController {
  private static let basil = UIColor(red: 0x1F / 255, green: 0x7A / 255, blue: 0x55 / 255, alpha: 1)
  private static let ink = UIColor(red: 0x1D / 255, green: 0x2A / 255, blue: 0x22 / 255, alpha: 1)

  /// Ana uygulamanın kimliği + "group." (Runner.entitlements ile aynı).
  private var appGroupId: String {
    var id = Bundle.main.bundleIdentifier ?? ""
    let suffix = ".ShareExtension"
    if id.hasSuffix(suffix) { id.removeLast(suffix.count) }
    return "group.\(id)"
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = UIColor.black.withAlphaComponent(0.3)
    collect { [weak self] url, text in
      guard let self else { return }
      self.showCard(saved: self.save(url: url, text: text))
    }
  }

  // MARK: - Paylaşılanı oku

  private func collect(_ done: @escaping (String?, String?) -> Void) {
    let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
    var url: String?
    var texts: [String] = []
    for item in items {
      if let t = item.attributedContentText?.string, !t.isEmpty { texts.append(t) }
    }
    let lock = NSLock()
    let group = DispatchGroup()
    for provider in items.flatMap({ $0.attachments ?? [] }) {
      if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
        group.enter()
        provider.loadItem(forTypeIdentifier: UTType.url.identifier) { item, _ in
          lock.lock()
          if url == nil, let u = item as? URL { url = u.absoluteString }
          lock.unlock()
          group.leave()
        }
      } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
        group.enter()
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, _ in
          lock.lock()
          if let s = item as? String, !s.isEmpty { texts.append(s) }
          lock.unlock()
          group.leave()
        }
      }
    }
    group.notify(queue: .main) {
      done(url, texts.isEmpty ? nil : texts.joined(separator: "\n"))
    }
  }

  private func save(url: String?, text: String?) -> Bool {
    guard url != nil || text != nil,
          let defaults = UserDefaults(suiteName: appGroupId) else { return false }
    var pending = defaults.array(forKey: "pendingShares") as? [[String: String]] ?? []
    var entry = ["at": ISO8601DateFormatter().string(from: Date())]
    if let url { entry["url"] = url }
    if let text { entry["text"] = text }
    pending.append(entry)
    defaults.set(pending, forKey: "pendingShares")
    return true
  }

  // MARK: - "Kaydedildi" kartı

  private func rounded(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: weight)
    guard let d = base.fontDescriptor.withDesign(.rounded) else { return base }
    return UIFont(descriptor: d, size: size)
  }

  private func showCard(saved: Bool) {
    let card = UIView()
    card.backgroundColor = UIColor(red: 0xF4 / 255, green: 0xF7 / 255, blue: 0xF1 / 255, alpha: 1)
    card.layer.cornerRadius = 32
    card.translatesAutoresizingMaskIntoConstraints = false

    let icon = UILabel()
    icon.text = saved ? "🧑‍🍳" : "🤔"
    icon.font = .systemFont(ofSize: 64)

    let title = UILabel()
    title.text = saved ? "Buzdolabı Şefi'ne kaydedildi" : "Kaydedilemedi"
    title.font = rounded(22, .heavy)
    title.textColor = Self.ink
    title.textAlignment = .center
    title.numberOfLines = 0

    let subtitle = UILabel()
    subtitle.text = saved
      ? "Uygulamayı açınca tarif, dolabındakilerle karşılaştırılmış olarak hazır."
      : "Bu paylaşımda bir video linki bulamadım."
    subtitle.font = rounded(16, .semibold)
    subtitle.textColor = Self.ink.withAlphaComponent(0.7)
    subtitle.textAlignment = .center
    subtitle.numberOfLines = 0

    let button = UIButton(type: .system)
    button.setTitle("Tamam", for: .normal)
    button.titleLabel?.font = rounded(18, .heavy)
    button.setTitleColor(.white, for: .normal)
    button.backgroundColor = Self.basil
    button.layer.cornerRadius = 22
    button.heightAnchor.constraint(equalToConstant: 54).isActive = true
    button.addTarget(self, action: #selector(close), for: .touchUpInside)

    let stack = UIStackView(arrangedSubviews: [icon, title, subtitle, button])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 10
    stack.setCustomSpacing(20, after: subtitle)
    stack.translatesAutoresizingMaskIntoConstraints = false
    button.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

    card.addSubview(stack)
    view.addSubview(card)
    NSLayoutConstraint.activate([
      card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
      card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
      card.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
      stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -22),
      stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
    ])

    card.transform = CGAffineTransform(translationX: 0, y: 400)
    UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8,
                   initialSpringVelocity: 0.5) { card.transform = .identity }

    if saved {
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.close() }
    }
  }

  @objc private func close() {
    extensionContext?.completeRequest(returningItems: nil)
  }
}
