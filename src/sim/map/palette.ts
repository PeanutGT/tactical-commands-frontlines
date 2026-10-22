import { Terrain } from './types';

export type Rgb = readonly [number, number, number];

export interface TerrainInfo {
  rgb: Rgb;
  /** Ground infantry can enter. */
  infantry: boolean;
  /** Ground vehicles can enter. */
  vehicle: boolean;
  speedInfantry: number;
  speedVehicle: number;
  blocksSight: boolean;
}

const open = (rgb: Rgb, speed = 1): TerrainInfo => ({
  rgb, infantry: true, vehicle: true, speedInfantry: speed, speedVehicle: speed, blocksSight: false,
});

/** Section 4.1 of the design doc. */
export const TERRAIN_INFO: Record<Terrain, TerrainInfo> = {
  [Terrain.Plain]: open([0, 200, 0]),
  [Terrain.Forest]: { rgb: [0, 100, 0], infantry: true, vehicle: true, speedInfantry: 0.8, speedVehicle: 0.5, blocksSight: true },
  [Terrain.Road]: open([128, 128, 128], 1.3),
  [Terrain.Water]: { rgb: [0, 0, 255], infantry: false, vehicle: false, speedInfantry: 0, speedVehicle: 0, blocksSight: false },
  [Terrain.Building]: { rgb: [0, 0, 0], infantry: false, vehicle: false, speedInfantry: 0, speedVehicle: 0, blocksSight: true },
  [Terrain.Poi]: open([255, 255, 0]),
  [Terrain.EnemySpawn]: open([255, 0, 0]),
  [Terrain.PlayerSpawn]: open([0, 200, 255]),
  [Terrain.Hq]: { rgb: [255, 0, 255], infantry: false, vehicle: false, speedInfantry: 0, speedVehicle: 0, blocksSight: true },
  [Terrain.Bridge]: open([160, 82, 45]),
  [Terrain.Ford]: { rgb: [120, 170, 200], infantry: true, vehicle: false, speedInfantry: 0.4, speedVehicle: 0, blocksSight: false },
};

const ENTRIES = (Object.keys(TERRAIN_INFO) as unknown as string[])
  .map((k) => Number(k) as Terrain)
  .map((t) => [t, TERRAIN_INFO[t].rgb] as const);

/** Max RGB distance still considered a match (absorbs JPEG / resampling noise). */
export const COLOR_TOLERANCE = 60;

export interface Classification {
  terrain: Terrain;
  /** Euclidean RGB distance to the matched palette color. */
  distance: number;
}

/** Nearest palette color. Callers decide whether `distance` is too large. */
export function classifyColor(r: number, g: number, b: number): Classification {
  let best = Terrain.Plain;
  let bestD = Infinity;
  for (const [t, [pr, pg, pb]] of ENTRIES) {
    const d = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2;
    if (d < bestD) {
      bestD = d;
      best = t;
    }
  }
  return { terrain: best, distance: Math.sqrt(bestD) };
}

/** Grey levels of the height PNG (section 4.2). */
export const HEIGHT_LEVELS = [0, 85, 170, 255] as const;

export function classifyHeight(grey: number): number {
  let best = 0;
  for (let i = 1; i < HEIGHT_LEVELS.length; i++) {
    if (Math.abs(grey - HEIGHT_LEVELS[i]) < Math.abs(grey - HEIGHT_LEVELS[best])) best = i;
  }
  return best;
}
