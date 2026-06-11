/**
 * Shared playground state for the demo: user-picked images and glass
 * properties, plus the single place that (re)configures the native tab bar
 * from them.
 */
import { configureTabBar } from 'tauri-plugin-liquid-glass-api';
import { makeAvatar } from './avatar.js';

export const pg = $state({
  /** data URL override for the profile avatar; null → generated default */
  avatar: null,
  /** data URL for a full-window photo background; null → animated gradient */
  background: null,
  /** hex accent for the native tab bar; '' → system default */
  tabTint: '',
  /** native glass cards mode: glass panels below the webview back the
   *  Home-page cards, synced to their DOM rects */
  nativeCards: false,
});

export const tabs = [
  { id: 'home', title: 'Home', sfSymbol: 'house.fill', icon: '⌂' },
  { id: 'gallery', title: 'Gallery', sfSymbol: 'photo.on.rectangle', icon: '▦' },
  // Bitmap icon: the user's avatar rendered natively in the tab bar,
  // clipped to a circle (the Pendi profile-tab pattern).
  { id: 'profile', title: 'Profile', icon: '◉' },
  { id: 'settings', title: 'Settings', sfSymbol: 'gearshape.fill', icon: '⚙' },
];

export function currentAvatar() {
  return pg.avatar ?? makeAvatar('P');
}

/** (Re)configures the native bar from the current playground state. */
export async function applyTabBar(selectedId) {
  await configureTabBar({
    items: tabs.map((t) =>
      t.id === 'profile'
        ? { id: t.id, title: t.title, image: currentAvatar(), circular: true }
        : { id: t.id, title: t.title, sfSymbol: t.sfSymbol },
    ),
    selectedId,
    tint: pg.tabTint || undefined,
  });
}

export function readFileAsDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result);
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}
