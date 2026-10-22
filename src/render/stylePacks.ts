import { Terrain } from '../sim/map/types';

/**
 * Art is looked up from a style pack so it can be swapped without touching
 * the simulation (design doc section 3). `dev` is the geometric placeholder.
 */
export interface StylePack {
  id: string;
  cellPx: number;
  terrain: Record<Terrain, number>;
  /** Brightness multiplier per height level 0..3. */
  heightShade: [number, number, number, number];
  contour: number;
  grid: number;
  poiRing: number;
  hq: Record<'player' | 'enemy', number>;
}

export const DEV_STYLE: StylePack = {
  id: 'dev',
  cellPx: 16,
  terrain: {
    [Terrain.Plain]: 0x7fa65a,
    [Terrain.Forest]: 0x3f6b3a,
    [Terrain.Road]: 0xa7a59c,
    [Terrain.Water]: 0x3b6fa8,
    [Terrain.Building]: 0x3a3a40,
    [Terrain.Poi]: 0x7fa65a,
    [Terrain.EnemySpawn]: 0xb45a50,
    [Terrain.PlayerSpawn]: 0x4f8fb8,
    [Terrain.Hq]: 0x7fa65a,
    [Terrain.Bridge]: 0x8a6a4a,
    [Terrain.Ford]: 0x6f9cbf,
  },
  heightShade: [0.86, 0.96, 1.06, 1.16],
  contour: 0x1d2418,
  grid: 0x000000,
  poiRing: 0xf2d04a,
  hq: { player: 0x58b4e8, enemy: 0xe8605a },
};

export function shade(color: number, k: number): number {
  const c = (shift: number) => Math.min(255, Math.round(((color >> shift) & 0xff) * k));
  return (c(16) << 16) | (c(8) << 8) | c(0);
}

export const cssColor = (color: number) => `#${color.toString(16).padStart(6, '0')}`;
