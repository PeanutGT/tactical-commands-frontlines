/** Raw RGBA pixels, as produced by a canvas or pngjs. */
export interface RgbaImage {
  width: number;
  height: number;
  data: Uint8Array | Uint8ClampedArray;
}

export enum Terrain {
  Plain = 0,
  Forest = 1,
  Road = 2,
  Water = 3,
  Building = 4,
  Poi = 5,
  EnemySpawn = 6,
  PlayerSpawn = 7,
  Hq = 8,
  Bridge = 9,
  Ford = 10,
}

export type Side = 'player' | 'enemy';

export interface Cell {
  x: number;
  y: number;
}

/** A connected group of same-terrain cells (a POI, an HQ, a bridge...). */
export interface CellGroup {
  id: number;
  cells: Cell[];
  /** Cell-space centroid. */
  center: { x: number; y: number };
}

export interface HqGroup extends CellGroup {
  owner: Side;
}

/** Contents of a map's map.json. */
export interface MapConfig {
  id: string;
  name: string;
  files: { terrain: string; height: string | null };
  size: { w: number; h: number };
  metersPerCell: number;
  weightCap: number;
  deckSize: number;
  handSize: number;
  startSupply: number;
  supplyCap: number;
  victoryPoints: number;
  timeLimitSec: number;
}

export interface UnknownColor {
  x: number;
  y: number;
  rgb: [number, number, number];
}

/** A fully parsed, ready-to-simulate map. */
export interface GameMap {
  config: MapConfig;
  width: number;
  height: number;
  /** Terrain id per cell, row-major. */
  terrain: Uint8Array;
  /** Height level 0..3 per cell, row-major. */
  elevation: Uint8Array;
  pois: CellGroup[];
  hqs: HqGroup[];
  bridges: CellGroup[];
  spawns: Record<Side, CellGroup | null>;
  unknownColors: UnknownColor[];
}
