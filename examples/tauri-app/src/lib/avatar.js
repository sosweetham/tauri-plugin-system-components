/**
 * Generates a demo avatar (gradient + initials) as a base64 data URL — the
 * same shape of payload an app would produce from a real profile photo.
 * The plugin decodes it natively (UIImage/NSImage) for tab items and image
 * components.
 */
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
