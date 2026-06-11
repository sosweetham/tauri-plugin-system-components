<div class="card">
  <h1>Profile</h1>
  <p>
    This page switch was driven by a native <code>tabSelected</code> event on
    iOS (or the HTML bar elsewhere) — the web app owns all page state.
  </p>
</div>

<div class="card">
  <h2>How it works</h2>
  <p class="muted">
    Swift: <code>UITabBarDelegate.didSelect</code> →
    <code>trigger("tabSelected")</code> → JS
    <code>addPluginListener('liquid-glass', 'tabSelected', …)</code> → Svelte
    state.
  </p>
</div>
