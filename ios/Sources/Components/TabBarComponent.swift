//
//  TabBarComponent.swift
//  tauri-plugin-system-components
//

import UIKit

/// A UITabBar that is its own delegate (so it stays retained inside the view
/// tree without an external owner) and reports selection through a closure.
final class ComponentTabBar: UITabBar, UITabBarDelegate {
    private var ids: [String] = []
    private var onSelectId: ((String) -> Void)?

    /// Side of bitmap tab icons (avatars), in points.
    private static let imageSide: CGFloat = 26

    func configure(
        items: [TabItemArgs], selectedId: String?, tint: UIColor?,
        onSelect: @escaping (String) -> Void
    ) {
        onSelectId = onSelect
        delegate = self
        ids = items.map { $0.id }
        let barItems = items.enumerated().map { index, item -> UITabBarItem in
            var image: UIImage?
            if let b64 = item.image, let decoded = ImageUtil.decode(b64) {
                image = ImageUtil.icon(decoded, side: Self.imageSide, circular: item.circular ?? false)
            } else if let symbol = item.sfSymbol {
                image = UIImage(systemName: symbol)
            }
            let barItem = UITabBarItem(title: item.title, image: image, tag: index)
            barItem.badgeValue = item.badge
            return barItem
        }
        setItems(barItems, animated: false)
        if let selectedId, let idx = ids.firstIndex(of: selectedId), idx < barItems.count {
            selectedItem = barItems[idx]
        } else {
            selectedItem = barItems.first
        }
        applyTint(tint)
    }

    /// Highlight a tab by id without emitting a selection event.
    func selectTab(_ id: String) {
        guard let idx = ids.firstIndex(of: id), let items, idx < items.count else { return }
        selectedItem = items[idx]
    }

    /// Tint the selected item via the bar's appearance (so the iOS 26 glass
    /// selection pill honors the accent — plain `tintColor` alone does not).
    private func applyTint(_ color: UIColor?) {
        tintColor = color
        guard let color else { return }
        let appearance = standardAppearance
        for layout in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ] {
            layout.selected.iconColor = color
            layout.selected.titleTextAttributes = [.foregroundColor: color]
        }
        standardAppearance = appearance
        if #available(iOS 15.0, *) { scrollEdgeAppearance = appearance }
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard item.tag >= 0, item.tag < ids.count else { return }
        onSelectId?(ids[item.tag])
    }
}

/// The system tab bar as a component. `props.items` are the tabs; selection
/// emits a `select` event whose `detail` is the chosen tab id. `props.selectedId`
/// (via update) re-highlights without emitting.
enum TabBarComponent: ComponentBuilder {
    static func make(_ args: CreateComponentArgs, _ ctx: ComponentContext) -> UIView? {
        let props = args.props
        let bar = ComponentTabBar()
        let id = args.id
        let emit = ctx.emit
        bar.configure(
            items: props?.items ?? [],
            selectedId: props?.selectedId,
            tint: props?.tint.flatMap(ColorUtil.from(hex:))
        ) { tabId in emit(id, "select", nil, nil, tabId) }
        return bar
    }

    static func update(_ control: UIView, _ props: ComponentPropsArgs) {
        if let bar = control as? ComponentTabBar, let selectedId = props.selectedId {
            bar.selectTab(selectedId)
        }
    }
}
