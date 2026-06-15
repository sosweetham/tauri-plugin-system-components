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

import UIKit

/// Root view of the overlay controller: covers the whole host view so the
/// tab bar can pin to the real screen bottom, but only claims touches that
/// land on the bar itself — everything else falls through to the webview.
final class PassthroughView: UIView {
    weak var interactiveView: UIView?
    /// The standalone account button beside the bar, if any — also interactive.
    weak var accessory: UIView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        if let bar = interactiveView, !bar.isHidden, hit === bar || hit.isDescendant(of: bar) {
            return hit
        }
        if let acc = accessory, !acc.isHidden, hit === acc || hit.isDescendant(of: acc) {
            return hit
        }
        return nil
    }
}

final class TabBarOverlayController: UIViewController, UITabBarDelegate {
    let tabBar = UITabBar()
    private(set) var ids: [String] = []
    var onSelect: ((String) -> Void)?

    /// The bar's trailing edge — pinned to the screen edge normally, or to the
    /// account button's leading edge when an accessory is mounted (so the bar
    /// shrinks to leave room beside it, à la Apple Music's search button).
    private var trailingFull: NSLayoutConstraint!
    private var trailingToAccessory: NSLayoutConstraint?
    private var accessoryButton: UIButton?
    private(set) var accessoryId: String?

    /// The accessory's size and vertical placement are derived from the bar's
    /// live geometry (see `updateAccessoryGeometry`), so they are held here and
    /// refreshed on every layout pass rather than frozen at mount time.
    private var accessoryWidth: NSLayoutConstraint?
    private var accessoryHeight: NSLayoutConstraint?
    private var accessoryCenterY: NSLayoutConstraint?

    /// Avatar diameter, in points.
    private static let accessorySide: CGFloat = 50
    /// Gap between the avatar's trailing edge and the safe-area edge.
    private static let accessoryEdgeMargin: CGFloat = 16
    /// Gap between the bar's trailing edge and the avatar's leading edge.
    private static let accessoryGap: CGFloat = 14

    /// The bar's *visible* content-row height — its frame height minus the
    /// home-indicator inset it self-extends under. This is the height of the
    /// glass pill the user sees, so the accessory matches it to read as a
    /// sibling, and the icon row is centered within it.
    private var barContentHeight: CGFloat {
        let h = tabBar.bounds.height - tabBar.safeAreaInsets.bottom
        return h > 1 ? h : Self.accessorySide
    }

    override func loadView() {
        let passthrough = PassthroughView()
        passthrough.interactiveView = tabBar
        passthrough.backgroundColor = .clear
        view = passthrough
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.delegate = self
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)
        trailingFull = tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingFull,
            // UITabBar self-extends its background under the home indicator
            // when pinned to the physical bottom edge.
            tabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
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
    /// the bar. The avatar fills the circle; with no image, an SF Symbol over a
    /// glass disc. Taps report through `onSelect(id)` — the same channel as
    /// tabs — so the web app opens its account menu.
    func setAccessory(id: String?, image: UIImage?, sfSymbol: String?) {
        trailingToAccessory?.isActive = false
        trailingToAccessory = nil
        accessoryButton?.removeFromSuperview()
        accessoryButton = nil
        accessoryWidth = nil
        accessoryHeight = nil
        accessoryCenterY = nil
        (view as? PassthroughView)?.accessory = nil
        accessoryId = id
        trailingFull.isActive = true
        guard let id else { return }

        let side = Self.accessorySide
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.clipsToBounds = true
        button.layer.cornerRadius = side / 2
        if let image {
            button.setImage(image, for: .normal)
            button.imageView?.contentMode = .scaleAspectFill
            button.contentHorizontalAlignment = .fill
            button.contentVerticalAlignment = .fill
        } else {
            let effect: UIVisualEffect = {
                // UIGlassEffect ships in the iOS 26 SDK (Xcode 26 / Swift 6.2);
                // compile it out on older SDKs that lack the symbol.
                #if compiler(>=6.2)
                if #available(iOS 26.0, *) { return UIGlassEffect() }
                #endif
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
        view.addSubview(button)
        let guide = view.safeAreaLayoutGuide
        // Size and vertical placement are seeded from `side` and refined in
        // `updateAccessoryGeometry` once the bar reports a real frame: the
        // button matches the bar's content-row height and centers on it by
        // anchoring to the bar's own top (not a safe-area guess), so it stays
        // aligned across devices, orientations, and SDK metric changes.
        // Align the avatar to the bar's *content row* via the bar's own safe-area
        // layout guide: the guide excludes the home-indicator strip the bar
        // self-extends under, so its center is the glass-pill center. Centre the
        // avatar on that, but size it to a fraction of the row height so there's
        // margin above and below it (a smaller circle seated in the row, not a
        // disc stretched to the full bar height).
        let barGuide = tabBar.safeAreaLayoutGuide
        let heightC = button.heightAnchor.constraint(equalToConstant: Self.accessorySide)
        let widthC = button.widthAnchor.constraint(equalToConstant: Self.accessorySide)
        let centerYC = button.centerYAnchor.constraint(equalTo: barGuide.centerYAnchor)
        NSLayoutConstraint.activate([
            widthC,
            heightC,
            button.trailingAnchor.constraint(
                equalTo: guide.trailingAnchor, constant: -Self.accessoryEdgeMargin),
            centerYC,
        ])
        accessoryWidth = widthC
        accessoryHeight = heightC
        accessoryCenterY = centerYC
        // Shrink the bar so the button sits beside it, with a gap between them.
        trailingFull.isActive = false
        let shrink = tabBar.trailingAnchor.constraint(
            equalTo: button.leadingAnchor, constant: -Self.accessoryGap)
        shrink.isActive = true
        trailingToAccessory = shrink
        accessoryButton = button
        (view as? PassthroughView)?.accessory = button
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateAccessoryGeometry()
    }

    /// Match the accessory button to the bar's live content-row geometry: a
    /// circle the same height as the visible glass pill, vertically centered on
    /// the bar's icon row. Anchoring to `tabBar.topAnchor` plus half the content
    /// height lands on that row's center regardless of the home-indicator inset
    /// the bar extends under — which is why this replaces the old hardcoded
    /// `-24.5` offset that only held for one device metric.
    private func updateAccessoryGeometry() {
        guard let button = accessoryButton, button.bounds.height > 1 else { return }
        // Size/placement come from constraints on the bar's safe-area guide; here
        // we only keep the avatar perfectly circular as that height resolves.
        button.layer.cornerRadius = button.bounds.height / 2
        NSLog(
            "[pendi-nav][native] TabBarOverlay geometry barFrame=%@ barSafeBottom=%.1f avatar=%@",
            NSCoder.string(for: tabBar.frame), tabBar.safeAreaInsets.bottom,
            NSCoder.string(for: button.frame))
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
        NSLog(
            "[pendi-nav][native] TabBarOverlay(separate) apply tabs=%d accessory=%@",
            ids.count, accessoryId ?? "(none)")
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

    /// Height of the region the bar occludes at the bottom of the screen,
    /// in CSS points — what the web content should pad itself by.
    var bottomInset: CGFloat {
        view.layoutIfNeeded()
        guard !(tabBar.items?.isEmpty ?? true), !tabBar.isHidden else { return 0 }
        return max(0, view.bounds.height - tabBar.frame.minY)
    }

    // MARK: UITabBarDelegate

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard item.tag >= 0, item.tag < ids.count else { return }
        onSelect?(ids[item.tag])
    }
}
