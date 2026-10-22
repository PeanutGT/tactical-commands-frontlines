import { Terrain } from '../sim/map/types';
import type { GameMap } from '../sim/map/types';
import { cssColor, shade } from './stylePacks';
import type { StylePack } from './stylePacks';

/** Paints the static terrain layer (ground, height shading, contours) onto a 2D canvas. */
export function drawTerrain(ctx: CanvasRenderingContext2D, map: GameMap, style: StylePack): void {
  const s = style.cellPx;
  const { width: w, height: h, terrain, elevation } = map;

  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const i = y * w + x;
      const t = terrain[i] as Terrain;
      ctx.fillStyle = cssColor(shade(style.terrain[t], style.heightShade[elevation[i]]));
      ctx.fillRect(x * s, y * s, s, s);
      if (t === Terrain.Building) {
        // Inset roof so adjacent buildings read as separate blocks.
        ctx.fillStyle = cssColor(shade(style.terrain[t], 1.35));
        ctx.fillRect(x * s + 2, y * s + 2, s - 4, s - 4);
      } else if (t === Terrain.Forest) {
        ctx.fillStyle = cssColor(shade(style.terrain[t], 0.8));
        ctx.beginPath();
        ctx.arc(x * s + s / 2, y * s + s / 2, s * 0.32, 0, Math.PI * 2);
        ctx.fill();
      } else if (t === Terrain.Ford) {
        ctx.fillStyle = cssColor(shade(style.terrain[t], 1.2));
        ctx.fillRect(x * s, y * s + s / 2 - 1, s, 2);
      }
    }
  }

  // Contour lines wherever the height level changes.
  ctx.fillStyle = cssColor(style.contour);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const e = elevation[y * w + x];
      if (x + 1 < w && elevation[y * w + x + 1] !== e) ctx.fillRect((x + 1) * s - 1, y * s, 2, s);
      if (y + 1 < h && elevation[(y + 1) * w + x] !== e) ctx.fillRect(x * s, (y + 1) * s - 1, s, 2);
    }
  }
}
