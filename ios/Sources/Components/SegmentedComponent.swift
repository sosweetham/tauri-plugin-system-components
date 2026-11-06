//
//  SegmentedComponent.swift
//  tauri-plugin-system-components
//
//  The iOS "tab view" from Apple's HIG: a UISegmentedControl, floated on a
//  Liquid Glass capsule on iOS 26 (the platter system bars give it).
//

import UIKit

/// UISegmentedControl. `props.items` are the segments: `title`, or an
/// `sfSymbol` when `title` is empty (a segment holds a title *or* an image,
/// never both; VoiceOver reads the item `id` for symbol-only segments), plus an
/// optional `badge`. A tap emits `select` with the item id as `detail`. An
/// update with `items` rebuilds the segments; `selectedId` changes the
/// selection silently.
/// A `badge` renders as a colored pill after the title (`badgeColor` /
/// `badgeTextColor`): segments only hold a title *or* an image, so a badged
/// segment is drawn into an image with the control's own font.
final class ComponentSegmentedControl: UISegmentedControl {
    var ids: [String] = []
    var items: [TabItemArgs] = []
    var badgeColor: UIColor = .systemRed
    var badgeTextColor: UIColor = .white

    /// Set explicitly so image (badged) segments match title segments exactly.
    static let font = UIFont.systemFont(ofSize: 15, weight: .medium)
    static let badgeFont = UIFont.systemFont(ofSize: 12, weight: .semibold)

    func select(_ id: String?) {
        selectedSegmentIndex = id.flatMap { ids.firstIndex(of: $0) } ?? UISegmentedControl.noSegment
    }

    func build() {
        let selected = selectedSegmentIndex
        removeAllSegments()
        setTitleTextAttributes([.font: Self.font, .foregroundColor: UIColor.label], for: .normal)
        setTitleTextAttributes([.font: Self.font, .foregroundColor: UIColor.label], for: .selected)
        for (index, item) in items.enumerated() {
            if let badge = item.badge, !badge.isEmpty {
                insertSegment(with: badgedTitle(item.title, badge), at: index, animated: false)
            } else if item.title.isEmpty, let symbol = item.sfSymbol, let image = UIImage(systemName: symbol) {
                image.accessibilityLabel = item.id
                insertSegment(with: image, at: index, animated: false)
            } else {
                insertSegment(withTitle: item.title, at: index, animated: false)
            }
        }
        // Fewer segments after a rebuild: the old index may no longer exist.
        selectedSegmentIndex = selected < numberOfSegments ? selected : UISegmentedControl.noSegment
    }

    /// "Wednesday (3)": the title, then the badge in a colored pill.
    private func badgedTitle(_ title: String, _ badge: String) -> UIImage {
        let titleText = NSAttributedString(
            string: title, attributes: [.font: Self.font, .foregroundColor: UIColor.label.resolvedColor(with: traitCollection)])
        let badgeText = NSAttributedString(
            string: badge, attributes: [.font: Self.badgeFont, .foregroundColor: badgeTextColor])
        let titleSize = titleText.size()
        let badgeSize = badgeText.size()
        let gap: CGFloat = 6
        let pillHeight: CGFloat = 20
        let pillWidth = max(pillHeight, ceil(badgeSize.width) + 12)
        let size = CGSize(
            width: ceil(titleSize.width) + gap + pillWidth,
            height: max(ceil(titleSize.height), pillHeight))
        let format = UIGraphicsImageRendererFormat(for: traitCollection)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            titleText.draw(at: CGPoint(x: 0, y: (size.height - titleSize.height) / 2))
            let pill = CGRect(
                x: ceil(titleSize.width) + gap, y: (size.height - pillHeight) / 2,
                width: pillWidth, height: pillHeight)
            badgeColor.setFill()
            UIBezierPath(roundedRect: pill, cornerRadius: pillHeight / 2).fill()
            badgeText.draw(at: CGPoint(
                x: pill.midX - badgeSize.width / 2, y: pill.midY - badgeSize.height / 2))
        }.withRenderingMode(.alwaysOriginal)
        image.accessibilityLabel = "\(title), \(badge)"
        return image
    }

    // Light/dark switch: redraw so the title baked into the image follows.
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previous),
            items.contains(where: { !($0.badge ?? "").isEmpty }) {
            build()
        }
    }
}

enum SegmentedComponent: ComponentBuilder {
    static func make(_ args: CreateComponentArgs, _ ctx: ComponentContext) -> UIView? {
        let props = args.props
        let items = props?.items ?? []
        let control = ComponentSegmentedControl()
        control.ids = items.map { $0.id }
        control.items = items
        if let color = props?.badgeColor.flatMap(ColorUtil.from(hex:)) { control.badgeColor = color }
        if let color = props?.badgeTextColor.flatMap(ColorUtil.from(hex:)) { control.badgeTextColor = color }
        control.build()
        control.select(props?.selectedId ?? items.first?.id)
        let id = args.id
        let emit = ctx.emit
        control.addAction(
            UIAction { [weak control] _ in
                guard let control, control.selectedSegmentIndex >= 0,
                    control.selectedSegmentIndex < control.ids.count
                else { return }
                emit(id, "select", nil, nil, control.ids[control.selectedSegmentIndex])
            },
            for: .valueChanged)
        return glassPlatter(around: control) ?? control
    }

    /// iOS 26: system bars put segmented controls on a glass platter (see the
    /// Phone app). Standalone, the control has none — so add a capsule
    /// `UIGlassEffect` that refracts the page. The control fills it so its own
    /// track edge lines up with the capsule instead of showing a second outline.
    private static func glassPlatter(around control: UISegmentedControl) -> UIView? {
        #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                let glass = UIGlassEffect()
                glass.isInteractive = true
                let platter = UIVisualEffectView(effect: glass)
                platter.cornerConfiguration = .capsule()
                control.translatesAutoresizingMaskIntoConstraints = false
                platter.contentView.addSubview(control)
                NSLayoutConstraint.activate([
                    control.leadingAnchor.constraint(equalTo: platter.contentView.leadingAnchor),
                    control.trailingAnchor.constraint(equalTo: platter.contentView.trailingAnchor),
                    control.topAnchor.constraint(equalTo: platter.contentView.topAnchor),
                    control.bottomAnchor.constraint(equalTo: platter.contentView.bottomAnchor),
                ])
                return platter
            }
        #endif
        return nil
    }

    private static func segmented(in view: UIView) -> ComponentSegmentedControl? {
        if let control = view as? ComponentSegmentedControl { return control }
        for sub in view.subviews {
            if let found = segmented(in: sub) { return found }
        }
        return nil
    }

    static func update(_ control: UIView, _ props: ComponentPropsArgs) {
        guard let segmented = segmented(in: control) else { return }
        if let color = props.badgeColor.flatMap(ColorUtil.from(hex:)) { segmented.badgeColor = color }
        if let color = props.badgeTextColor.flatMap(ColorUtil.from(hex:)) { segmented.badgeTextColor = color }
        if let items = props.items {
            // Keep the selection by id across a rebuild (indices may shift).
            let current = segmented.selectedSegmentIndex >= 0 && segmented.selectedSegmentIndex < segmented.ids.count
                ? segmented.ids[segmented.selectedSegmentIndex] : nil
            segmented.items = items
            segmented.ids = items.map { $0.id }
            segmented.build()
            segmented.select(props.selectedId ?? current)
        } else if props.badgeColor != nil || props.badgeTextColor != nil {
            segmented.build()
        }
        if let selectedId = props.selectedId { segmented.select(selectedId) }
    }
}
