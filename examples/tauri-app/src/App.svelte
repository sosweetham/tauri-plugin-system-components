<script>
  import { onMount } from 'svelte';
  import {
    configureTabBar,
    getTabBarInsets,
    onTabSelected,
    isGlassSupported,
    setWindowGlass,
  } from 'tauri-plugin-liquid-glass-api';
  import TabBarHtml from './lib/TabBarHtml.svelte';
  import Home from './lib/pages/Home.svelte';
  import Gallery from './lib/pages/Gallery.svelte';
  import Profile from './lib/pages/Profile.svelte';
  import Settings from './lib/pages/Settings.svelte';

  const tabs = [
    { id: 'home', title: 'Home', sfSymbol: 'house.fill', icon: '⌂' },
    { id: 'gallery', title: 'Gallery', sfSymbol: 'photo.on.rectangle', icon: '▦' },
    { id: 'profile', title: 'Profile', sfSymbol: 'person.crop.circle', icon: '◉' },
    { id: 'settings', title: 'Settings', sfSymbol: 'gearshape.fill', icon: '⚙' },
  ];

  const pages = { home: Home, gallery: Gallery, profile: Profile, settings: Settings };

  let selected = $state('home');
  /** true once the native iOS tab bar is mounted */
  let nativeBar = $state(false);
  /** bottom padding (px) reserved for the floating native bar */
  let bottomPad = $state(0);
  /** glass support report on desktop, null elsewhere */
  let glass = $state(null);

  // onMount (not $effect): this must run exactly once — an effect would
  // track `selected` and re-run the whole init on every tab change,
  // stacking duplicate tabSelected listeners.
  onMount(async () => {
    try {
        // iOS: mounts the native Liquid Glass tab bar over the webview.
        // Everywhere else this rejects with "unsupported on this platform",
        // which is the documented signal to fall back to the HTML bar.
      await configureTabBar({
        items: tabs.map(({ id, title, sfSymbol }) => ({ id, title, sfSymbol })),
        selectedId: selected,
      });
      nativeBar = true;
      bottomPad = (await getTabBarInsets()).bottom;
      await onTabSelected(({ id }) => {
        selected = id;
      });
    } catch {
      try {
        glass = await isGlassSupported();
        // macOS: real glass on 26+, blur fallback before that.
        await setWindowGlass({});
        document.body.classList.add('desktop-glass');
      } catch {
        // Windows/Linux: plain gradient, HTML bar.
      }
    }
  });

  const Page = $derived(pages[selected]);
</script>

<main style:padding-bottom={nativeBar ? `${bottomPad}px` : 'calc(72px + env(safe-area-inset-bottom))'}>
  <Page {glass} {nativeBar} />
</main>

{#if !nativeBar}
  <TabBarHtml {tabs} bind:selected />
{/if}
