use serde::de::DeserializeOwned;
use tauri::{plugin::PluginApi, AppHandle, Runtime, WebviewWindow};

use crate::models::*;
use crate::Error;

pub fn init<R: Runtime, C: DeserializeOwned>(
    app: &AppHandle<R>,
    _api: PluginApi<R, C>,
) -> crate::Result<LiquidGlass<R>> {
    Ok(LiquidGlass(app.clone()))
}

/// Access to the liquid-glass APIs on desktop.
///
/// macOS gets a real glass (or blur-fallback) window background; the native
/// tab bar is iOS-only, so those commands reject with `Unsupported` — the JS
/// side documents that rejection as the signal to render an HTML tab bar.
pub struct LiquidGlass<R: Runtime>(AppHandle<R>);

impl<R: Runtime> LiquidGlass<R> {
    pub fn configure_tab_bar(&self, _options: ConfigureTabBarOptions) -> crate::Result<()> {
        Err(Error::Unsupported("the native tab bar is iOS-only"))
    }

    pub fn remove_tab_bar(&self) -> crate::Result<()> {
        Err(Error::Unsupported("the native tab bar is iOS-only"))
    }

    pub fn show_tab_bar(&self) -> crate::Result<()> {
        Err(Error::Unsupported("the native tab bar is iOS-only"))
    }

    pub fn hide_tab_bar(&self) -> crate::Result<()> {
        Err(Error::Unsupported("the native tab bar is iOS-only"))
    }

    pub fn select_tab(&self, _options: SelectTabOptions) -> crate::Result<()> {
        Err(Error::Unsupported("the native tab bar is iOS-only"))
    }

    pub fn set_badge(&self, _options: SetBadgeOptions) -> crate::Result<()> {
        Err(Error::Unsupported("the native tab bar is iOS-only"))
    }

    pub fn get_tab_bar_insets(&self) -> crate::Result<TabBarInsets> {
        Err(Error::Unsupported("the native tab bar is iOS-only"))
    }

    pub fn is_glass_supported(&self) -> crate::Result<GlassSupport> {
        #[cfg(target_os = "macos")]
        {
            Ok(macos::glass_support())
        }
        #[cfg(not(target_os = "macos"))]
        {
            Ok(GlassSupport {
                supported: false,
                fallback: false,
            })
        }
    }

    pub fn set_window_glass(
        &self,
        window: WebviewWindow<R>,
        options: WindowGlassOptions,
    ) -> crate::Result<()> {
        #[cfg(target_os = "macos")]
        {
            macos::set_window_glass(window, options)
        }
        #[cfg(not(target_os = "macos"))]
        {
            let _ = (window, options);
            Err(Error::Unsupported("window glass is macOS-only"))
        }
    }

    pub fn clear_window_glass(&self, window: WebviewWindow<R>) -> crate::Result<()> {
        #[cfg(target_os = "macos")]
        {
            macos::clear_window_glass(window)
        }
        #[cfg(not(target_os = "macos"))]
        {
            let _ = window;
            Err(Error::Unsupported("window glass is macOS-only"))
        }
    }
}

#[cfg(target_os = "macos")]
mod macos {
    use std::sync::mpsc;

    use objc2::msg_send;
    use objc2::rc::Retained;
    use objc2::runtime::AnyClass;
    use objc2::sel;
    use objc2_app_kit::{
        NSAutoresizingMaskOptions, NSColor, NSView, NSVisualEffectBlendingMode,
        NSVisualEffectMaterial, NSVisualEffectState, NSVisualEffectView, NSWindow,
        NSWindowOrderingMode,
    };
    use objc2_foundation::{MainThreadMarker, NSObjectProtocol, NSString};
    use tauri::{Runtime, WebviewWindow};

    use crate::models::{GlassSupport, WindowGlassOptions};
    use crate::Error;

    /// `identifier` value used to find our view again across calls — keeps
    /// `set_window_glass` idempotent and powers `clear_window_glass` without
    /// having to store a (non-Send) NSView handle in plugin state.
    const GLASS_VIEW_ID: &str = "tauri-plugin-liquid-glass.glass-view";

    fn glass_class() -> Option<&'static AnyClass> {
        // Dynamic lookup: NSGlassEffectView only exists in the macOS 26 SDK /
        // runtime; resolving it by name keeps the crate buildable and runnable
        // against older toolchains and systems.
        AnyClass::get(c"NSGlassEffectView")
    }

    pub fn glass_support() -> GlassSupport {
        let supported = glass_class().is_some();
        GlassSupport {
            supported,
            fallback: !supported,
        }
    }

    /// Runs `f` on the main thread and waits for its result.
    fn on_main_thread<R, T, F>(window: &WebviewWindow<R>, f: F) -> crate::Result<T>
    where
        R: Runtime,
        T: Send + 'static,
        F: FnOnce(&WebviewWindow<R>) -> crate::Result<T> + Send + 'static,
    {
        let (tx, rx) = mpsc::channel();
        let win = window.clone();
        window
            .run_on_main_thread(move || {
                let _ = tx.send(f(&win));
            })
            .map_err(|e| Error::WindowHandle(e.to_string()))?;
        rx.recv()
            .map_err(|e| Error::WindowHandle(format!("main thread dropped result: {e}")))?
    }

    fn content_view<R: Runtime>(window: &WebviewWindow<R>) -> crate::Result<Retained<NSView>> {
        let ptr = window
            .ns_window()
            .map_err(|e| Error::WindowHandle(e.to_string()))?;
        let ns_window: &NSWindow = unsafe { &*ptr.cast::<NSWindow>() };
        ns_window
            .contentView()
            .ok_or_else(|| Error::WindowHandle("window has no contentView".into()))
    }

    fn find_glass_view(content: &NSView) -> Option<Retained<NSView>> {
        for sub in content.subviews().iter() {
            let id: Option<Retained<NSString>> = unsafe { msg_send![&*sub, identifier] };
            if id.is_some_and(|id| id.to_string() == GLASS_VIEW_ID) {
                return Some(sub);
            }
        }
        None
    }

    fn parse_hex_color(hex: &str) -> Option<(f64, f64, f64, f64)> {
        let hex = hex.trim_start_matches('#');
        let (r, g, b, a) = match hex.len() {
            6 => (&hex[0..2], &hex[2..4], &hex[4..6], "ff"),
            8 => (&hex[0..2], &hex[2..4], &hex[4..6], &hex[6..8]),
            _ => return None,
        };
        let p = |s: &str| u8::from_str_radix(s, 16).ok().map(|v| v as f64 / 255.0);
        Some((p(r)?, p(g)?, p(b)?, p(a)?))
    }

    pub fn set_window_glass<R: Runtime>(
        window: WebviewWindow<R>,
        options: WindowGlassOptions,
    ) -> crate::Result<()> {
        on_main_thread(&window, move |win| {
            let mtm = MainThreadMarker::new()
                .ok_or_else(|| Error::WindowHandle("not on main thread".into()))?;
            let content = content_view(win)?;

            // Idempotent: replace any glass view from a previous call.
            if let Some(existing) = find_glass_view(&content) {
                existing.removeFromSuperview();
            }

            let glass: Retained<NSView> = match glass_class() {
                Some(cls) => unsafe { msg_send![cls, new] },
                None => {
                    // Pre-macOS-26 fallback: behind-window blur.
                    let effect = NSVisualEffectView::new(mtm);
                    effect.setMaterial(NSVisualEffectMaterial::UnderWindowBackground);
                    effect.setBlendingMode(NSVisualEffectBlendingMode::BehindWindow);
                    effect.setState(NSVisualEffectState::FollowsWindowActiveState);
                    Retained::into_super(effect)
                }
            };

            glass.setFrame(content.bounds());
            unsafe {
                glass.setAutoresizingMask(
                    NSAutoresizingMaskOptions::ViewWidthSizable
                        | NSAutoresizingMaskOptions::ViewHeightSizable,
                );
                let ident = NSString::from_str(GLASS_VIEW_ID);
                let _: () = msg_send![&*glass, setIdentifier: &*ident];

                // macOS 26 NSGlassEffectView options; guarded so the
                // NSVisualEffectView fallback (or an SDK rename) degrades to
                // plain glass instead of crashing.
                if let Some(radius) = options.corner_radius {
                    if glass.respondsToSelector(sel!(setCornerRadius:)) {
                        let _: () = msg_send![&*glass, setCornerRadius: radius];
                    }
                }
                if let Some(tint) = options.tint_color.as_deref().and_then(parse_hex_color) {
                    if glass.respondsToSelector(sel!(setTintColor:)) {
                        let (r, g, b, a) = tint;
                        let color = NSColor::colorWithSRGBRed_green_blue_alpha(r, g, b, a);
                        let _: () = msg_send![&*glass, setTintColor: &*color];
                    }
                }

                // Below all siblings — i.e. behind the WKWebView, which must be
                // transparent (tauri.conf.json: window `transparent` +
                // `macOSPrivateApi`) for the glass to show through.
                content.addSubview_positioned_relativeTo(
                    &glass,
                    NSWindowOrderingMode::Below,
                    None,
                );
            }
            Ok(())
        })
    }

    pub fn clear_window_glass<R: Runtime>(window: WebviewWindow<R>) -> crate::Result<()> {
        on_main_thread(&window, move |win| {
            let content = content_view(win)?;
            if let Some(existing) = find_glass_view(&content) {
                existing.removeFromSuperview();
            }
            Ok(())
        })
    }
}
