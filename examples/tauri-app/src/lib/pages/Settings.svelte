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
  import { makeAvatar } from '../avatar.js';

  let { glass = null, nativeBar = false } = $props();
  let status = $state('');
  let compEvent = $state('');
  let componentsOn = $state(false);

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
      props: { image: makeAvatar('P'), circular: true, width: 48, height: 48 },
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
