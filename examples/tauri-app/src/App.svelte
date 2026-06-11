<script>
  import { onMount } from 'svelte';
  import {
    getTabBarInsets,
    onTabSelected,
    isGlassSupported,
    setWindowGlass,
  } from 'tauri-plugin-liquid-glass-api';
  import TabBarHtml from './lib/TabBarHtml.svelte';
  import { pg, tabs, applyTabBar } from './lib/playground.svelte.js';
  import Home from './lib/pages/Home.svelte';
  import Gallery from './lib/pages/Gallery.svelte';
  import Profile from './lib/pages/Profile.svelte';
  import Settings from './lib/pages/Settings.svelte';

  const pages = { home: Home, gallery: Gallery, profile: Profile, settings: Settings };

  let selected = $state('home');
  /** true once the native tab bar is mounted */
  let nativeBar = $state(false);
  /** bottom padding (px) reserved for the floating native bar */
  let bottomPad = $state(0);
  /** glass support report on desktop, null elsewhere */
  let glass = $state(null);

  // onMount (not $effect): this must run exactly once — an effect would
  // track its reactive reads and re-run the whole init on every change,
  // stacking duplicate tabSelected listeners.
  onMount(async () => {
    try {
      // iOS: native Liquid Glass UITabBar; macOS: NSSegmentedControl in a
      // floating glass capsule. Windows/Linux reject with "unsupported on
      // this platform" — the documented signal to use the HTML bar instead.
      await applyTabBar(selected);
      nativeBar = true;
      bottomPad = (await getTabBarInsets()).bottom;
      await onTabSelected(({ id }) => {
        selected = id;
      });
    } catch {
      // Windows/Linux: plain gradient, HTML bar.
    }
    try {
      // macOS: glass window background — real glass on 26+, blur fallback
      // before that. Rejects on every other platform.
      glass = await isGlassSupported();
      await setWindowGlass({});
      document.body.classList.add('desktop-glass');
    } catch {
      glass = null;
    }
  });

  const Page = $derived(pages[selected]);
</script>

{#if pg.background && !pg.nativeCards}
  <!-- Fixed photo layer: content scrolls over it, so the glass bar refracts
       both the photo and the moving content. In native-cards mode the photo
       moves to the NATIVE backdrop layer instead — painting it in the DOM
       would sit on top of (and completely hide) the glass panels below the
       webview. -->
  <div class="photo-bg" style:background-image={`url(${pg.background})`}></div>
{/if}

<main style:padding-bottom={nativeBar ? `${bottomPad}px` : 'calc(72px + env(safe-area-inset-bottom))'}>
  <Page {glass} {nativeBar} {selected} />
</main>

{#if !nativeBar}
  <TabBarHtml {tabs} bind:selected />
{/if}
