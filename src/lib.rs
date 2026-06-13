//! Apple Liquid Glass components for Tauri 2.
//!
//! - **iOS**: a native `UITabBar` overlaid on the webview — it adopts Liquid
//!   Glass automatically when the app is built with Xcode 26 against the
//!   iOS 26 SDK, and refracts the web content rendered behind it. Tab taps
//!   are forwarded to JS as `tabSelected` events.
//! - **macOS**: a glass window background via `NSGlassEffectView` (macOS 26),
//!   with an `NSVisualEffectView` blur fallback on older systems.

use tauri::{
    plugin::{Builder, TauriPlugin},
    Manager, Runtime,
};

pub use models::*;

#[cfg(desktop)]
mod desktop;
#[cfg(mobile)]
mod mobile;

mod commands;
mod error;
mod models;

pub use error::{Error, Result};

#[cfg(desktop)]
use desktop::LiquidGlass;
#[cfg(mobile)]
use mobile::LiquidGlass;

/// Extensions to [`tauri::App`], [`tauri::AppHandle`] and [`tauri::Window`] to access the liquid-glass APIs.
pub trait LiquidGlassExt<R: Runtime> {
    fn liquid_glass(&self) -> &LiquidGlass<R>;
}

impl<R: Runtime, T: Manager<R>> crate::LiquidGlassExt<R> for T {
    fn liquid_glass(&self) -> &LiquidGlass<R> {
        self.state::<LiquidGlass<R>>().inner()
    }
}

/// Initializes the plugin. Call this from your Tauri app's `lib.rs`:
///
/// ```ignore
/// .plugin(tauri_plugin_liquid_glass::init())
/// ```
pub fn init<R: Runtime>() -> TauriPlugin<R> {
    Builder::new("liquid-glass")
        .invoke_handler(tauri::generate_handler![
            commands::configure_tab_bar,
            commands::remove_tab_bar,
            commands::show_tab_bar,
            commands::hide_tab_bar,
            commands::select_tab,
            commands::set_badge,
            commands::get_tab_bar_insets,
            commands::present_sheet,
            commands::dismiss_sheet,
            commands::create_component,
            commands::update_component,
            commands::update_components,
            commands::remove_component,
            commands::is_glass_supported,
            commands::set_window_glass,
            commands::clear_window_glass,
        ])
        .setup(|app, api| {
            #[cfg(mobile)]
            let liquid_glass = mobile::init(app, api)?;
            #[cfg(desktop)]
            let liquid_glass = desktop::init(app, api)?;
            app.manage(liquid_glass);
            Ok(())
        })
        .build()
}
