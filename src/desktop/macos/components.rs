//! Generic native overlay components: switch, button, slider, progress and
//! image views floated over the webview, optionally inside a glass capsule.
//! Interactive controls report through the `liquid-glass://component-event`
//! Tauri event (the desktop counterpart of the iOS plugin-event channel).

use objc2::rc::Retained;
use objc2::{msg_send, sel};
use objc2_app_kit::{
    NSAutoresizingMaskOptions, NSBezelStyle, NSButton, NSColor, NSImage, NSImageScaling,
    NSImageView, NSProgressIndicator, NSProgressIndicatorStyle, NSSlider, NSSwitch,
    NSVisualEffectBlendingMode, NSVisualEffectMaterial, NSVisualEffectState, NSVisualEffectView,
    NSView, NSWindowOrderingMode,
};
use objc2_foundation::{MainThreadMarker, NSObjectProtocol, NSPoint, NSRect, NSSize, NSString};
use tauri::{AppHandle, Emitter, Runtime, WebviewWindow};

use super::{
    attach_target, circular_image, content_view, find_subview, find_webview, glass_capsule,
    glass_class, image_from_base64, on_main_thread, parse_hex_color, set_identifier, ActionTarget,
    ID_PREFIX,
};
use crate::models::{
    ComponentAnchor, ComponentEventPayload, ComponentKind, ComponentProps, CreateComponentOptions,
    UpdateComponentOptions,
};
use crate::Error;

const COMPONENT_EVENT: &str = "liquid-glass://component-event";

/// Margin between anchored components and the window edge / safe area.
const EDGE_MARGIN: f64 = 16.0;
const CAPSULE_PADDING_X: f64 = 10.0;
const CAPSULE_PADDING_Y: f64 = 8.0;

fn container_id(id: &str) -> String {
    format!("{ID_PREFIX}component.{id}")
}
fn inner_id(id: &str) -> String {
    format!("{ID_PREFIX}component.{id}.control")
}

fn decode_image(props: &ComponentProps, side: f64) -> Option<Retained<NSImage>> {
    let img = props.image.as_deref().and_then(image_from_base64)?;
    Some(if props.circular.unwrap_or(false) {
        circular_image(&img, side)
    } else {
        img
    })
}

fn emit_event<R: Runtime>(app: &AppHandle<R>, payload: ComponentEventPayload) {
    let _ = app.emit(COMPONENT_EVENT, payload);
}

pub fn create<R: Runtime>(
    window: WebviewWindow<R>,
    app: AppHandle<R>,
    options: CreateComponentOptions,
) -> crate::Result<()> {
    on_main_thread(&window, move |win| {
        let mtm = MainThreadMarker::new()
            .ok_or_else(|| Error::WindowHandle("not on main thread".into()))?;
        let content = content_view(win)?;

        // Idempotent: re-creating an id replaces it.
        if let Some(existing) = find_subview(&content, &container_id(&options.id)) {
            existing.removeFromSuperview();
        }

        let props = &options.props;
        let id = options.id.clone();

        let control: Retained<NSView> = match options.kind {
            ComponentKind::Switch => {
                let control = NSSwitch::new(mtm);
                unsafe {
                    let _: () =
                        msg_send![&*control, setState: if props.on.unwrap_or(false) { 1isize } else { 0 }];
                }
                let app = app.clone();
                let event_id = id.clone();
                attach_target(
                    &control,
                    &ActionTarget::new(Box::new(move |sender| {
                        let state: isize = unsafe { msg_send![sender, state] };
                        emit_event(
                            &app,
                            ComponentEventPayload {
                                id: event_id.clone(),
                                event: "change".into(),
                                on: Some(state == 1),
                                value: None,
                            },
                        );
                    })),
                );
                control.sizeToFit();
                Retained::into_super(Retained::into_super(control))
            }
            ComponentKind::Button => {
                let control = NSButton::new(mtm);
                control.setBezelStyle(NSBezelStyle::Push);
                if let Some(label) = &props.label {
                    control.setTitle(&NSString::from_str(label));
                }
                let image = decode_image(props, 18.0).or_else(|| {
                    props.sf_symbol.as_deref().and_then(|name| {
                        NSImage::imageWithSystemSymbolName_accessibilityDescription(
                            &NSString::from_str(name),
                            None,
                        )
                    })
                });
                if let Some(image) = image {
                    control.setImage(Some(&image));
                }
                if props.prominent.unwrap_or(false) {
                    let (r, g, b, a) = props
                        .tint
                        .as_deref()
                        .and_then(parse_hex_color)
                        .unwrap_or((0.0, 0.48, 1.0, 1.0));
                    control.setBezelColor(Some(&NSColor::colorWithSRGBRed_green_blue_alpha(
                        r, g, b, a,
                    )));
                }
                let app = app.clone();
                let event_id = id.clone();
                attach_target(
                    &control,
                    &ActionTarget::new(Box::new(move |_| {
                        emit_event(
                            &app,
                            ComponentEventPayload {
                                id: event_id.clone(),
                                event: "click".into(),
                                on: None,
                                value: None,
                            },
                        );
                    })),
                );
                control.sizeToFit();
                Retained::into_super(Retained::into_super(control))
            }
            ComponentKind::Slider => {
                let control = NSSlider::new(mtm);
                control.setMinValue(props.min.unwrap_or(0.0));
                control.setMaxValue(props.max.unwrap_or(1.0));
                control.setContinuous(true);
                control.setDoubleValue(props.value.unwrap_or(0.0));
                let app = app.clone();
                let event_id = id.clone();
                attach_target(
                    &control,
                    &ActionTarget::new(Box::new(move |sender| {
                        let value: f64 = unsafe { msg_send![sender, doubleValue] };
                        emit_event(
                            &app,
                            ComponentEventPayload {
                                id: event_id.clone(),
                                event: "change".into(),
                                on: None,
                                value: Some(value),
                            },
                        );
                    })),
                );
                control.sizeToFit();
                let mut frame = control.frame();
                frame.size.width = props.width.unwrap_or(160.0);
                control.setFrame(frame);
                Retained::into_super(Retained::into_super(control))
            }
            ComponentKind::Progress => {
                let control = NSProgressIndicator::new(mtm);
                control.setStyle(NSProgressIndicatorStyle::Bar);
                control.setIndeterminate(false);
                control.setMinValue(props.min.unwrap_or(0.0));
                control.setMaxValue(props.max.unwrap_or(1.0));
                control.setDoubleValue(props.value.unwrap_or(0.0));
                control.sizeToFit();
                let mut frame = control.frame();
                frame.size.width = props.width.unwrap_or(160.0);
                control.setFrame(frame);
                Retained::into_super(control)
            }
            ComponentKind::Image => {
                let side = props.width.or(props.height).unwrap_or(48.0);
                let view = NSImageView::new(mtm);
                if let Some(image) = decode_image(props, side) {
                    view.setImage(Some(&image));
                }
                view.setImageScaling(NSImageScaling::ScaleAxesIndependently);
                view.setFrameSize(NSSize::new(
                    props.width.unwrap_or(side),
                    props.height.unwrap_or(side),
                ));
                Retained::into_super(Retained::into_super(view))
            }
            ComponentKind::Glass => {
                let radius = props.corner_radius.unwrap_or(18.0);
                let view: Retained<NSView> = match glass_class() {
                    Some(cls) => {
                        let glass: Retained<NSView> = unsafe { msg_send![cls, new] };
                        unsafe {
                            if glass.respondsToSelector(sel!(setCornerRadius:)) {
                                let _: () = msg_send![&*glass, setCornerRadius: radius];
                            }
                            if let Some((r, g, b, a)) =
                                props.tint.as_deref().and_then(parse_hex_color)
                            {
                                if glass.respondsToSelector(sel!(setTintColor:)) {
                                    let color =
                                        NSColor::colorWithSRGBRed_green_blue_alpha(r, g, b, a);
                                    let _: () = msg_send![&*glass, setTintColor: &*color];
                                }
                            }
                        }
                        glass
                    }
                    None => {
                        let effect = NSVisualEffectView::new(mtm);
                        effect.setMaterial(NSVisualEffectMaterial::HUDWindow);
                        effect.setBlendingMode(NSVisualEffectBlendingMode::BehindWindow);
                        effect.setState(NSVisualEffectState::Active);
                        unsafe {
                            effect.setWantsLayer(true);
                            let layer: *mut objc2::runtime::AnyObject =
                                msg_send![&*effect, layer];
                            if !layer.is_null() {
                                let _: () = msg_send![layer, setCornerRadius: radius];
                                let _: () = msg_send![layer, setMasksToBounds: true];
                            }
                        }
                        Retained::into_super(effect)
                    }
                };
                view.setFrameSize(NSSize::new(
                    props.width.unwrap_or(200.0),
                    props.height.unwrap_or(120.0),
                ));
                view
            }
        };

        // Explicit size overrides.
        let mut frame = control.frame();
        if let Some(w) = props.width {
            frame.size.width = w;
        }
        if let Some(h) = props.height {
            frame.size.height = h;
        }
        control.setFrame(frame);
        set_identifier(&control, &inner_id(&id));
        let control_size = control.frame().size;

        // Container: glass capsule or a plain transparent holder.
        let container: Retained<NSView> = if props.glass.unwrap_or(false) {
            control.setFrameOrigin(NSPoint::new(CAPSULE_PADDING_X, CAPSULE_PADDING_Y));
            let size = NSSize::new(
                control_size.width + CAPSULE_PADDING_X * 2.0,
                control_size.height + CAPSULE_PADDING_Y * 2.0,
            );
            let capsule = glass_capsule(mtm, &control, size.height / 2.0);
            capsule.setFrameSize(size);
            capsule
        } else {
            let holder = NSView::new(mtm);
            holder.setFrameSize(control_size);
            control.setFrameOrigin(NSPoint::new(0.0, 0.0));
            // Track the holder when it's resized (DOM-synced glass panels).
            control.setAutoresizingMask(
                NSAutoresizingMaskOptions::ViewWidthSizable
                    | NSAutoresizingMaskOptions::ViewHeightSizable,
            );
            holder.addSubview(&control);
            holder
        };
        set_identifier(&container, &container_id(&id));

        // Anchor placement (AppKit coordinates: y grows upward).
        let bounds = content.bounds();
        let (bw, bh) = (bounds.size.width, bounds.size.height);
        let mut size = container.frame().size;
        let (w, h) = (size.width, size.height);
        let (x, y, mask) = match options.anchor {
            ComponentAnchor::TopLeading => (
                EDGE_MARGIN + options.dx,
                bh - h - EDGE_MARGIN - options.dy,
                NSAutoresizingMaskOptions::ViewMinYMargin
                    | NSAutoresizingMaskOptions::ViewMaxXMargin,
            ),
            ComponentAnchor::TopTrailing => (
                bw - w - EDGE_MARGIN - options.dx,
                bh - h - EDGE_MARGIN - options.dy,
                NSAutoresizingMaskOptions::ViewMinYMargin
                    | NSAutoresizingMaskOptions::ViewMinXMargin,
            ),
            ComponentAnchor::BottomLeading => (
                EDGE_MARGIN + options.dx,
                EDGE_MARGIN + options.dy,
                NSAutoresizingMaskOptions::ViewMaxYMargin
                    | NSAutoresizingMaskOptions::ViewMaxXMargin,
            ),
            ComponentAnchor::BottomTrailing => (
                bw - w - EDGE_MARGIN - options.dx,
                EDGE_MARGIN + options.dy,
                NSAutoresizingMaskOptions::ViewMaxYMargin
                    | NSAutoresizingMaskOptions::ViewMinXMargin,
            ),
            ComponentAnchor::Center => (
                (bw - w) / 2.0 + options.dx,
                (bh - h) / 2.0 - options.dy,
                NSAutoresizingMaskOptions::ViewMinXMargin
                    | NSAutoresizingMaskOptions::ViewMaxXMargin
                    | NSAutoresizingMaskOptions::ViewMinYMargin
                    | NSAutoresizingMaskOptions::ViewMaxYMargin,
            ),
            // CSS coordinates: y from the top, so flip into AppKit space.
            ComponentAnchor::Absolute => (
                props.x.unwrap_or(0.0),
                bh - props.y.unwrap_or(0.0) - h,
                NSAutoresizingMaskOptions::ViewMinYMargin,
            ),
            ComponentAnchor::Fill => {
                size = bounds.size;
                (
                    0.0,
                    0.0,
                    NSAutoresizingMaskOptions::ViewWidthSizable
                        | NSAutoresizingMaskOptions::ViewHeightSizable,
                )
            }
        };
        container.setFrame(NSRect::new(NSPoint::new(x, y), size));
        container.setAutoresizingMask(mask);

        if options.below {
            // Just under the webview: above previously-inserted below-views
            // (e.g. a fill background), refracting them; DOM content renders
            // sharp on top through the transparent webview.
            let webview = find_webview(&content);
            content.addSubview_positioned_relativeTo(
                &container,
                NSWindowOrderingMode::Below,
                webview.as_deref(),
            );
        } else {
            content.addSubview(&container);
        }
        Ok(())
    })
}

pub fn update<R: Runtime>(
    window: WebviewWindow<R>,
    options: UpdateComponentOptions,
) -> crate::Result<()> {
    on_main_thread(&window, move |win| {
        let content = content_view(win)?;
        let control = find_subview(&content, &inner_id(&options.id))
            .ok_or_else(|| Error::WindowHandle(format!("unknown component: {}", options.id)))?;
        let props = &options.props;

        // Geometry updates (DOM scroll/resize sync) move the container.
        if props.x.is_some() || props.y.is_some() || props.width.is_some() || props.height.is_some()
        {
            if let Some(container) = find_subview(&content, &container_id(&options.id)) {
                let bh = unsafe { container.superview() }
                    .map(|s| s.bounds().size.height)
                    .unwrap_or(0.0);
                let mut frame = container.frame();
                if let Some(w) = props.width {
                    frame.size.width = w;
                }
                if let Some(h) = props.height {
                    frame.size.height = h;
                }
                if let Some(x) = props.x {
                    frame.origin.x = x;
                }
                if let Some(y) = props.y {
                    frame.origin.y = bh - y - frame.size.height;
                }
                container.setFrame(frame);
            }
        }
        unsafe {
            if let Some(on) = props.on {
                let _: () = msg_send![&*control, setState: if on { 1isize } else { 0 }];
            }
            if let Some(value) = props.value {
                let _: () = msg_send![&*control, setDoubleValue: value];
            }
            if let Some(label) = &props.label {
                let _: () = msg_send![&*control, setTitle: &*NSString::from_str(label)];
            }
            if props.image.is_some() {
                let side = control.frame().size.height;
                if let Some(image) = decode_image(props, side) {
                    let _: () = msg_send![&*control, setImage: &*image];
                }
            }
        }
        Ok(())
    })
}

pub fn remove<R: Runtime>(window: WebviewWindow<R>, id: String) -> crate::Result<()> {
    on_main_thread(&window, move |win| {
        let content = content_view(win)?;
        if let Some(container) = find_subview(&content, &container_id(&id)) {
            container.removeFromSuperview();
        }
        Ok(())
    })
}
