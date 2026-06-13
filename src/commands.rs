use tauri::{command, AppHandle, Manager, Runtime, WebviewWindow};

use crate::models::*;
use crate::LiquidGlassExt;
use crate::Result;

#[command]
pub(crate) async fn configure_tab_bar<R: Runtime>(
    app: AppHandle<R>,
    options: ConfigureTabBarOptions,
) -> Result<()> {
    app.liquid_glass().configure_tab_bar(options)
}

#[command]
pub(crate) async fn remove_tab_bar<R: Runtime>(app: AppHandle<R>) -> Result<()> {
    app.liquid_glass().remove_tab_bar()
}

#[command]
pub(crate) async fn show_tab_bar<R: Runtime>(app: AppHandle<R>) -> Result<()> {
    app.liquid_glass().show_tab_bar()
}

#[command]
pub(crate) async fn hide_tab_bar<R: Runtime>(app: AppHandle<R>) -> Result<()> {
    app.liquid_glass().hide_tab_bar()
}

#[command]
pub(crate) async fn select_tab<R: Runtime>(
    app: AppHandle<R>,
    options: SelectTabOptions,
) -> Result<()> {
    app.liquid_glass().select_tab(options)
}

#[command]
pub(crate) async fn set_badge<R: Runtime>(
    app: AppHandle<R>,
    options: SetBadgeOptions,
) -> Result<()> {
    app.liquid_glass().set_badge(options)
}

#[command]
pub(crate) async fn get_tab_bar_insets<R: Runtime>(app: AppHandle<R>) -> Result<TabBarInsets> {
    app.liquid_glass().get_tab_bar_insets()
}

#[command]
pub(crate) async fn present_sheet<R: Runtime>(
    app: AppHandle<R>,
    options: PresentSheetOptions,
) -> Result<()> {
    app.liquid_glass().present_sheet(options)
}

#[command]
pub(crate) async fn dismiss_sheet<R: Runtime>(
    app: AppHandle<R>,
    options: DismissSheetOptions,
) -> Result<()> {
    app.liquid_glass().dismiss_sheet(options)
}

#[command]
pub(crate) async fn create_component<R: Runtime>(
    app: AppHandle<R>,
    options: CreateComponentOptions,
) -> Result<()> {
    app.liquid_glass().create_component(options)
}

#[command]
pub(crate) async fn update_component<R: Runtime>(
    app: AppHandle<R>,
    options: UpdateComponentOptions,
) -> Result<()> {
    app.liquid_glass().update_component(options)
}

#[command]
pub(crate) async fn update_components<R: Runtime>(
    app: AppHandle<R>,
    options: UpdateComponentsOptions,
) -> Result<()> {
    app.liquid_glass().update_components(options)
}

#[command]
pub(crate) async fn remove_component<R: Runtime>(
    app: AppHandle<R>,
    options: RemoveComponentOptions,
) -> Result<()> {
    app.liquid_glass().remove_component(options)
}

#[command]
pub(crate) async fn is_glass_supported<R: Runtime>(app: AppHandle<R>) -> Result<GlassSupport> {
    app.liquid_glass().is_glass_supported()
}

#[command]
pub(crate) async fn set_window_glass<R: Runtime>(
    window: WebviewWindow<R>,
    options: Option<WindowGlassOptions>,
) -> Result<()> {
    window
        .app_handle()
        .liquid_glass()
        .set_window_glass(window.clone(), options.unwrap_or_default())
}

#[command]
pub(crate) async fn clear_window_glass<R: Runtime>(window: WebviewWindow<R>) -> Result<()> {
    window
        .app_handle()
        .liquid_glass()
        .clear_window_glass(window.clone())
}
