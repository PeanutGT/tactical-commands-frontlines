import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { buildGameMap } from '../src/sim/map/buildMap';
import { metersToCells, standardCellsToMeters, toMapCells } from '../src/sim/map/scale';
import type { MapConfig } from '../src/sim/map/types';
import { readPng } from './helpers';

const dir = 'public/maps/hecheng';
const config: MapConfig = JSON.parse(readFileSync(`${dir}/map.json`, 'utf8'));
const map = buildGameMap(config, readPng(`${dir}/terrain.png`), readPng(`${dir}/height.png`));

describe('河城 map', () => {
  it('is 128x128 with no unrecognised colours', () => {
    expect([map.width, map.height]).toEqual([128, 128]);
    expect(map.unknownColors).toEqual([]);
  });

  it('has seven 3x3 points of interest', () => {
    expect(map.pois).toHaveLength(7);
    for (const p of map.pois) expect(p.cells).toHaveLength(9);
  });

  it('has one 3x3 HQ per side, each next to its own spawn zone', () => {
    expect(map.hqs.map((h) => h.owner).sort()).toEqual(['enemy', 'player']);
    for (const h of map.hqs) expect(h.cells).toHaveLength(9);
    const player = map.hqs.find((h) => h.owner === 'player')!;
    expect(player.center.x).toBeLessThan(64); // player spawn is on the west edge
  });

  it('has four bridges and both spawn zones', () => {
    expect(map.bridges).toHaveLength(4);
    expect(map.spawns.player).not.toBeNull();
    expect(map.spawns.enemy).not.toBeNull();
  });

  it('uses all four height levels and no cliffs (adjacent difference <= 1)', () => {
    expect(new Set(map.elevation)).toEqual(new Set([0, 1, 2, 3]));
    for (let y = 0; y < map.height; y++) {
      for (let x = 0; x < map.width; x++) {
        const h = map.elevation[y * map.width + x];
        if (x + 1 < map.width) expect(Math.abs(h - map.elevation[y * map.width + x + 1])).toBeLessThanOrEqual(1);
        if (y + 1 < map.height) expect(Math.abs(h - map.elevation[(y + 1) * map.width + x])).toBeLessThanOrEqual(1);
      }
    }
  });
});

describe('scale conversion', () => {
  it('converts the doc example: tank range 160 m', () => {
    expect(metersToCells(160, 20)).toBe(8);
    expect(metersToCells(160, 10)).toBe(16);
    expect(metersToCells(160, 40)).toBe(4);
  });

  it('converts range, vision and speed of a doc-table unit for a 10 m/cell map', () => {
    const tank = { range: standardCellsToMeters(8), vision: standardCellsToMeters(8), speed: standardCellsToMeters(2) };
    expect(toMapCells(tank, 10)).toEqual({ range: 16, vision: 16, speed: 4 });
  });
});
