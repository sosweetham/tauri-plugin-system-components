import {
  invoke,
  addPluginListener,
  type PluginListener,
} from '@tauri-apps/api/core';

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
  sfSymbol: string;
  /** Optional badge text (e.g. `"3"`). */
  badge?: string;
}

export interface ConfigureTabBarOptions {
  items: TabItem[];
  /** Tab to select initially; defaults to the first item. */
  selectedId?: string;
}

/** Space the web content should reserve so the floating bar doesn't cover it. */
export interface TabBarInsets {
  /** Bar height + bottom safe area, in CSS points. */
  bottom: number;
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

/**
 * Mounts (or reconfigures) the native bottom tab bar over the webview.
 *
 * **iOS only** — rejects everywhere else. That rejection is the supported
 * way to detect the platform: catch it and render an HTML tab bar instead.
 *
 * On iOS 26+ (app built with Xcode 26) the bar is Liquid Glass and refracts
 * the web content behind it; older versions get the classic translucent bar.
 * Idempotent: calling again updates the existing bar in place.
 */
export async function configureTabBar(
  options: ConfigureTabBarOptions,
): Promise<void> {
  await invoke('plugin:liquid-glass|configure_tab_bar', { options });
}

/** Unmounts the native tab bar. iOS only. */
export async function removeTabBar(): Promise<void> {
  await invoke('plugin:liquid-glass|remove_tab_bar');
}

/** Shows a previously hidden tab bar. iOS only. */
export async function showTabBar(): Promise<void> {
  await invoke('plugin:liquid-glass|show_tab_bar');
}

/** Hides the tab bar without unmounting it. iOS only. */
export async function hideTabBar(): Promise<void> {
  await invoke('plugin:liquid-glass|hide_tab_bar');
}

/**
 * Programmatically selects a tab. Does **not** emit a `tabSelected` event
 * (matching UIKit, which only reports user taps). iOS only.
 */
export async function selectTab(id: string): Promise<void> {
  await invoke('plugin:liquid-glass|select_tab', { options: { id } });
}

/** Sets (or clears, when `value` is omitted) a tab's badge. iOS only. */
export async function setBadge(id: string, value?: string): Promise<void> {
  await invoke('plugin:liquid-glass|set_badge', { options: { id, value } });
}

/**
 * Height of the region the bar occludes at the bottom of the screen, in CSS
 * points — pad your page's bottom by this so content can scroll clear of the
 * floating bar. iOS only.
 */
export async function getTabBarInsets(): Promise<TabBarInsets> {
  return await invoke('plugin:liquid-glass|get_tab_bar_insets');
}

/**
 * Listens for user taps on the native tab bar. Drive your page switching
 * from this. iOS only (never fires elsewhere).
 */
export async function onTabSelected(
  handler: (event: TabSelectedEvent) => void,
): Promise<PluginListener> {
  return await addPluginListener('liquid-glass', 'tabSelected', handler);
}

/**
 * Reports whether the real `NSGlassEffectView` (macOS 26+) is available,
 * or whether {@link setWindowGlass} would fall back to a blur. Resolves
 * `{ supported: false, fallback: false }` on iOS/Windows/Linux.
 */
export async function isGlassSupported(): Promise<GlassSupport> {
  return await invoke('plugin:liquid-glass|is_glass_supported');
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
  await invoke('plugin:liquid-glass|set_window_glass', { options });
}

/** Removes the glass view installed by {@link setWindowGlass}. macOS only. */
export async function clearWindowGlass(): Promise<void> {
  await invoke('plugin:liquid-glass|clear_window_glass');
}
