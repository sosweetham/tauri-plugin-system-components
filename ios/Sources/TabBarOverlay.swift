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

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        guard let bar = interactiveView, !bar.isHidden else { return nil }
        return hit === bar || hit.isDescendant(of: bar) ? hit : nil
    }
}

final class TabBarOverlayController: UIViewController, UITabBarDelegate {
    let tabBar = UITabBar()
    private(set) var ids: [String] = []
    var onSelect: ((String) -> Void)?

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
        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // UITabBar self-extends its background under the home indicator
            // when pinned to the physical bottom edge.
            tabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
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
