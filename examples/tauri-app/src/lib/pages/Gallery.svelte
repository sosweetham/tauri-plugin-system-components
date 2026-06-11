<div class="card">
  <h1>Gallery</h1>
  <p class="muted">Bright swatches to push the glass refraction around.</p>
</div>

<div class="swatches">
  {#each ['#ff5e62', '#f9d423', '#38ef7d', '#4facfe', '#c471ed', '#f64f59', '#12c2e9', '#f5af19', '#0f9b8e', '#fc466b', '#3f5efb', '#11998e'] as color}
    <div class="swatch" style:background={color}></div>
  {/each}
</div>
