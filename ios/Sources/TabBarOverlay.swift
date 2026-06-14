//
//  TabBarOverlay.swift
//  tauri-plugin-system-components
//
//  A bottom tab bar floated over the Tauri WKWebView. The bar is the official
//  Apple component: built with Xcode 26 against the iOS 26 SDK it adopts Liquid
//  Glass automatically and refracts the web content rendered behind it; on
//  older SDKs/devices it renders the classic translucent look.
//
//  IMPORTANT — why this hosts a UITabBarController and not a bare UITabBar:
//  a standalone `UITabBar` does not lay itself out correctly. Its internal
//  `_UITabBarPlatterView` runs its own layout and ignores the constraints you
//  pin it with, so on iOS 26 it floats well above the bottom edge (the bar is
//  ~62pt but its system container is ~83pt, and a lone bar can't reserve that
//  space) — i.e. it sits higher than every controller-managed bar in other
//  apps. Apple's guidance (DTS, developer forums thread 796299) is explicit:
//  use `UITabBarController` and let the system own the floating-glass metrics,
//  safe-area reservation, and minimize behavior. So the overlay embeds a real
//  `UITabBarController` whose content is transparent placeholder controllers —
//  the webview behind shows through and the glass refracts it, while tab taps
//  are reported to the web app without ever swapping real content.
//

import UIKit

/// Root view of the overlay controller: covers the whole host view so the tab
/// bar can pin to the real screen bottom, but only claims touches that land on
/// the bar (or the bottom accessory) — everything else falls through to the
/// webview behind.
final class PassthroughView: UIView {
    weak var interactiveView: UIView?
    /// The bottom accessory (account button) host, if any — also interactive.
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

final class TabBarOverlayController: UIViewController, UITabBarControllerDelegate {
    /// The system tab bar controller that owns the bar's geometry and glass.
    private let inner = UITabBarController()
    /// Exposed so callers can toggle the bar's visibility (see the plugin's
    /// show/hide), mirroring the previous standalone-bar surface.
    var tabBar: UITabBar { inner.tabBar }

    private(set) var ids: [String] = []
    var onSelect: ((String) -> Void)?

    /// Guards against echoing selection events back to the web app when *we*
    /// drive selection programmatically (initial selection / `selectTab`).
    private var suppressSelectionEvent = false

    // MARK: Accessory (account button)

    /// The configured account button's id, if any. Tapping the accessory
    /// reports through `onSelect(id)` — the same channel as tabs.
    private(set) var accessoryId: String?
    /// The accessory's content view (held so hit-testing can treat it as
    /// interactive and so we can tear it down on reconfigure).
    private weak var accessoryContent: UIView?

    /// Side of bitmap tab icons (avatars), in points.
    private static let imageSide: CGFloat = 26
    /// Side of the account button, in points.
    private static let accessorySide: CGFloat = 44

    override func loadView() {
        let passthrough = PassthroughView()
        passthrough.backgroundColor = .clear
        view = passthrough
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        inner.delegate = self
        // Transparent throughout so the webview behind shows through and the
        // glass bar refracts it.
        inner.view.backgroundColor = .clear
        addChild(inner)
        inner.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inner.view)
        NSLayoutConstraint.activate([
            inner.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inner.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inner.view.topAnchor.constraint(equalTo: view.topAnchor),
            inner.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        inner.didMove(toParent: self)
        (view as? PassthroughView)?.interactiveView = inner.tabBar
    }

    /// Tints the selected item via the bar's appearance (preserving the iOS 26
    /// glass background) — plain `tintColor` is ignored by the glass selection
    /// pill, so the accent has to ride on the appearance's selected colors.
    func applyTint(_ color: UIColor?) {
        let bar = inner.tabBar
        bar.tintColor = color
        guard let color else { return }
        let appearance = bar.standardAppearance
        for items in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ] {
            items.selected.iconColor = color
            items.selected.titleTextAttributes = [.foregroundColor: color]
        }
        bar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            bar.scrollEdgeAppearance = appearance
        }
    }

    /// Rebuilds the tabs. Each item becomes a transparent placeholder view
    /// controller carrying the item's `UITabBarItem`; the system tab bar
    /// controller derives the bar from them and positions it correctly.
    func apply(items: [TabItemArgs], selectedId: String?) {
        ids = items.map { $0.id }
        let controllers = items.enumerated().map { index, item -> UIViewController in
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
            let placeholder = UIViewController()
            placeholder.view.backgroundColor = .clear
            let barItem = UITabBarItem(title: item.title, image: image, tag: index)
            barItem.badgeValue = item.badge
            placeholder.tabBarItem = barItem
            return placeholder
        }
        let animated = !(inner.viewControllers?.isEmpty ?? true)
        inner.setViewControllers(controllers, animated: animated)
        select(id: selectedId ?? ids.first)
    }

    @discardableResult
    func select(id: String?) -> Bool {
        guard let id, let index = ids.firstIndex(of: id),
            let count = inner.viewControllers?.count, index < count
        else { return false }
        suppressSelectionEvent = true
        inner.selectedIndex = index
        suppressSelectionEvent = false
        return true
    }

    @discardableResult
    func setBadge(id: String, value: String?) -> Bool {
        guard let index = ids.firstIndex(of: id),
            let controllers = inner.viewControllers, index < controllers.count
        else { return false }
        controllers[index].tabBarItem.badgeValue = value
        return true
    }

    /// Mounts (or, with `id == nil`, removes) the account button as the tab
    /// bar's bottom accessory — the system slot that aligns the control with
    /// the bar and tucks it inline when the bar minimizes. The avatar fills a
    /// circle; with no image, an SF Symbol over a glass disc. Taps report
    /// through `onSelect(id)`.
    ///
    /// The bottom accessory is an iOS 26 API; on older systems the account
    /// button is omitted (the bar itself still renders, just without it).
    func setAccessory(id: String?, image: UIImage?, sfSymbol: String?) {
        accessoryContent?.removeFromSuperview()
        accessoryContent = nil
        (view as? PassthroughView)?.accessory = nil
        accessoryId = id

        #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                guard let id else {
                    inner.setBottomAccessory(nil, animated: true)
                    return
                }
                let content = makeAccessoryContent(id: id, image: image, sfSymbol: sfSymbol)
                inner.setBottomAccessory(UITabAccessory(contentView: content), animated: true)
                accessoryContent = content
                (view as? PassthroughView)?.accessory = content
                return
            }
        #endif
        // Pre-iOS 26: no bottom-accessory API. The account button is not shown;
        // surfacing it as a tab is the manual-form fallback on the web side.
        _ = (image, sfSymbol)
    }

    /// Builds the account button wrapped in a full-width content view, with the
    /// button pinned to the trailing edge so it reads as a circular control at
    /// the end of the accessory row.
    private func makeAccessoryContent(id: String, image: UIImage?, sfSymbol: String?) -> UIView {
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

        let content = UIView()
        content.backgroundColor = .clear
        content.addSubview(button)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: side),
            button.heightAnchor.constraint(equalToConstant: side),
            button.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            button.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor),
            button.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor),
            button.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            content.heightAnchor.constraint(greaterThanOrEqualToConstant: side),
        ])
        return content
    }

    /// Height of the region the bar occludes at the bottom of the screen, in
    /// CSS points — what the web content should pad itself by. Measured from the
    /// system-positioned bar, so it stays correct across devices.
    var bottomInset: CGFloat {
        view.layoutIfNeeded()
        let bar = inner.tabBar
        guard !(inner.viewControllers?.isEmpty ?? true), !bar.isHidden else { return 0 }
        let barFrame = bar.convert(bar.bounds, to: view)
        return max(0, view.bounds.height - barFrame.minY)
    }

    // MARK: UITabBarControllerDelegate

    func tabBarController(
        _ tabBarController: UITabBarController, didSelect viewController: UIViewController
    ) {
        guard !suppressSelectionEvent else { return }
        let index = tabBarController.selectedIndex
        guard index >= 0, index < ids.count else { return }
        onSelect?(ids[index])
    }
}
