//
//  ComponentArgs.swift
//  tauri-plugin-system-components
//
//  Decodable argument models shared by the component system. Kept separate
//  from any one component so each component file owns only its own rendering.
//

import Foundation

/// Per-kind properties. All optional; a component reads only what it needs.
class ComponentPropsArgs: Decodable {
    let label: String?
    let on: Bool?
    let value: Double?
    let min: Double?
    let max: Double?
    let sfSymbol: String?
    let image: String?
    let circular: Bool?
    let glass: Bool?
    let prominent: Bool?
    let tint: String?
    let width: Double?
    let height: Double?
    /// Top-left position in CSS points, for `absolute` placement.
    let x: Double?
    let y: Double?
    /// Corner radius for `glass` panels.
    let cornerRadius: Double?
    /// `document` anchor: stick this many CSS points below the top of the
    /// visible area, like `position: sticky; top: …`.
    let stickyTop: Double?
    /// `document` anchor: bottom edge of the containing block (document CSS
    /// points) — the view stops sticking when its bottom reaches it. Only
    /// used with `stickyTop`; an update can change it but not remove it.
    let stickyBottom: Double?
    /// `segmented`: fill and text colors of the item `badge` pill.
    let badgeColor: String?
    let badgeTextColor: String?

    // `container` layout.
    let axis: String?
    let align: String?
    let spacing: Double?
    let inset: Double?

    // `tabBar`.
    let items: [TabItemArgs]?
    let selectedId: String?
    /// How the bar lays out its items: `"fill"` spreads them across the full
    /// width, `"centered"` hugs them in the middle, `"automatic"` (default) lets
    /// the system decide. Maps to `UITabBar.ItemPositioning`.
    let itemPositioning: String?
}

class CreateComponentArgs: Decodable {
    let id: String
    let kind: String
    let props: ComponentPropsArgs?
    let anchor: String?
    let dx: Double?
    let dy: Double?
    /// Insert below the (transparent) webview so DOM content renders sharp
    /// on top while the view shows through unpainted page regions.
    let below: Bool?
    /// Child components, for `kind == "container"` (recursive).
    let children: [CreateComponentArgs]?
}

class UpdateComponentArgs: Decodable {
    let id: String
    let props: ComponentPropsArgs
}

class UpdateComponentsArgs: Decodable {
    let components: [UpdateComponentArgs]
}

class RemoveComponentArgs: Decodable {
    let id: String
}
