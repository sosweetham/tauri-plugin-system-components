<script>
  import {
    setBadge,
    hideTabBar,
    showTabBar,
    selectTab,
    clearWindowGlass,
    setWindowGlass,
  } from 'tauri-plugin-liquid-glass-api';

  let { glass = null, nativeBar = false } = $props();
  let status = $state('');

  async function run(label, fn) {
    try {
      await fn();
      status = `${label}: ok`;
    } catch (e) {
      status = `${label}: ${e}`;
    }
  }
</script>

<div class="card">
  <h1>Settings</h1>
  <p class="muted">Debug controls for the plugin commands.</p>
</div>

{#if nativeBar}
  <div class="card">
    <h2>Native tab bar</h2>
    <button onclick={() => run('setBadge', () => setBadge('gallery', '3'))}>
      Badge Gallery (iOS)
    </button>
    <button onclick={() => run('clearBadge', () => setBadge('gallery'))}>
      Clear badge (iOS)
    </button>
    <button
      onclick={() =>
        run('hide/show', async () => {
          await hideTabBar();
          await new Promise((r) => setTimeout(r, 1200));
          await showTabBar();
        })}
    >
      Hide for 1.2s
    </button>
    <button onclick={() => run('selectTab', () => selectTab('home'))}>
      Select Home (no event)
    </button>
  </div>
{/if}

{#if glass}
  <div class="card">
    <h2>Window glass (macOS)</h2>
    <p class="muted">
      supported: {glass.supported} · fallback: {glass.fallback}
    </p>
    <button
      onclick={() =>
        run('setWindowGlass', async () => {
          await setWindowGlass({});
          document.body.classList.add('desktop-glass');
        })}
    >
      Apply glass
    </button>
    <button
      onclick={() =>
        run('clearWindowGlass', async () => {
          await clearWindowGlass();
          document.body.classList.remove('desktop-glass');
        })}
    >
      Clear glass
    </button>
  </div>
{/if}

{#if status}
  <div class="card">
    <p class="muted">{status}</p>
  </div>
{/if}
