<script>
  import { onMount, onDestroy } from 'svelte';
  import {
    setBadge,
    hideTabBar,
    showTabBar,
    selectTab,
    clearWindowGlass,
    setWindowGlass,
    createComponent,
    updateComponent,
    removeComponent,
    onComponentEvent,
  } from 'tauri-plugin-liquid-glass-api';
  import {
    pg,
    applyTabBar,
    currentAvatar,
    readFileAsDataUrl,
  } from '../playground.svelte.js';
  import { makeBackdropImage } from '../avatar.js';

  async function toggleNativeCards() {
    if (!pg.nativeCards) {
      // Native backdrop below the webview — what the glass cards refract.
      await createComponent({
        id: 'native-bg',
        kind: 'image',
        anchor: 'fill',
        below: true,
        props: { image: pg.background ?? makeBackdropImage() },
      });
      document.body.classList.add('native-cards');
      pg.nativeCards = true;
    } else {
      pg.nativeCards = false; // Home page detaches its panels reactively.
      document.body.classList.remove('native-cards');
      await removeComponent('native-bg');
    }
  }

  let { glass = null, nativeBar = false, selected = 'settings' } = $props();
  let status = $state('');
  let compEvent = $state('');
  let componentsOn = $state(false);

  // Glass property knobs.
  let tabTint = $state('#4facfe');
  let glassRadius = $state(0);
  let glassTint = $state('#4facfe');
  let glassTintOn = $state(false);

  async function pickImage(event, apply) {
    const file = event.target.files?.[0];
    if (!file) return;
    const dataUrl = await readFileAsDataUrl(file);
    await run(file.name, () => apply(dataUrl));
    event.target.value = '';
  }

  async function reconfigure() {
    if (nativeBar) await applyTabBar(selected);
  }

  async function applyWindowGlass() {
    await setWindowGlass({
      cornerRadius: glassRadius > 0 ? glassRadius : undefined,
      tintColor: glassTintOn ? glassTint : undefined,
    });
    document.body.classList.add('desktop-glass');
  }

  const COMPONENT_IDS = [
    'demo-switch',
    'demo-slider',
    'demo-button',
    'demo-progress',
    'demo-avatar',
  ];

  let listener = null;
  onMount(async () => {
    listener = await onComponentEvent(async (e) => {
      compEvent = JSON.stringify(e);
      // Drive the native progress bar from the native slider.
      if (e.id === 'demo-slider' && e.value != null) {
        await updateComponent('demo-progress', { value: e.value / 100 }).catch(() => {});
      }
    });
  });
  onDestroy(() => listener?.unregister());

  async function toggleComponents() {
    if (componentsOn) {
      for (const id of COMPONENT_IDS) {
        await removeComponent(id).catch(() => {});
      }
      componentsOn = false;
      return;
    }
    await createComponent({
      id: 'demo-switch',
      kind: 'switch',
      anchor: 'topTrailing',
      props: { glass: true, on: true },
    });
    await createComponent({
      id: 'demo-avatar',
      kind: 'image',
      anchor: 'topTrailing',
      dy: 72,
      props: { image: currentAvatar(), circular: true, width: 48, height: 48 },
    });
    await createComponent({
      id: 'demo-button',
      kind: 'button',
      anchor: 'topLeading',
      props: { label: 'Glass', sfSymbol: 'sparkles', prominent: true },
    });
    await createComponent({
      id: 'demo-slider',
      kind: 'slider',
      anchor: 'bottomTrailing',
      dy: 96,
      props: { glass: true, min: 0, max: 100, value: 40 },
    });
    await createComponent({
      id: 'demo-progress',
      kind: 'progress',
      anchor: 'bottomLeading',
      dy: 96,
      props: { glass: true, value: 0.4 },
    });
    componentsOn = true;
  }

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

<div class="card">
  <h2>Appearance playground</h2>
  <div class="field">
    <img class="avatar-preview" src={pg.avatar ?? currentAvatar()} alt="avatar" />
    <label>
      Profile image
      <input
        type="file"
        accept="image/*"
        onchange={(e) =>
          pickImage(e, async (dataUrl) => {
            pg.avatar = dataUrl;
            await reconfigure();
          })}
      />
    </label>
  </div>
  <div class="field">
    <label>
      Background photo (scroll the pages to watch the glass refract it)
      <input
        type="file"
        accept="image/*"
        onchange={(e) =>
          pickImage(e, async (dataUrl) => {
            pg.background = dataUrl;
            // In native-cards mode the photo lives in the native backdrop.
            if (pg.nativeCards) {
              await updateComponent('native-bg', { image: dataUrl });
            }
          })}
      />
    </label>
  </div>
  <button
    onclick={() =>
      run('reset images', async () => {
        pg.avatar = null;
        pg.background = null;
        await reconfigure();
      })}
  >
    Reset images
  </button>
</div>

{#if nativeBar}
  <div class="card">
    <h2>Native glass cards</h2>
    <p class="muted">
      Backs the Home-page cards with real glass panels below the webview,
      synced to their DOM rects, over a native backdrop image. Go to Home
      and scroll.
    </p>
    <button onclick={() => run('native cards', toggleNativeCards)}>
      {pg.nativeCards ? 'Disable native cards' : 'Enable native cards'}
    </button>
  </div>

  <div class="card">
    <h2>Tab bar properties</h2>
    <div class="field">
      <label>
        Accent tint
        <input type="color" bind:value={tabTint} />
      </label>
      <button
        onclick={() =>
          run('tint', async () => {
            pg.tabTint = tabTint;
            await reconfigure();
          })}
      >
        Apply
      </button>
      <button
        onclick={() =>
          run('clear tint', async () => {
            pg.tabTint = '';
            await reconfigure();
          })}
      >
        Clear
      </button>
    </div>
  </div>
{/if}

{#if nativeBar}
  <div class="card">
    <h2>Native components</h2>
    <p class="muted">
      Floats a native switch, glass button, slider, progress bar and a
      circular avatar image over the page. The slider drives the progress
      bar natively.
    </p>
    <button onclick={() => run('components', toggleComponents)}>
      {componentsOn ? 'Remove components' : 'Spawn components'}
    </button>
    {#if compEvent}
      <p class="muted">last event: {compEvent}</p>
    {/if}
  </div>
{/if}

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
    <div class="field">
      <label>
        Corner radius: {glassRadius}
        <input type="range" min="0" max="48" bind:value={glassRadius} />
      </label>
    </div>
    <div class="field">
      <label>
        Tint
        <input type="color" bind:value={glassTint} />
      </label>
      <label>
        <input type="checkbox" bind:checked={glassTintOn} />
        use tint
      </label>
    </div>
    <button onclick={() => run('setWindowGlass', applyWindowGlass)}>
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
