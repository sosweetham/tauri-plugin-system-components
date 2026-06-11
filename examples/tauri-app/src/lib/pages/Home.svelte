<script>
  import { onDestroy } from 'svelte';
  import { attachGlassCard } from 'tauri-plugin-liquid-glass-api';
  import { pg } from '../playground.svelte.js';

  let { glass = null, nativeBar = false } = $props();

  /** Filler-card elements that get native glass panels behind them. */
  let cardEls = [];
  let handles = [];

  async function attachAll() {
    await detachAll();
    for (const el of cardEls.filter(Boolean)) {
      const handle = await attachGlassCard(el, { cornerRadius: 18 }).catch(() => null);
      if (handle) handles.push(handle);
    }
  }

  async function detachAll() {
    const detaching = handles;
    handles = [];
    for (const handle of detaching) {
      await handle.remove().catch(() => {});
    }
  }

  $effect(() => {
    if (pg.nativeCards) {
      attachAll();
    } else {
      detachAll();
    }
  });
  onDestroy(detachAll);
</script>

<div class="hero">
  <h1>Liquid Glass Demo</h1>
  <p>
    {#if nativeBar && glass}
      The capsule below is a native <code>NSSegmentedControl</code> floating
      over this webview
      {#if glass.supported}
        inside a real <code>NSGlassEffectView</code> — and the window
        background is glass too.
      {:else}
        inside a blur capsule (macOS pre-26 fallback).
      {/if}
    {:else if nativeBar}
      The bar below is a real UIKit <code>UITabBar</code> floating over this
      webview — on iOS 26 it's Liquid Glass, refracting this gradient as you
      scroll.
    {:else}
      Native tab bar unavailable here — using the HTML fallback bar.
    {/if}
    {#if pg.nativeCards}
      The cards below are backed by <strong>native glass panels</strong>
      synced to their DOM rects — scroll and watch them refract the native
      backdrop.
    {/if}
  </p>
</div>

<div class="card">
  <h2>Scroll me</h2>
  <p>
    Content scrolls behind the floating bar; the page reserves bottom padding
    reported by <code>getTabBarInsets()</code> so nothing gets stuck under it.
    {#if !pg.nativeCards}
      Enable <em>Native glass cards</em> in Settings to back the cards below
      with real glass.
    {/if}
  </p>
</div>

{#each Array(8) as _, i}
  <div class="card" class:glassy={pg.nativeCards} bind:this={cardEls[i]}>
    <h2>Card {i + 1}</h2>
    <p class="muted">
      {#if pg.nativeCards}
        This card's surface is a native glass panel below the webview — the
        text you're reading is plain DOM on top of it.
      {:else}
        Filler content so the page scrolls — watch the bar refract the
        gradient moving behind it.
      {/if}
    </p>
  </div>
{/each}
