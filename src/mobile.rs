use serde::de::DeserializeOwned;
use tauri::{plugin::PluginApi, AppHandle, Runtime, WebviewWindow};

#[cfg(target_os = "ios")]
use tauri::plugin::PluginHandle;

use crate::models::*;
use crate::Error;

#[cfg(target_os = "ios")]
tauri::ios_plugin_binding!(init_plugin_liquid_glass);

/// Initializes the Swift plugin class registered by the host app.
///
/// There is no Android implementation in v1 — the plugin still loads there,
/// but every tab-bar command rejects with `Unsupported` so the web app can
/// fall back to an HTML tab bar (same contract as desktop).
pub fn init<R: Runtime, C: DeserializeOwned>(
    _app: &AppHandle<R>,
    #[allow(unused_variables)] api: PluginApi<R, C>,
) -> crate::Result<LiquidGlass<R>> {
    #[cfg(target_os = "ios")]
    {
        let handle = api.register_ios_plugin(init_plugin_liquid_glass)?;
        Ok(LiquidGlass { handle })
    }
    #[cfg(not(target_os = "ios"))]
    {
        Ok(LiquidGlass {
            _marker: std::marker::PhantomData,
        })
    }
}

/// Access to the liquid-glass APIs on mobile.
pub struct LiquidGlass<R: Runtime> {
    #[cfg(target_os = "ios")]
    handle: PluginHandle<R>,
    #[cfg(not(target_os = "ios"))]
    _marker: std::marker::PhantomData<R>,
}

/// Forwards a tab-bar method to the Swift plugin on iOS; rejects elsewhere.
/// Swift method names are camelCase to match the @objc selectors.
macro_rules! ios_command {
    ($self:ident, $name:literal, $payload:expr) => {{
        #[cfg(target_os = "ios")]
        {
            $self
                .handle
                .run_mobile_plugin($name, $payload)
                .map_err(Into::into)
        }
        #[cfg(not(target_os = "ios"))]
        {
            let _ = $payload;
            Err(Error::Unsupported("the native tab bar is iOS-only"))
        }
    }};
}

impl<R: Runtime> LiquidGlass<R> {
    pub fn configure_tab_bar(&self, options: ConfigureTabBarOptions) -> crate::Result<()> {
        ios_command!(self, "configureTabBar", options)
    }

    pub fn remove_tab_bar(&self) -> crate::Result<()> {
        ios_command!(self, "removeTabBar", ())
    }

    pub fn show_tab_bar(&self) -> crate::Result<()> {
        ios_command!(self, "showTabBar", ())
    }

    pub fn hide_tab_bar(&self) -> crate::Result<()> {
        ios_command!(self, "hideTabBar", ())
    }

    pub fn select_tab(&self, options: SelectTabOptions) -> crate::Result<()> {
        ios_command!(self, "selectTab", options)
    }

    pub fn set_badge(&self, options: SetBadgeOptions) -> crate::Result<()> {
        ios_command!(self, "setBadge", options)
    }

    pub fn get_tab_bar_insets(&self) -> crate::Result<TabBarInsets> {
        ios_command!(self, "getTabBarInsets", ())
    }

    pub fn create_component(&self, options: CreateComponentOptions) -> crate::Result<()> {
        ios_command!(self, "createComponent", options)
    }

    pub fn update_component(&self, options: UpdateComponentOptions) -> crate::Result<()> {
        ios_command!(self, "updateComponent", options)
    }

    pub fn remove_component(&self, options: RemoveComponentOptions) -> crate::Result<()> {
        ios_command!(self, "removeComponent", options)
    }

    // Window glass is a macOS (desktop) concept; these never reach Swift.

    pub fn is_glass_supported(&self) -> crate::Result<GlassSupport> {
        Ok(GlassSupport {
            supported: false,
            fallback: false,
        })
    }

    pub fn set_window_glass(
        &self,
        _window: WebviewWindow<R>,
        _options: WindowGlassOptions,
    ) -> crate::Result<()> {
        Err(Error::Unsupported("window glass is macOS-only"))
    }

    pub fn clear_window_glass(&self, _window: WebviewWindow<R>) -> crate::Result<()> {
        Err(Error::Unsupported("window glass is macOS-only"))
    }
}
