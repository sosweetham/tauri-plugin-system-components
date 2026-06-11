use std::sync::{Arc, Mutex};

use serde::de::DeserializeOwned;
use tauri::{plugin::PluginApi, AppHandle, Manager, Runtime, WebviewWindow};

use crate::models::*;
use crate::Error;

pub fn init<R: Runtime, C: DeserializeOwned>(
    app: &AppHandle<R>,
    _api: PluginApi<R, C>,
) -> crate::Result<LiquidGlass<R>> {
    Ok(LiquidGlass {
        app: app.clone(),
        tab_ids: Arc::new(Mutex::new(Vec::new())),
    })
}

/// Access to the liquid-glass APIs on desktop.
///
/// macOS gets a real glass (or blur-fallback) window background plus a
/// native floating tab bar (NSSegmentedControl in a glass capsule — the same
/// control NSTabViewController uses for toolbar-style tabs). Windows/Linux
/// reject with `Unsupported`, which the JS side documents as the signal to
/// render an HTML tab bar.
pub struct LiquidGlass<R: Runtime> {
    app: AppHandle<R>,
    /// Tab ids by segment index — shared with the AppKit action callback.
    #[cfg_attr(not(target_os = "macos"), allow(dead_code))]
    tab_ids: Arc<Mutex<Vec<String>>>,
}

impl<R: Runtime> LiquidGlass<R> {
    #[cfg_attr(not(target_os = "macos"), allow(dead_code))]
    fn window(&self) -> crate::Result<WebviewWindow<R>> {
        self.app
            .get_webview_window("main")
            .or_else(|| self.app.webview_windows().into_values().next())
            .ok_or_else(|| Error::WindowHandle("no webview window".into()))
    }

    pub fn configure_tab_bar(&self, options: ConfigureTabBarOptions) -> crate::Result<()> {
        #[cfg(target_os = "macos")]
        {
            macos::configure_tab_bar(self.window()?, self.app.clone(), &self.tab_ids, options)
        }
        #[cfg(not(target_os = "macos"))]
        {
            let _ = options;
            Err(Error::Unsupported("the native tab bar is iOS/macOS-only"))
        }
    }

    pub fn remove_tab_bar(&self) -> crate::Result<()> {
        #[cfg(target_os = "macos")]
        {
            macos::remove_tab_bar(self.window()?, &self.tab_ids)
        }
        #[cfg(not(target_os = "macos"))]
        {
            Err(Error::Unsupported("the native tab bar is iOS/macOS-only"))
        }
    }

    pub fn show_tab_bar(&self) -> crate::Result<()> {
        #[cfg(target_os = "macos")]
        {
            macos::set_tab_bar_hidden(self.window()?, false)
        }
        #[cfg(not(target_os = "macos"))]
        {
            Err(Error::Unsupported("the native tab bar is iOS/macOS-only"))
        }
    }

    pub fn hide_tab_bar(&self) -> crate::Result<()> {
        #[cfg(target_os = "macos")]
        {
            macos::set_tab_bar_hidden(self.window()?, true)
        }
        #[cfg(not(target_os = "macos"))]
        {
            Err(Error::Unsupported("the native tab bar is iOS/macOS-only"))
        }
    }

    pub fn select_tab(&self, options: SelectTabOptions) -> crate::Result<()> {
        #[cfg(target_os = "macos")]
        {
            macos::select_tab(self.window()?, &self.tab_ids, options.id)
        }
        #[cfg(not(target_os = "macos"))]
        {
            let _ = options;
            Err(Error::Unsupported("the native tab bar is iOS/macOS-only"))
        }
    }

    pub fn set_badge(&self, _options: SetBadgeOptions) -> crate::Result<()> {
        // NSSegmentedControl has no badge concept; keep badges iOS-only.
        Err(Error::Unsupported("tab badges are iOS-only"))
    }

    pub fn get_tab_bar_insets(&self) -> crate::Result<TabBarInsets> {
        #[cfg(target_os = "macos")]
        {
            macos::tab_bar_insets(self.window()?)
        }
        #[cfg(not(target_os = "macos"))]
        {
            Err(Error::Unsupported("the native tab bar is iOS/macOS-only"))
        }
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
    use std::sync::{mpsc, Arc, Mutex};

    use objc2::rc::Retained;
    use objc2::runtime::{AnyClass, AnyObject, NSObject};
    use objc2::{define_class, msg_send, sel, AllocAnyThread, DefinedClass};
    use objc2_app_kit::{
        NSAutoresizingMaskOptions, NSColor, NSControlSize, NSImage, NSSegmentSwitchTracking,
        NSSegmentedControl, NSView, NSVisualEffectBlendingMode, NSVisualEffectMaterial,
        NSVisualEffectState, NSVisualEffectView, NSWindow, NSWindowOrderingMode,
    };
    use objc2_foundation::{MainThreadMarker, NSObjectProtocol, NSPoint, NSRect, NSSize, NSString};
    use tauri::{AppHandle, Emitter, Runtime, WebviewWindow};

    use crate::models::{
        ConfigureTabBarOptions, GlassSupport, TabBarInsets, TabSelectedPayload, WindowGlassOptions,
    };
    use crate::Error;

    /// `identifier` values used to find our views again across calls — keeps
    /// the commands idempotent without storing (non-Send) NSView handles in
    /// plugin state.
    const GLASS_VIEW_ID: &str = "tauri-plugin-liquid-glass.glass-view";
    const TAB_BAR_ID: &str = "tauri-plugin-liquid-glass.tab-bar";
    const TAB_CONTROL_ID: &str = "tauri-plugin-liquid-glass.tab-control";

    /// Event listened to by the JS `onTabSelected` helper (the desktop
    /// counterpart of the iOS plugin-event channel).
    const TAB_SELECTED_EVENT: &str = "liquid-glass://tab-selected";

    /// Gap between the floating capsule and the window's bottom edge.
    const BAR_BOTTOM_MARGIN: f64 = 20.0;
    /// Padding around the segmented control inside the capsule.
    const BAR_PADDING_X: f64 = 10.0;
    const BAR_PADDING_Y: f64 = 8.0;

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

    fn find_subview(root: &NSView, identifier: &str) -> Option<Retained<NSView>> {
        for sub in root.subviews().iter() {
            let id: Option<Retained<NSString>> = unsafe { msg_send![&*sub, identifier] };
            if id.is_some_and(|id| id.to_string() == identifier) {
                return Some(sub);
            }
            if let Some(found) = find_subview(&sub, identifier) {
                return Some(found);
            }
        }
        None
    }

    fn set_identifier(view: &NSView, identifier: &str) {
        let ident = NSString::from_str(identifier);
        let _: () = unsafe { msg_send![view, setIdentifier: &*ident] };
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

    // MARK: window glass

    pub fn set_window_glass<R: Runtime>(
        window: WebviewWindow<R>,
        options: WindowGlassOptions,
    ) -> crate::Result<()> {
        on_main_thread(&window, move |win| {
            let mtm = MainThreadMarker::new()
                .ok_or_else(|| Error::WindowHandle("not on main thread".into()))?;
            let content = content_view(win)?;

            // Idempotent: replace any glass view from a previous call.
            if let Some(existing) = find_subview(&content, GLASS_VIEW_ID) {
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
                set_identifier(&glass, GLASS_VIEW_ID);

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
                content.addSubview_positioned_relativeTo(&glass, NSWindowOrderingMode::Below, None);
            }
            Ok(())
        })
    }

    pub fn clear_window_glass<R: Runtime>(window: WebviewWindow<R>) -> crate::Result<()> {
        on_main_thread(&window, move |win| {
            let content = content_view(win)?;
            if let Some(existing) = find_subview(&content, GLASS_VIEW_ID) {
                existing.removeFromSuperview();
            }
            Ok(())
        })
    }

    // MARK: native tab bar (glass capsule + NSSegmentedControl)

    struct TabTargetIvars {
        on_select: Box<dyn Fn(isize)>,
    }

    define_class!(
        // SAFETY: NSObject has no subclassing requirements; the class is only
        // used as an NSControl target on the main thread.
        #[unsafe(super(NSObject))]
        #[name = "TauriLiquidGlassTabTarget"]
        #[ivars = TabTargetIvars]
        struct TabTarget;

        impl TabTarget {
            #[unsafe(method(segmentClicked:))]
            fn segment_clicked(&self, sender: &NSSegmentedControl) {
                let idx = sender.selectedSegment();
                (self.ivars().on_select)(idx);
            }
        }
    );

    impl TabTarget {
        fn new(on_select: Box<dyn Fn(isize)>) -> Retained<Self> {
            let this = Self::alloc().set_ivars(TabTargetIvars { on_select });
            unsafe { msg_send![super(this), init] }
        }
    }

    /// Key for associating the TabTarget with the control: NSControl.target
    /// is weak, so the association is what keeps the target alive.
    static TAB_TARGET_ASSOC_KEY: u8 = 0;

    pub fn configure_tab_bar<R: Runtime>(
        window: WebviewWindow<R>,
        app: AppHandle<R>,
        tab_ids: &Arc<Mutex<Vec<String>>>,
        options: ConfigureTabBarOptions,
    ) -> crate::Result<()> {
        if options.items.is_empty() {
            return Err(Error::WindowHandle(
                "configureTabBar requires at least one item".into(),
            ));
        }
        let ids: Vec<String> = options.items.iter().map(|i| i.id.clone()).collect();
        *tab_ids.lock().unwrap() = ids.clone();
        let ids_for_action = Arc::clone(tab_ids);

        on_main_thread(&window, move |win| {
            let mtm = MainThreadMarker::new()
                .ok_or_else(|| Error::WindowHandle("not on main thread".into()))?;
            let content = content_view(win)?;

            // Idempotent: rebuild from scratch on reconfigure.
            if let Some(existing) = find_subview(&content, TAB_BAR_ID) {
                existing.removeFromSuperview();
            }

            // The segmented control — the native macOS tab-switcher control
            // (NSTabViewController uses the same one in toolbar style).
            let control = NSSegmentedControl::new(mtm);
            let count = options.items.len() as isize;
            control.setSegmentCount(count);
            control.setTrackingMode(NSSegmentSwitchTracking::SelectOne);
            control.setControlSize(NSControlSize::Large);
            for (i, item) in options.items.iter().enumerate() {
                let idx = i as isize;
                control.setLabel_forSegment(&NSString::from_str(&item.title), idx);
                // SF Symbols exist on macOS 11+; nil just renders the label.
                let image = NSImage::imageWithSystemSymbolName_accessibilityDescription(
                    &NSString::from_str(&item.sf_symbol),
                    None,
                );
                control.setImage_forSegment(image.as_deref(), idx);
            }
            let selected = options
                .selected_id
                .as_deref()
                .and_then(|id| ids.iter().position(|i| i == id))
                .unwrap_or(0) as isize;
            control.setSelectedSegment(selected);

            // Wire taps → Tauri event. The target is kept alive by an
            // associated-object retain on the control (NSControl.target is weak).
            let target = TabTarget::new(Box::new(move |idx| {
                let ids = ids_for_action.lock().unwrap();
                if let Some(id) = ids.get(idx as usize) {
                    let _ = app.emit(TAB_SELECTED_EVENT, TabSelectedPayload { id: id.clone() });
                }
            }));
            unsafe {
                control.setTarget(Some(&target));
                control.setAction(Some(sel!(segmentClicked:)));
                objc2::ffi::objc_setAssociatedObject(
                    Retained::as_ptr(&control) as *mut _,
                    &TAB_TARGET_ASSOC_KEY as *const u8 as *const _,
                    Retained::as_ptr(&target) as *mut AnyObject,
                    objc2::ffi::OBJC_ASSOCIATION_RETAIN,
                );
            }
            control.sizeToFit();
            set_identifier(&control, TAB_CONTROL_ID);
            let control_size = control.frame().size;

            // The floating capsule container: real glass on macOS 26, blur
            // fallback otherwise.
            let bar_size = NSSize::new(
                control_size.width + BAR_PADDING_X * 2.0,
                control_size.height + BAR_PADDING_Y * 2.0,
            );
            let bounds = content.bounds();
            let bar_origin = NSPoint::new(
                (bounds.size.width - bar_size.width) / 2.0,
                BAR_BOTTOM_MARGIN,
            );
            let corner_radius = bar_size.height / 2.0;

            let bar: Retained<NSView> = match glass_class() {
                Some(cls) => {
                    let glass: Retained<NSView> = unsafe { msg_send![cls, new] };
                    unsafe {
                        if glass.respondsToSelector(sel!(setCornerRadius:)) {
                            let _: () = msg_send![&*glass, setCornerRadius: corner_radius];
                        }
                        // Wrapper so the control sits padded inside the glass.
                        let wrapper = NSView::new(mtm);
                        control.setFrameOrigin(NSPoint::new(BAR_PADDING_X, BAR_PADDING_Y));
                        wrapper.addSubview(&control);
                        if glass.respondsToSelector(sel!(setContentView:)) {
                            let _: () = msg_send![&*glass, setContentView: &*wrapper];
                        } else {
                            glass.addSubview(&wrapper);
                        }
                    }
                    glass
                }
                None => {
                    let effect = NSVisualEffectView::new(mtm);
                    effect.setMaterial(NSVisualEffectMaterial::HUDWindow);
                    effect.setBlendingMode(NSVisualEffectBlendingMode::WithinWindow);
                    effect.setState(NSVisualEffectState::Active);
                    unsafe {
                        effect.setWantsLayer(true);
                        let layer: *mut AnyObject = msg_send![&*effect, layer];
                        if !layer.is_null() {
                            let _: () = msg_send![layer, setCornerRadius: corner_radius];
                            let _: () = msg_send![layer, setMasksToBounds: true];
                        }
                        control.setFrameOrigin(NSPoint::new(BAR_PADDING_X, BAR_PADDING_Y));
                        effect.addSubview(&control);
                    }
                    Retained::into_super(effect)
                }
            };

            bar.setFrame(NSRect::new(bar_origin, bar_size));
            // Flexible left/right/top margins keep the capsule pinned to
            // the bottom center as the window resizes.
            bar.setAutoresizingMask(
                NSAutoresizingMaskOptions::ViewMinXMargin
                    | NSAutoresizingMaskOptions::ViewMaxXMargin
                    | NSAutoresizingMaskOptions::ViewMaxYMargin,
            );
            set_identifier(&bar, TAB_BAR_ID);

            // On top of the webview (addSubview appends above siblings).
            content.addSubview(&bar);
            Ok(())
        })
    }

    pub fn remove_tab_bar<R: Runtime>(
        window: WebviewWindow<R>,
        tab_ids: &Arc<Mutex<Vec<String>>>,
    ) -> crate::Result<()> {
        tab_ids.lock().unwrap().clear();
        on_main_thread(&window, move |win| {
            let content = content_view(win)?;
            if let Some(bar) = find_subview(&content, TAB_BAR_ID) {
                bar.removeFromSuperview();
            }
            Ok(())
        })
    }

    pub fn set_tab_bar_hidden<R: Runtime>(
        window: WebviewWindow<R>,
        hidden: bool,
    ) -> crate::Result<()> {
        on_main_thread(&window, move |win| {
            let content = content_view(win)?;
            let bar = find_subview(&content, TAB_BAR_ID)
                .ok_or_else(|| Error::WindowHandle("tab bar is not configured".into()))?;
            bar.setHidden(hidden);
            Ok(())
        })
    }

    pub fn select_tab<R: Runtime>(
        window: WebviewWindow<R>,
        tab_ids: &Arc<Mutex<Vec<String>>>,
        id: String,
    ) -> crate::Result<()> {
        let idx = tab_ids
            .lock()
            .unwrap()
            .iter()
            .position(|i| *i == id)
            .ok_or_else(|| Error::WindowHandle(format!("unknown tab id: {id}")))?
            as isize;
        on_main_thread(&window, move |win| {
            let content = content_view(win)?;
            let control = find_subview(&content, TAB_CONTROL_ID)
                .ok_or_else(|| Error::WindowHandle("tab bar is not configured".into()))?;
            let _: () = unsafe { msg_send![&*control, setSelectedSegment: idx] };
            Ok(())
        })
    }

    pub fn tab_bar_insets<R: Runtime>(window: WebviewWindow<R>) -> crate::Result<TabBarInsets> {
        on_main_thread(&window, move |win| {
            let content = content_view(win)?;
            let bottom = match find_subview(&content, TAB_BAR_ID) {
                Some(bar) if !bar.isHidden() => {
                    bar.frame().size.height + BAR_BOTTOM_MARGIN + 8.0
                }
                _ => 0.0,
            };
            Ok(TabBarInsets { bottom })
        })
    }
}
