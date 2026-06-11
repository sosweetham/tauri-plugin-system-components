<script>
  let { tabs, selected = $bindable() } = $props();
</script>

<nav class="tab-bar-html">
  {#each tabs as tab (tab.id)}
    <button
      class:active={selected === tab.id}
      onclick={() => (selected = tab.id)}
    >
      <span class="icon">{tab.icon}</span>
      <span>{tab.title}</span>
    </button>
  {/each}
</nav>
