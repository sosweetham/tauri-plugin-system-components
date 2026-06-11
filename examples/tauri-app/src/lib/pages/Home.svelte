<script>
  let { glass = null, nativeBar = false } = $props();
</script>

<div class="hero">
  <h1>Liquid Glass Demo</h1>
  <p>
    {#if nativeBar}
      The bar below is a real UIKit <code>UITabBar</code> floating over this
      webview — on iOS 26 it's Liquid Glass, refracting this gradient as you
      scroll.
    {:else if glass}
      Native tab bar unavailable here — using the HTML fallback bar.
      {#if glass.supported}
        The window background is a real <code>NSGlassEffectView</code>.
      {:else}
        macOS pre-26: using the <code>NSVisualEffectView</code> blur fallback.
      {/if}
    {:else}
      Native tab bar unavailable here — using the HTML fallback bar.
    {/if}
  </p>
</div>

<div class="card">
  <h2>Scroll me</h2>
  <p>
    Content scrolls behind the floating bar; the page reserves bottom padding
    reported by <code>getTabBarInsets()</code> so nothing gets stuck under it.
  </p>
</div>

{#each Array(8) as _, i}
  <div class="card">
    <h2>Card {i + 1}</h2>
    <p class="muted">
      Filler content so the page scrolls — watch the bar refract the gradient
      moving behind it.
    </p>
  </div>
{/each}
