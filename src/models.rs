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
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub sf_symbol: Option<String>,
    /// Bitmap icon as base64 (raw or `data:` URL) — e.g. a user avatar.
    /// Takes precedence over `sf_symbol`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub image: Option<String>,
    /// Clip the bitmap `image` to a circle (avatar style).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub circular: Option<bool>,
    /// Optional badge text (e.g. "3"). `None` shows no badge.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub badge: Option<String>,
}

/// A standalone account button floated beside the bar (Apple Music
/// search-button style). `image` (base64 / data URL) wins over `sf_symbol`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AccessoryItem {
    /// Stable id reported back in `tabSelected` events when tapped.
    pub id: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub sf_symbol: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub image: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConfigureTabBarOptions {
    pub items: Vec<TabItem>,
    /// Tab to select initially; defaults to the first item.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub selected_id: Option<String>,
    /// Hex accent color `#RRGGBB[AA]` — selected-item color on iOS, glass
    /// capsule tint + selected segment color on macOS.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tint: Option<String>,
    /// Optional circular account button beside the bar (iOS). Ignored on macOS,
    /// where the account button is an overlay component instead.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub accessory: Option<AccessoryItem>,
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

/// Kind of native overlay component.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ComponentKind {
    /// UISwitch / NSSwitch — emits `change` with `on`.
    Switch,
    /// UIButton (glass configuration on iOS 26) / NSButton — emits `click`.
    Button,
    /// UISlider / NSSlider — emits `change` with `value`.
    Slider,
    /// UIProgressView / NSProgressIndicator — display only.
    Progress,
    /// UIImageView / NSImageView — display only (avatars, thumbnails).
    Image,
    /// A bare glass panel (UIGlassEffect / NSGlassEffectView, blur
    /// fallback) — pair with `below: true` + `absolute` placement to back
    /// DOM elements with real glass (see `attachGlassCard` in the JS API).
    Glass,
}

/// Where a component is pinned, relative to the window/safe area.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum ComponentAnchor {
    TopLeading,
    #[default]
    TopTrailing,
    BottomLeading,
    BottomTrailing,
    Center,
    /// Position by `props.x`/`props.y` (CSS points from the top-left) —
    /// for views synced to DOM element rects.
    Absolute,
    /// Cover the whole window, resizing with it (e.g. background images).
    Fill,
}

/// Per-kind properties. All optional; irrelevant fields are ignored.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct ComponentProps {
    /// Text: button title, switch/slider accessibility label.
    pub label: Option<String>,
    /// Switch state.
    pub on: Option<bool>,
    /// Slider/progress value (progress is 0..1).
    pub value: Option<f64>,
    pub min: Option<f64>,
    pub max: Option<f64>,
    /// SF Symbol for buttons.
    pub sf_symbol: Option<String>,
    /// Bitmap as base64 (raw or `data:` URL) — image components, button icons.
    pub image: Option<String>,
    /// Clip the bitmap to a circle (avatar style).
    pub circular: Option<bool>,
    /// Wrap the control in a floating glass capsule.
    pub glass: Option<bool>,
    /// Prominent (tinted) button style.
    pub prominent: Option<bool>,
    /// Hex tint color `#RRGGBB[AA]`.
    pub tint: Option<String>,
    /// Explicit size in points (defaults to the control's natural size).
    pub width: Option<f64>,
    pub height: Option<f64>,
    /// Top-left position in CSS points, for `absolute` placement. Also
    /// accepted by `update_component` to move/resize (DOM scroll sync).
    pub x: Option<f64>,
    pub y: Option<f64>,
    /// Corner radius for `glass` panels.
    pub corner_radius: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreateComponentOptions {
    /// Stable identifier, reported back in component events.
    pub id: String,
    pub kind: ComponentKind,
    #[serde(default)]
    pub props: ComponentProps,
    #[serde(default)]
    pub anchor: ComponentAnchor,
    /// Offset from the anchor, in points (dx grows inward/right, dy inward/down).
    #[serde(default)]
    pub dx: f64,
    #[serde(default)]
    pub dy: f64,
    /// Insert the view *below* the webview instead of above it. The webview
    /// is made transparent so unpainted DOM regions reveal the view — this
    /// is how glass panels sit behind DOM content (text stays sharp on
    /// top while the glass refracts what's behind the page).
    #[serde(default)]
    pub below: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateComponentOptions {
    pub id: String,
    pub props: ComponentProps,
}

/// Batched form of [`UpdateComponentOptions`] — one IPC round trip and one
/// (animation-disabled) native transaction for all geometry updates of a
/// frame. Used by the DOM scroll-sync path.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateComponentsOptions {
    pub components: Vec<UpdateComponentOptions>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RemoveComponentOptions {
    pub id: String,
}

/// Payload of the `liquid-glass://component-event` event on macOS (iOS
/// delivers the same shape through the plugin event channel).
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ComponentEventPayload {
    pub id: String,
    /// `click` (button) or `change` (switch/slider).
    pub event: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub on: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub value: Option<f64>,
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
