use serde::{Deserialize, Serialize};

/// A single tab in the native bottom tab bar.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TabItem {
    /// Stable identifier reported back in `tabSelected` events.
    pub id: String,
    /// User-visible label under the icon.
    pub title: String,
    /// SF Symbol name (e.g. "house.fill"). Must exist on the device's OS
    /// version; unknown names render a label-only item.
    pub sf_symbol: String,
    /// Optional badge text (e.g. "3"). `None` shows no badge.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub badge: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConfigureTabBarOptions {
    pub items: Vec<TabItem>,
    /// Tab to select initially; defaults to the first item.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub selected_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SelectTabOptions {
    pub id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SetBadgeOptions {
    pub id: String,
    /// `None` clears the badge.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub value: Option<String>,
}

/// Space the web content should reserve so the floating bar doesn't cover it.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TabBarInsets {
    /// Bar height + bottom safe area, in CSS points.
    pub bottom: f64,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WindowGlassOptions {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub corner_radius: Option<f64>,
    /// Hex color, `#RRGGBB` or `#RRGGBBAA`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tint_color: Option<String>,
}

/// Payload of the `liquid-glass://tab-selected` event emitted on macOS
/// (iOS delivers the same shape through the plugin event channel).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TabSelectedPayload {
    pub id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GlassSupport {
    /// `true` when the real `NSGlassEffectView` (macOS 26+) is available.
    pub supported: bool,
    /// `true` when `set_window_glass` would use the `NSVisualEffectView`
    /// blur fallback instead of real glass.
    pub fallback: bool,
}
