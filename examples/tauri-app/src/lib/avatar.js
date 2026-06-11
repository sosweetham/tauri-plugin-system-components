/**
 * Generates a demo avatar (gradient + initials) as a base64 data URL — the
 * same shape of payload an app would produce from a real profile photo.
 * The plugin decodes it natively (UIImage/NSImage) for tab items and image
 * components.
 */
/**
 * Static gradient backdrop for the native-cards demo: rendered to a JPEG
 * data URL and shown as a native `fill` image component *below* the
 * webview, so native glass cards have something colorful to refract.
 */
export function makeBackdropImage() {
  const canvas = document.createElement('canvas');
  canvas.width = 1024;
  canvas.height = 2048;
  const ctx = canvas.getContext('2d');
  const gradient = ctx.createLinearGradient(0, 0, 1024, 2048);
  gradient.addColorStop(0, '#ff5e62');
  gradient.addColorStop(0.35, '#f9d423');
  gradient.addColorStop(0.7, '#38ef7d');
  gradient.addColorStop(1, '#4facfe');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, 1024, 2048);
  return canvas.toDataURL('image/jpeg', 0.9);
}

export function makeAvatar(initials) {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 128;
  const ctx = canvas.getContext('2d');
  const gradient = ctx.createLinearGradient(0, 0, 128, 128);
  gradient.addColorStop(0, '#ff5e62');
  gradient.addColorStop(1, '#4facfe');
  ctx.fillStyle = gradient;
  ctx.fillRect(0, 0, 128, 128);
  ctx.fillStyle = '#fff';
  ctx.font = 'bold 56px -apple-system, sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(initials, 64, 70);
  return canvas.toDataURL('image/png');
}
