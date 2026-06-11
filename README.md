# tauri-plugin-liquid-glass

Apple's official **Liquid Glass** components for [Tauri 2](https://tauri.app) apps:

- **iOS — native bottom tab bar.** A real UIKit `UITabBar` floated over the
  webview. Built with Xcode 26 against the iOS 26 SDK, it adopts Liquid Glass
  automatically and **refracts the live web content rendered behind it** —
  something CSS cannot reproduce, because glass samples the native layers
  beneath the view (the same mechanism Safari's own iOS 26 toolbars use over
  a `WKWebView`). Tab taps are delivered to JS as `tabSelected` events so the
  web app drives its own page switching. On pre-26 devices the same bar
  renders the classic translucent look.
- **macOS — glass window background.** An `NSGlassEffectView` (macOS 26)
  inserted behind a transparent webview, with an `NSVisualEffectView` blur
  fallback on older systems. The class is resolved dynamically at runtime, so
  the plugin builds and runs against older SDKs/systems.

Windows, Linux, and Android are graceful stubs: the commands reject with
`unsupported on this platform`, which is the documented signal to fall back
to an HTML UI (see the example app).

## Install

```toml
# src-tauri/Cargo.toml
[dependencies]
tauri-plugin-liquid-glass = { path = "..." }
```

```rust
// src-tauri/src/lib.rs
tauri::Builder::default()
    .plugin(tauri_plugin_liquid_glass::init())
```

```json
// src-tauri/capabilities/default.json
{ "permissions": ["liquid-glass:default"] }
```

```bash
pnpm add tauri-plugin-liquid-glass-api
```

## Usage

```ts
import {
  configureTabBar,
  onTabSelected,
  getTabBarInsets,
  isGlassSupported,
  setWindowGlass,
} from 'tauri-plugin-liquid-glass-api';

try {
  // iOS: mounts the native Liquid Glass tab bar.
  await configureTabBar({
    items: [
      { id: 'home', title: 'Home', sfSymbol: 'house.fill' },
      { id: 'settings', title: 'Settings', sfSymbol: 'gearshape.fill' },
    ],
    selectedId: 'home',
  });
  // Pad the page bottom so content scrolls clear of the floating bar.
  const { bottom } = await getTabBarInsets();
  await onTabSelected(({ id }) => router.goto(id));
} catch {
  // Not iOS. On macOS, put glass behind the (transparent) webview instead:
  const { supported, fallback } = await isGlassSupported();
  await setWindowGlass({}).catch(() => {/* Windows/Linux */});
}
```

Other commands: `removeTabBar`, `showTabBar`, `hideTabBar`,
`selectTab(id)` (no event, mirrors UIKit), `setBadge(id, value?)`,
`clearWindowGlass`.

## Requirements & caveats

- **Seeing glass on iOS requires building with Xcode 26** (iOS 26 SDK) and an
  iOS 26 device/simulator. The bar itself works from iOS 14.
- **macOS window glass requires** `"transparent": true` on the window and
  `"app": { "macOSPrivateApi": true }` in `tauri.conf.json` (plus the
  `macos-private-api` tauri feature) so the webview lets the glass show
  through — note the private-API flag has App Store implications. Real glass
  needs macOS 26; older systems get a behind-window blur.
- The web page must leave regions transparent (no opaque full-bleed
  background) wherever macOS glass should be visible.
- `tabBarMinimizeBehavior` (bar collapses on scroll) is not exposed yet — it
  lives on `UITabBarController`, not the bare `UITabBar`; planned for a later
  iteration along with more glass components (switches, etc.).
- Keyboard does not auto-hide the bar (standard for floating bars).

## Example app

`examples/tauri-app` is a Svelte 5 + Vite app with an animated gradient
background (so the refraction is obvious), four pages switched by in-app
state, the native bar on iOS, and an HTML fallback bar + window glass on
desktop.

```bash
cd examples/tauri-app
pnpm install
pnpm tauri dev                      # macOS: HTML bar + window glass
pnpm tauri ios dev "iPhone 17 Pro"  # iOS 26 simulator: Liquid Glass bar
```
