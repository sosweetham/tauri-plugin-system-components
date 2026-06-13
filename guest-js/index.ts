import { invoke, addPluginListener } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';

/** A single tab in the native bottom tab bar. */
export interface TabItem {
  /** Stable identifier reported back in `tabSelected` events. */
  id: string;
  /** User-visible label under the icon. */
  title: string;
  /**
   * SF Symbol name (e.g. `house.fill`). Must exist on the device's OS
   * version; unknown names render a label-only item.
   */
  sfSymbol?: string;
  /**
   * Bitmap icon as base64 (raw or `data:` URL) — e.g. a user avatar.
   * Takes precedence over `sfSymbol`.
   */
  image?: string;
  /** Clip the bitmap `image` to a circle (avatar style). */
  circular?: boolean;
  /** Optional badge text (e.g. `"3"`). */
  badge?: string;
}

/**
 * A standalone account button floated beside the bar (Apple Music
 * search-button style). `image` (base64 / `data:` URL) wins over `sfSymbol`.
 */
export interface TabBarAccessory {
  /** Stable id reported back in `tabSelected` events when tapped. */
  id: string;
  sfSymbol?: string;
  image?: string;
}

export interface ConfigureTabBarOptions {
  items: TabItem[];
  /** Tab to select initially; defaults to the first item. */
  selectedId?: string;
  /**
   * Hex accent color `#RRGGBB[AA]` — selected-item color on iOS, glass
   * capsule tint + selected segment color on macOS.
   */
  tint?: string;
  /**
   * Optional circular account button beside the bar — iOS renders it as a
   * native tab-bar accessory (the bar shrinks to make room); taps arrive
   * through {@link onTabSelected} with this `id`. Ignored on macOS.
   */
  accessory?: TabBarAccessory;
}

/** Space the web content should reserve so the floating bar doesn't cover it. */
export interface TabBarInsets {
  /** Bar height + bottom safe area, in CSS points. */
  bottom: number;
}

/** Kind of native overlay component. */
export type ComponentKind =
  | 'switch'
  | 'button'
  | 'slider'
  | 'progress'
  | 'image'
  | 'glass'
  /** A layout container (stack) arranging its `children` along `props.axis` —
   * compose your own nav (bar or sidebar) from it; imposes no layout. */
  | 'container'
  /** The system tab bar as a component: `props.items` are the tabs; selection
   * arrives as a `select` event whose `detail` is the chosen tab id. */
  | 'tabBar';

/** Where a component is pinned, relative to the window/safe area. */
export type ComponentAnchor =
  | 'topLeading'
  | 'topTrailing'
  | 'bottomLeading'
  | 'bottomTrailing'
  | 'center'
  /** Centered against one safe-area edge — for docking a nav container as a
   * bottom bar or a side rail. `props.inset` sets the gap from the edge. */
  | 'bottom'
  | 'top'
  | 'leading'
  | 'trailing'
  /** Position by `props.x`/`props.y` (CSS points from the top-left). */
  | 'absolute'
  /** Cover the whole window, resizing with it. */
  | 'fill';

/** Per-kind properties. All optional; irrelevant fields are ignored. */
export interface ComponentProps {
  /** Button title / accessibility label. */
  label?: string;
  /** Switch state. */
  on?: boolean;
  /** Slider/progress value (progress is 0..1 by default). */
  value?: number;
  min?: number;
  max?: number;
  /** SF Symbol for buttons. */
  sfSymbol?: string;
  /** Bitmap as base64 (raw or `data:` URL) — image components, button icons. */
  image?: string;
  /** Clip the bitmap to a circle (avatar style). */
  circular?: boolean;
  /** Wrap the control in a floating glass capsule. */
  glass?: boolean;
  /** Prominent (tinted) button style. */
  prominent?: boolean;
  /** Hex tint color `#RRGGBB[AA]`. */
  tint?: string;
  /** Explicit size in points (defaults to the control's natural size). */
  width?: number;
  height?: number;
  /**
   * Top-left position in CSS points, for `absolute` placement. Also
   * accepted by {@link updateComponent} to move/resize (DOM scroll sync).
   */
  x?: number;
  y?: number;
  /** Corner radius for `glass` panels. */
  cornerRadius?: number;

  // ── `container` layout ──────────────────────────────────────────────────
  /** `horizontal` (a bar) or `vertical` (a sidebar). Default `horizontal`. */
  axis?: 'horizontal' | 'vertical';
  /** Cross-axis alignment of children. Default `center`. */
  align?: 'center' | 'leading' | 'trailing' | 'fill';
  /** Gap between children, in points. */
  spacing?: number;
  /** Gap from the anchored safe-area edge, in points. */
  inset?: number;

  // ── `tabBar` ────────────────────────────────────────────────────────────
  /** The tabs, when `kind === 'tabBar'`. */
  items?: TabItem[];
  /** Initially-selected tab id (defaults to the first). */
  selectedId?: string;
}

export interface CreateComponentOptions {
  /** Stable identifier, reported back in component events. */
  id: string;
  kind: ComponentKind;
  props?: ComponentProps;
  /** Defaults to `topTrailing`. */
  anchor?: ComponentAnchor;
  /** Offset from the anchor, in points (grows inward). */
  dx?: number;
  dy?: number;
  /**
   * Insert the view *below* the webview instead of above it. The webview is
   * made transparent so unpainted DOM regions reveal the view (e.g. a
   * full-window `fill` backdrop image behind the page).
   */
  below?: boolean;
  /** Child components, when `kind === 'container'` — arranged along
   * `props.axis`. Each child is a full spec, so containers nest and a
   * `tabBar`/`button` can live inside. */
  children?: CreateComponentOptions[];
}

export interface ComponentEvent {
  id: string;
  /** `click` (button), `change` (switch/slider), or `select` (tab bar). */
  event: 'click' | 'change' | 'select';
  /** Switch state, on `change` events from switches. */
  on?: boolean;
  /** Slider value, on `change` events from sliders. */
  value?: number;
  /** The chosen tab id, on `select` events from a `tabBar`. */
  detail?: string;
}

export interface WindowGlassOptions {
  cornerRadius?: number;
  /** Hex color, `#RRGGBB` or `#RRGGBBAA`. */
  tintColor?: string;
}

export interface GlassSupport {
  /** `true` when the real `NSGlassEffectView` (macOS 26+) is available. */
  supported: boolean;
  /**
   * `true` when `setWindowGlass` would use the `NSVisualEffectView` blur
   * fallback instead of real glass.
   */
  fallback: boolean;
}

export interface TabSelectedEvent {
  id: string;
}

/** Subscription handle returned by {@link onTabSelected}. */
export interface TabSelectedListener {
  unregister(): Promise<void>;
}

/**
 * Mounts (or reconfigures) the native tab bar over the webview.
 *
 * **iOS and macOS** — rejects on Windows/Linux/Android. That rejection is
 * the supported way to detect the platform: catch it and render an HTML tab
 * bar instead.
 *
 * - iOS: a real `UITabBar`. On iOS 26+ (app built with Xcode 26) it's
 *   Liquid Glass and refracts the web content behind it; older versions get
 *   the classic translucent bar.
 * - macOS: an `NSSegmentedControl` (the native tab-switcher control) inside
 *   a floating `NSGlassEffectView` capsule on macOS 26, blur capsule on
 *   older systems.
 *
 * Idempotent: calling again updates the existing bar in place.
 */
export async function configureTabBar(
  options: ConfigureTabBarOptions,
): Promise<void> {
  await invoke('plugin:system-components|configure_tab_bar', { options });
}

/** Unmounts the native tab bar. iOS/macOS. */
export async function removeTabBar(): Promise<void> {
  await invoke('plugin:system-components|remove_tab_bar');
}

/** Shows a previously hidden tab bar. iOS/macOS. */
export async function showTabBar(): Promise<void> {
  await invoke('plugin:system-components|show_tab_bar');
}

/** Hides the tab bar without unmounting it. iOS/macOS. */
export async function hideTabBar(): Promise<void> {
  await invoke('plugin:system-components|hide_tab_bar');
}

/**
 * Programmatically selects a tab. Does **not** emit a `tabSelected` event
 * (matching AppKit/UIKit, which only report user interaction). iOS/macOS.
 */
export async function selectTab(id: string): Promise<void> {
  await invoke('plugin:system-components|select_tab', { options: { id } });
}

/**
 * Sets (or clears, when `value` is omitted) a tab's badge. iOS only —
 * NSSegmentedControl has no badge concept, so this rejects on macOS.
 */
export async function setBadge(id: string, value?: string): Promise<void> {
  await invoke('plugin:system-components|set_badge', { options: { id, value } });
}

/**
 * Height of the region the bar occludes at the bottom of the window, in CSS
 * points — pad your page's bottom by this so content can scroll clear of the
 * floating bar. iOS/macOS.
 */
export async function getTabBarInsets(): Promise<TabBarInsets> {
  return await invoke('plugin:system-components|get_tab_bar_insets');
}

/**
 * Listens for user taps on the native tab bar. Drive your page switching
 * from this. iOS/macOS (never fires elsewhere).
 *
 * Internally this subscribes to both transports — the mobile plugin event
 * channel (iOS) and the `system-components://tab-selected` Tauri event (macOS);
 * only the platform-active one ever fires.
 */
export async function onTabSelected(
  handler: (event: TabSelectedEvent) => void,
): Promise<TabSelectedListener> {
  const unlistenEvent = await listen<TabSelectedEvent>(
    'system-components://tab-selected',
    (event) => handler(event.payload),
  );
  // register_listener only exists on the mobile plugin; rejects on desktop.
  const pluginListener = await addPluginListener<TabSelectedEvent>(
    'system-components',
    'tabSelected',
    handler,
  ).catch(() => null);
  return {
    async unregister() {
      unlistenEvent();
      await pluginListener?.unregister();
    },
  };
}

/** An option for a `select` row. */
export interface SheetSelectOption {
  value: string;
  label: string;
}

/** One natively-rendered row in a native sheet (iOS). */
export interface SheetRow {
  /** Stable id reported in events. */
  id: string;
  /**
   * `header` (identity), `action` (tappable → `sheetRow`), `text` (paragraph),
   * `textfield`, `toggle`, `datetime`, `select`, `submit` (→ `sheetSubmit`).
   * Defaults to `action`.
   */
  kind?: 'header' | 'action' | 'text' | 'textfield' | 'toggle' | 'datetime' | 'select' | 'submit';
  label: string;
  /** Secondary line. */
  detail?: string;
  /** Bitmap (base64 / `data:` URL) — e.g. the avatar. Wins over `sfSymbol`. */
  image?: string;
  sfSymbol?: string;
  /** Trailing badge text (e.g. a count). */
  badge?: string;
  /** Render in the destructive (red) style. */
  destructive?: boolean;
  /** Back-compat shorthand for `kind: 'header'`. */
  header?: boolean;
  /** Initial value: `textfield` text / `datetime` ISO-8601 / `select` value. */
  value?: string;
  /** Initial `toggle` state. */
  on?: boolean;
  placeholder?: string;
  /** `select` options. */
  options?: SheetSelectOption[];
}

export interface PresentSheetOptions {
  /** Stable id reported in `sheetRow` / `sheetDismissed` events. */
  id: string;
  /** Hex accent `#RRGGBB[AA]` for badges. */
  tint?: string;
  rows: SheetRow[];
}

export interface SheetRowEvent {
  sheetId: string;
  rowId: string;
}

export interface SheetDismissedEvent {
  sheetId: string;
}

/** A form field's value changed. */
export interface SheetFieldEvent {
  sheetId: string;
  rowId: string;
  /** New value (toggle: `"true"`/`"false"`; datetime: ISO-8601; select: value). */
  value: string;
}

/** A `submit` row was tapped, carrying all current field values. */
export interface SheetSubmitEvent {
  sheetId: string;
  rowId: string;
  /** JSON object string of `{ rowId: value }` for every form row. */
  values: string;
}

/**
 * Presents a native Liquid Glass bottom sheet (iOS) — real detents, grabber,
 * drag-to-dismiss — whose rows are rendered natively from `rows`. Rejects on
 * macOS/Windows/Linux (use an HTML sheet there). Row taps arrive through
 * {@link onSheetRow}; user dismissal through {@link onSheetDismissed}.
 */
export async function presentSheet(options: PresentSheetOptions): Promise<void> {
  await invoke('plugin:system-components|present_sheet', { options });
}

/** Dismisses a sheet by id. iOS. */
export async function dismissSheet(id: string): Promise<void> {
  await invoke('plugin:system-components|dismiss_sheet', { options: { id } });
}

/** Listens for taps on a native sheet's rows. */
export async function onSheetRow(
  handler: (event: SheetRowEvent) => void,
): Promise<TabSelectedListener> {
  const unlistenEvent = await listen<SheetRowEvent>(
    'system-components://sheet-row',
    (event) => handler(event.payload),
  );
  const pluginListener = await addPluginListener<SheetRowEvent>(
    'system-components',
    'sheetRow',
    handler,
  ).catch(() => null);
  return {
    async unregister() {
      unlistenEvent();
      await pluginListener?.unregister();
    },
  };
}

/** Listens for user dismissal (swipe / tap-away) of a native sheet. */
export async function onSheetDismissed(
  handler: (event: SheetDismissedEvent) => void,
): Promise<TabSelectedListener> {
  const unlistenEvent = await listen<SheetDismissedEvent>(
    'system-components://sheet-dismissed',
    (event) => handler(event.payload),
  );
  const pluginListener = await addPluginListener<SheetDismissedEvent>(
    'system-components',
    'sheetDismissed',
    handler,
  ).catch(() => null);
  return {
    async unregister() {
      unlistenEvent();
      await pluginListener?.unregister();
    },
  };
}

/** Listens for form-field value changes in a native sheet. */
export async function onSheetField(
  handler: (event: SheetFieldEvent) => void,
): Promise<TabSelectedListener> {
  const unlistenEvent = await listen<SheetFieldEvent>(
    'system-components://sheet-field',
    (event) => handler(event.payload),
  );
  const pluginListener = await addPluginListener<SheetFieldEvent>(
    'system-components',
    'sheetField',
    handler,
  ).catch(() => null);
  return {
    async unregister() {
      unlistenEvent();
      await pluginListener?.unregister();
    },
  };
}

/** Listens for a `submit` row tap (carries all field values as a JSON string). */
export async function onSheetSubmit(
  handler: (event: SheetSubmitEvent) => void,
): Promise<TabSelectedListener> {
  const unlistenEvent = await listen<SheetSubmitEvent>(
    'system-components://sheet-submit',
    (event) => handler(event.payload),
  );
  const pluginListener = await addPluginListener<SheetSubmitEvent>(
    'system-components',
    'sheetSubmit',
    handler,
  ).catch(() => null);
  return {
    async unregister() {
      unlistenEvent();
      await pluginListener?.unregister();
    },
  };
}

/**
 * Creates (or replaces, by `id`) a native overlay component floating over
 * the webview: switch, button, slider, progress bar, or image view (e.g. a
 * user avatar). iOS and macOS — rejects on Windows/Linux/Android.
 *
 * Interactive components report through {@link onComponentEvent}. Pass
 * `props.glass: true` to float the control in a glass capsule (real glass
 * on iOS 26 / macOS 26, material blur before that).
 */
export async function createComponent(
  options: CreateComponentOptions,
): Promise<void> {
  await invoke('plugin:system-components|create_component', { options });
}

/** Updates a component's props (state, value, label, image). iOS/macOS. */
export async function updateComponent(
  id: string,
  props: ComponentProps,
): Promise<void> {
  await invoke('plugin:system-components|update_component', {
    options: { id, props },
  });
}

/**
 * Batched {@link updateComponent}: one IPC round trip and one
 * animation-disabled native transaction for all entries. Unknown ids are
 * skipped. Use this for per-frame geometry sync.
 */
export async function updateComponents(
  components: Array<{ id: string; props: ComponentProps }>,
): Promise<void> {
  await invoke('plugin:system-components|update_components', {
    options: { components },
  });
}

/** Removes a component created with {@link createComponent}. iOS/macOS. */
export async function removeComponent(id: string): Promise<void> {
  await invoke('plugin:system-components|remove_component', { options: { id } });
}

/**
 * Listens for interaction with native components: button `click`s and
 * switch/slider `change`s. Same dual-transport mechanism as
 * {@link onTabSelected}.
 */
export async function onComponentEvent(
  handler: (event: ComponentEvent) => void,
): Promise<TabSelectedListener> {
  const unlistenEvent = await listen<ComponentEvent>(
    'system-components://component-event',
    (event) => handler(event.payload),
  );
  const pluginListener = await addPluginListener<ComponentEvent>(
    'system-components',
    'componentEvent',
    handler,
  ).catch(() => null);
  return {
    async unregister() {
      unlistenEvent();
      await pluginListener?.unregister();
    },
  };
}

/**
 * Reports whether the real `NSGlassEffectView` (macOS 26+) is available,
 * or whether {@link setWindowGlass} would fall back to a blur. Resolves
 * `{ supported: false, fallback: false }` on iOS/Windows/Linux.
 */
export async function isGlassSupported(): Promise<GlassSupport> {
  return await invoke('plugin:system-components|is_glass_supported');
}

/**
 * Installs a glass view behind the webview of the current window.
 *
 * **macOS only** — rejects everywhere else. Requires the window to be
 * `transparent: true` and `app.macOSPrivateApi: true` in tauri.conf.json so
 * the webview lets the glass show through; the page must also leave the
 * regions where glass should appear unpainted (transparent body/elements).
 * Idempotent: calling again replaces the previous glass view.
 */
export async function setWindowGlass(
  options?: WindowGlassOptions,
): Promise<void> {
  await invoke('plugin:system-components|set_window_glass', { options });
}

/** Removes the glass view installed by {@link setWindowGlass}. macOS only. */
export async function clearWindowGlass(): Promise<void> {
  await invoke('plugin:system-components|clear_window_glass');
}
