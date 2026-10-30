import UIKit
import WebKit

// Only the system controls claim touches; the existing webview keeps scrolling,
// text selection, and its back/forward gestures beneath this transparent overlay.
final class NavigationPassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        var ancestor: UIView? = hit
        while let current = ancestor, current !== self {
            if current is UIControl || current is UINavigationBar || current is UITabBar || current is UIToolbar {
                return hit
            }
            ancestor = current.superview
        }
        return nil
    }
}

final class AdaptiveTabs: UITabBarController {
    var onLayout: (() -> Void)?
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        onLayout?()
    }
}

// UIKit owns the placement: bottom tabs on standard iPhones, a vertical rail
// alongside the status area on Duo. Never override size classes or device models.
final class AdaptiveTabBarController: UIViewController, UITabBarControllerDelegate {
    let tabs = AdaptiveTabs()
    private var ids: [String] = []
    private var buttons: [String: (placement: String, item: UIBarButtonItem)] = [:]
    private var buttonOrder: [String] = []
    private var lastInsets: [String: Double] = [:]
    private weak var scrollView: UIScrollView?
    var onSelect: ((String) -> Void)?
    var onClick: ((String) -> Void)?
    var onLayout: (([String: Double]) -> Void)?

    override func loadView() {
        view = NavigationPassthroughView()
        view.backgroundColor = .clear
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tabs.delegate = self
        tabs.customizableViewControllers = []
        addChild(tabs)
        tabs.view.backgroundColor = .clear
        tabs.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabs.view)
        NSLayoutConstraint.activate([
            tabs.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabs.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabs.view.topAnchor.constraint(equalTo: view.topAnchor),
            tabs.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        tabs.didMove(toParent: self)
        tabs.onLayout = { [weak self] in self?.publishInsets() }
    }

    func mount(on host: UIViewController) {
        host.addChild(self)
        view.translatesAutoresizingMaskIntoConstraints = false
        host.view.addSubview(view)
        // Frame autoresizing can retain the old display geometry when Duo unfolds.
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: host.view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: host.view.trailingAnchor),
            view.topAnchor.constraint(equalTo: host.view.topAnchor),
            view.bottomAnchor.constraint(equalTo: host.view.bottomAnchor),
        ])
        didMove(toParent: host)
    }

    func apply(_ args: ConfigureTabBarArgs, webView: WKWebView?) {
        loadViewIfNeeded()
        scrollView = webView?.scrollView
        let oldSelection = tabs.selectedIndex < ids.count ? ids[tabs.selectedIndex] : nil
        ids = args.items.map(\.id)
        tabs.viewControllers = args.items.enumerated().map { index, item in
            let content = UIViewController()
            content.view.backgroundColor = .clear
            if #available(iOS 15.0, *) {
                content.setContentScrollView(scrollView, for: .all)
            }
            let nav = UINavigationController(rootViewController: content)
            nav.view.backgroundColor = .clear
            var image = item.sfSymbol.flatMap(UIImage.init(systemName:))
            if let decoded = item.image.flatMap(ImageUtil.decode) {
                image = ImageUtil.icon(decoded, side: 26, circular: item.circular ?? false)
            }
            nav.tabBarItem = UITabBarItem(title: item.title, image: image, tag: index)
            nav.tabBarItem.accessibilityLabel = item.title
            nav.tabBarItem.badgeValue = item.badge
            return nav
        }
        tabs.customizableViewControllers = []
        tabs.view.tintColor = args.tint.flatMap(ColorUtil.from(hex:))
        _ = select(id: args.selectedId ?? oldSelection ?? ids[0])
        refreshButtons()
        view.setNeedsLayout()
    }

    @discardableResult
    func select(id: String) -> Bool {
        guard let index = ids.firstIndex(of: id) else { return false }
        tabs.selectedIndex = index
        refreshButtons()
        return true
    }

    func setBadge(id: String, value: String?) -> Bool {
        guard let index = ids.firstIndex(of: id) else { return false }
        tabs.viewControllers?[index].tabBarItem.badgeValue = value
        return true
    }

    func createButton(_ args: CreateComponentArgs) {
        removeButton(id: args.id)
        let action = UIAction { [weak self] _ in self?.onClick?(args.id) }
        let item = UIBarButtonItem(title: nil, image: nil, primaryAction: action, menu: nil)
        buttons[args.id] = (args.navigation!, item)
        buttonOrder.append(args.id)
        if let props = args.props { _ = updateButton(id: args.id, props: props) }
        refreshButtons()
    }

    @discardableResult
    func updateButton(id: String, props: ComponentPropsArgs) -> Bool {
        guard let entry = buttons[id] else { return false }
        let item = entry.item
        if let label = props.label { item.accessibilityLabel = label; item.title = label }
        if let symbol = props.sfSymbol { item.image = UIImage(systemName: symbol) }
        if let image = props.image.flatMap(ImageUtil.decode) {
            item.image = ImageUtil.icon(image, side: 24, circular: props.circular ?? false)
        }
        if item.image != nil { item.title = nil }
        if let tint = props.tint { item.tintColor = ColorUtil.from(hex: tint) }
        return true
    }

    func removeButton(id: String) {
        buttons.removeValue(forKey: id)
        buttonOrder.removeAll { $0 == id }
        refreshButtons()
    }

    private func refreshButtons() {
        let leading = buttonOrder.compactMap { buttons[$0] }.filter { $0.placement == "leading" }.map(\.item)
        let trailing = buttonOrder.compactMap { buttons[$0] }.filter { $0.placement == "trailing" }.map(\.item)
        for case let nav as UINavigationController in tabs.viewControllers ?? [] {
            let selected = nav === tabs.selectedViewController
            nav.topViewController?.navigationItem.leftBarButtonItems = selected ? leading : []
            nav.topViewController?.navigationItem.rightBarButtonItems = selected ? trailing : []
            nav.setNavigationBarHidden(!selected || (leading.isEmpty && trailing.isEmpty), animated: false)
        }
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        publishInsets()
    }

    private func publishInsets() {
        guard !view.isHidden,
              let nav = tabs.selectedViewController as? UINavigationController,
              let content = nav.topViewController, content.isViewLoaded else { return }
        let frame = content.view.convert(content.view.safeAreaLayoutGuide.layoutFrame, to: view)
        let insets = [
            "top": max(0, frame.minY), "left": max(0, frame.minX),
            "bottom": max(0, view.bounds.maxY - frame.maxY),
            "right": max(0, view.bounds.maxX - frame.maxX),
        ].mapValues(Double.init)
        guard insets != lastInsets else { return }
        lastInsets = insets
        onLayout?(insets)
    }

    var bottomInset: CGFloat { view.isHidden ? 0 : CGFloat(lastInsets["bottom"] ?? 0) }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        refreshButtons()
        let index = tabs.selectedIndex
        if index < ids.count { onSelect?(ids[index]) }
    }
}
