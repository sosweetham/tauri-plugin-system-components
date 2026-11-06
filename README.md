# tauri-plugin-system-components

Native **system UI components** for [Tauri 2](https://tauri.app) apps — real UIKit/AppKit controls over the webview, including Apple's Liquid Glass material on iOS 26 / macOS 26:

- **iOS — native bottom tab bar.** A real UIKit `UITabBar` floated over the
  webview. Built with Xcode 26 against the iOS 26 SDK, it adopts Liquid Glass
  automatically and **refracts the live web content rendered behind it** —
  something CSS cannot reproduce, because glass samples the native layers
  beneath the view (the same mechanism Safari's own iOS 26 toolbars use over
  a `WKWebView`). Tab taps are delivered to JS as `tabSelected` events so the
  web app drives its own page switching. On pre-26 devices the same bar
  renders the classic translucent look.
- **macOS — native floating tab bar.** The same `configureTabBar` API mounts
  an `NSSegmentedControl` (the control `NSTabViewController` uses for
  toolbar-style tabs, with SF Symbol icons) inside a floating
  `NSGlassEffectView` capsule pinned to the bottom center of the window —
  blur capsule fallback pre-26. Selection reaches JS through the same
  `onTabSelected` helper.
- **macOS — glass window background.** An `NSGlassEffectView` (macOS 26)
  inserted behind a transparent webview, with an `NSVisualEffectView` blur
  fallback on older systems. The class is resolved dynamically at runtime, so
  the plugin builds and runs against older SDKs/systems.

- **Native overlay components** on both platforms via one generic API:
  `createComponent({ id, kind, props, anchor, dx, dy })` with kinds
  `switch` (UISwitch/NSSwitch), `button` (glass `UIButton.Configuration`
  on iOS 26 / NSButton), `slider`, `progress`, and `image`. Components float
  over the webview anchored to a corner/center, optionally inside a glass
  capsule (`props.glass: true`). Interaction arrives via
  `onComponentEvent(({ id, event, on, value }) => …)`; state updates go
  back with `updateComponent(id, props)`.
- **Image data everywhere.** Tab items and components accept bitmaps as
  base64 / `data:` URLs (`image`), decoded natively to `UIImage`/`NSImage`,
  with `circular: true` for the avatar treatment — e.g. a user avatar as
  the profile tab icon, rendered by the real native bar.

Windows, Linux, and Android are graceful stubs: the commands reject with
`unsupported on this platform`, which is the documented signal to fall back
to an HTML UI (see the example app). Tab badges (`setBadge`) are iOS-only —
`NSSegmentedControl` has no badge concept.

## Install

```toml
# src-tauri/Cargo.toml
[dependencies]
tauri-plugin-system-components = { path = "..." }
```

```rust
// src-tauri/src/lib.rs
tauri::Builder::default()
    .plugin(tauri_plugin_system_components::init())
```

```json
// src-tauri/capabilities/default.json
{ "permissions": ["system-components:default"] }
```

```bash
pnpm add @sosweetham/tauri-plugin-system-components-api
```

## Usage

```ts
import {
  configureTabBar,
  onTabSelected,
  getTabBarInsets,
  isGlassSupported,
  setWindowGlass,
} from '@sosweetham/tauri-plugin-system-components-api';

try {
  // Native Liquid Glass tab bar (iOS UITabBar / macOS glass capsule).
  await configureTabBar({
    items: [
      { id: 'home', title: 'Home', sfSymbol: 'house.fill' },
      // A bitmap icon — e.g. the user's avatar — clipped to a circle:
      { id: 'profile', title: 'Profile', image: avatarDataUrl, circular: true },
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

Native overlay components:

```ts
import {
  createComponent, updateComponent, removeComponent, onComponentEvent,
} from '@sosweetham/tauri-plugin-system-components-api';

await createComponent({
  id: 'wifi', kind: 'switch', anchor: 'topTrailing',
  props: { glass: true, on: true },
});
await createComponent({
  id: 'volume', kind: 'slider', anchor: 'bottomTrailing', dy: 96,
  props: { glass: true, min: 0, max: 100, value: 40 },
});
await createComponent({
  id: 'me', kind: 'image', anchor: 'topLeading',
  props: { image: avatarDataUrl, circular: true, width: 48, height: 48 },
});
await onComponentEvent(({ id, event, on, value }) => {
  if (id === 'volume' && event === 'change') setVolume(value);
});
await updateComponent('wifi', { on: false });
await removeComponent('me');
```

Segmented control (iOS), scrolling with the page. With the `document` anchor
the view lives inside the webview's scroll view, so it moves with the content
natively; `stickyTop` pins it like `position: sticky`, and `stickyBottom`
releases it at the end of its containing block. Keep an invisible DOM
placeholder that holds the space and carries the sticky CSS:

```css
#day-tabs {
  position: sticky;
  top: calc(env(safe-area-inset-top) + 8px); /* becomes stickyTop */
  height: 44px;
  visibility: hidden; /* the native control draws on top */
}
```

```ts
const el = document.querySelector<HTMLElement>('#day-tabs')!;

// Page geometry of the placeholder, as if it weren't stuck.
function measure() {
  const stickyTop = parseFloat(getComputedStyle(el).top) || 0;
  const position = el.style.position;
  el.style.position = 'static';
  const { left, top, width, height } = el.getBoundingClientRect();
  el.style.position = position;
  const parent = el.parentElement!.getBoundingClientRect();
  return {
    x: left + scrollX, y: top + scrollY, width, height,
    stickyTop, stickyBottom: parent.bottom + scrollY,
  };
}

await createComponent({
  id: 'days', kind: 'segmented', anchor: 'document',
  props: {
    items: [
      { id: 'tue', title: 'Tuesday' },
      { id: 'wed', title: 'Wednesday', badge: '3' },
    ],
    selectedId: 'tue',
    badgeColor: '#5b0f5b', badgeTextColor: '#ffffff',
    ...measure(),
  },
});
// Scrolling needs no JS; re-measure only when the layout changes.
new ResizeObserver(() => updateComponent('days', measure())).observe(document.body);

await onComponentEvent(({ id, event, detail }) => {
  if (id === 'days' && event === 'select') showDay(detail);
});
await updateComponent('days', { selectedId: 'wed' });
```

On iOS 26 the control sits on a Liquid Glass capsule, like segmented
controls in system bars. A segment shows its `title`, or its `sfSymbol` only
when `title` is empty.

Other commands: `removeTabBar`, `showTabBar`, `hideTabBar`,
`selectTab(id)` (no event, mirrors AppKit/UIKit), `setBadge(id, value?)`
(iOS-only), `clearWindowGlass`.

`onTabSelected` subscribes to both transports under the hood — the mobile
plugin event channel on iOS and the `system-components://tab-selected` Tauri event
on macOS — so app code is identical everywhere.

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
- **iOS: the plugin repairs the keyboard's layout-viewport shrink.** Focusing a
  text field makes WebKit take the input accessory bar's height off the
  webview's *layout* viewport — `window.innerHeight`, `100dvh`, and the
  containing block of every `position: fixed` element — and iOS often never
  gives it back once the keyboard leaves, stranding bottom-anchored UI 44–53pt
  above the screen for the life of the web view (a page reload does not clear
  it). Merely loading the plugin installs a guard that restores the viewport
  once the keyboard is gone; there is no API and nothing to opt into. It costs
  one hidden 0.5pt resize of the webview per keyboard dismissal.

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
