//
//  TabBarOverlay.swift
//  tauri-plugin-system-components
//
//  A UITabBar floated over the Tauri WKWebView as a child view controller of
//  the host VC. The bar is the official Apple component: when the app is
//  built with Xcode 26 against the iOS 26 SDK it adopts Liquid Glass
//  automatically and refracts the web content rendered behind it. On older
//  SDKs/devices the same bar renders the classic translucent look.
//
//  The bar and the optional account button live in a horizontal UIStackView
//  "container", so the stack owns their layout (spacing + vertical alignment)
//  — no hand-tuned offsets. The container sits just above the bottom safe area
//  (where the iOS 26 bar floats), which keeps the bar at its natural icon-row
//  height so `.center` alignment seats the avatar right on the icons.
//

import UIKit

/// Root view of the overlay controller: covers the whole host view so the
/// nav container can pin near the screen bottom, but only claims touches that
/// land on the container itself — everything else falls through to the webview.
final class PassthroughView: UIView {
    weak var interactiveView: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        if let c = interactiveView, !c.isHidden, hit === c || hit.isDescendant(of: c) {
            return hit
        }
        return nil
    }
}

final class TabBarOverlayController: UIViewController, UITabBarDelegate {
    let tabBar = UITabBar()
    /// Horizontal container laying out the bar and the optional account button
    /// side by side. The stack handles alignment + spacing, so the button needs
    /// no absolute positioning.
    private let container = UIStackView()
    private(set) var ids: [String] = []
    var onSelect: ((String) -> Void)?

    private var accessoryButton: UIButton?
    private(set) var accessoryId: String?

    /// Side of the account button, in points.
    private static let accessorySide: CGFloat = 50

    override func loadView() {
        let passthrough = PassthroughView()
        passthrough.interactiveView = container
        passthrough.backgroundColor = .clear
        view = passthrough
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.delegate = self
        // The bar grows to fill the row; the account button keeps its size.
        tabBar.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tabBar.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        container.axis = .horizontal
        container.alignment = .center
        container.distribution = .fill
        container.spacing = 10
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addArrangedSubview(tabBar)
        view.addSubview(container)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -12),
            // Sit just above the home indicator — where the iOS 26 bar floats —
            // which keeps the bar at its natural (non-extended) height.
            container.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
        ])
    }

    /// Tints the selected item via the bar's appearance (preserving the iOS 26
    /// glass background) — plain `tintColor` is ignored by the glass selection
    /// pill, so the accent has to ride on the appearance's selected colors.
    func applyTint(_ color: UIColor?) {
        tabBar.tintColor = color
        guard let color else { return }
        let appearance = tabBar.standardAppearance
        for items in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ] {
            items.selected.iconColor = color
            items.selected.titleTextAttributes = [.foregroundColor: color]
        }
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
    }

    /// Mounts (or, with `id == nil`, removes) the circular account button beside
    /// the bar in the stack. The avatar fills the circle; with no image, an SF
    /// Symbol over a glass disc. Taps report through `onSelect(id)` — the same
    /// channel as tabs — so the web app opens its account menu.
    func setAccessory(id: String?, image: UIImage?, sfSymbol: String?) {
        accessoryButton?.removeFromSuperview()
        accessoryButton = nil
        accessoryId = id
        guard let id else { return }

        let side = Self.accessorySide
        let button = UIButton(type: .custom)
        button.clipsToBounds = true
        button.layer.cornerRadius = side / 2
        if let image {
            button.setImage(image, for: .normal)
            button.imageView?.contentMode = .scaleAspectFill
            button.contentHorizontalAlignment = .fill
            button.contentVerticalAlignment = .fill
        } else {
            let effect: UIVisualEffect = {
                if #available(iOS 26.0, *) { return UIGlassEffect() }
                return UIBlurEffect(style: .systemMaterial)
            }()
            let disc = UIVisualEffectView(effect: effect)
            disc.isUserInteractionEnabled = false
            disc.translatesAutoresizingMaskIntoConstraints = false
            button.insertSubview(disc, at: 0)
            NSLayoutConstraint.activate([
                disc.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                disc.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                disc.topAnchor.constraint(equalTo: button.topAnchor),
                disc.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            ])
            let conf = UIImage.SymbolConfiguration(pointSize: side * 0.46, weight: .regular)
            button.setImage(
                UIImage(systemName: sfSymbol ?? "person.crop.circle.fill", withConfiguration: conf),
                for: .normal)
            button.tintColor = .label
        }
        button.addAction(UIAction { [weak self] _ in self?.onSelect?(id) }, for: .touchUpInside)
        // Fixed size, and never compressed/stretched by the stack.
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: side),
            button.heightAnchor.constraint(equalToConstant: side),
        ])
        container.addArrangedSubview(button)
        accessoryButton = button
    }

    /// Side of bitmap tab icons (avatars), in points.
    private static let imageSide: CGFloat = 26

    func apply(items: [TabItemArgs], selectedId: String?) {
        ids = items.map { $0.id }
        let barItems = items.enumerated().map { index, item -> UITabBarItem in
            var image: UIImage?
            if let b64 = item.image, let decoded = ImageUtil.decode(b64) {
                image = ImageUtil.icon(
                    decoded,
                    side: Self.imageSide,
                    circular: item.circular ?? false
                )
            } else if let symbol = item.sfSymbol {
                image = UIImage(systemName: symbol)
            }
            let barItem = UITabBarItem(title: item.title, image: image, tag: index)
            barItem.badgeValue = item.badge
            return barItem
        }
        let animated = !(tabBar.items?.isEmpty ?? true)
        tabBar.setItems(barItems, animated: animated)
        select(id: selectedId ?? ids.first)
    }

    @discardableResult
    func select(id: String?) -> Bool {
        guard let id, let index = ids.firstIndex(of: id),
            let items = tabBar.items, index < items.count
        else { return false }
        tabBar.selectedItem = items[index]
        return true
    }

    @discardableResult
    func setBadge(id: String, value: String?) -> Bool {
        guard let index = ids.firstIndex(of: id),
            let items = tabBar.items, index < items.count
        else { return false }
        items[index].badgeValue = value
        return true
    }

    /// Height of the region the nav container occludes at the bottom of the
    /// screen, in CSS points — what the web content should pad itself by.
    var bottomInset: CGFloat {
        view.layoutIfNeeded()
        guard !(tabBar.items?.isEmpty ?? true), !tabBar.isHidden else { return 0 }
        return max(0, view.bounds.height - container.frame.minY)
    }

    // MARK: UITabBarDelegate

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard item.tag >= 0, item.tag < ids.count else { return }
        onSelect?(ids[item.tag])
    }
}
