import { groupCells, parseHeight, parseTerrain } from './parse';
import { Terrain } from './types';
import type { GameMap, HqGroup, MapConfig, RgbaImage, Side } from './types';

const dist2 = (a: { x: number; y: number }, b: { x: number; y: number }) => (a.x - b.x) ** 2 + (a.y - b.y) ** 2;

/** Turns the decoded PNGs plus map.json into a GameMap. Pure; no Phaser, no I/O. */
export function buildGameMap(config: MapConfig, terrainImg: RgbaImage, heightImg: RgbaImage | null): GameMap {
  const { width, height, terrain, unknownColors } = parseTerrain(terrainImg);
  if (width !== config.size.w || height !== config.size.h) {
    throw new Error(`${config.id}: terrain is ${width}x${height}, map.json says ${config.size.w}x${config.size.h}`);
  }

  let elevation: Uint8Array = new Uint8Array(width * height);
  if (heightImg) {
    if (heightImg.width !== width || heightImg.height !== height) {
      throw new Error(`${config.id}: height map is ${heightImg.width}x${heightImg.height}, expected ${width}x${height}`);
    }
    elevation = parseHeight(heightImg);
  }

  const largest = (t: Terrain) =>
    groupCells(terrain, width, t).sort((a, b) => b.cells.length - a.cells.length)[0] ?? null;
  const spawns: Record<Side, GameMap['spawns'][Side]> = {
    player: largest(Terrain.PlayerSpawn),
    enemy: largest(Terrain.EnemySpawn),
  };

  // Section 4.1: an HQ belongs to whichever spawn zone it is closer to.
  const hqs: HqGroup[] = groupCells(terrain, width, Terrain.Hq).map((g) => {
    const dp = spawns.player ? dist2(g.center, spawns.player.center) : Infinity;
    const de = spawns.enemy ? dist2(g.center, spawns.enemy.center) : Infinity;
    return { ...g, owner: dp <= de ? 'player' : 'enemy' };
  });

  return {
    config,
    width,
    height,
    terrain,
    elevation,
    pois: groupCells(terrain, width, Terrain.Poi),
    hqs,
    // A POI on a bridge (河城's north and south bridges) is bridge deck too.
    bridges: groupCells(terrain, width, Terrain.Bridge, [Terrain.Poi]),
    spawns,
    unknownColors,
  };
}

export const cellIndex = (map: GameMap, x: number, y: number) => y * map.width + x;

export function inBounds(map: GameMap, x: number, y: number): boolean {
  return x >= 0 && y >= 0 && x < map.width && y < map.height;
}
