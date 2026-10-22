/**
 * Phaser cameras zoom around the viewport centre:
 *   world = scroll + view/2 + (screen - view/2) / zoom
 * Returns the scroll that keeps the world point under `screen` fixed when
 * zoom changes from `zoom` to `nextZoom`. Works per axis.
 */
export function scrollForZoomAt(scroll: number, view: number, zoom: number, nextZoom: number, screen: number): number {
  const half = view / 2;
  const world = scroll + half + (screen - half) / zoom;
  return world - half - (screen - half) / nextZoom;
}

export const clamp = (v: number, min: number, max: number) => Math.min(max, Math.max(min, v));

/** Zoom that fits the whole world inside the viewport. */
export function fitZoom(viewW: number, viewH: number, worldW: number, worldH: number): number {
  return Math.min(viewW / worldW, viewH / worldH);
}
