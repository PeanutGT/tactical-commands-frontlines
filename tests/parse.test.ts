import { describe, expect, it } from 'vitest';
import { classifyColor, classifyHeight } from '../src/sim/map/palette';
import { cropBottom, downsampleMajority, groupCells, measureScaleBar, parseTerrain } from '../src/sim/map/parse';
import { Terrain } from '../src/sim/map/types';
import { imageFromRows } from './helpers';

const W: [number, number, number] = [255, 255, 255];
const K: [number, number, number] = [0, 0, 0];
const G: [number, number, number] = [0, 200, 0];

describe('classifyColor', () => {
  it('matches exact palette colours', () => {
    expect(classifyColor(0, 200, 255).terrain).toBe(Terrain.PlayerSpawn);
    expect(classifyColor(120, 170, 200).terrain).toBe(Terrain.Ford);
    expect(classifyColor(160, 82, 45).terrain).toBe(Terrain.Bridge);
  });

  it('absorbs JPEG-style noise by snapping to the nearest colour', () => {
    const c = classifyColor(10, 190, 12);
    expect(c.terrain).toBe(Terrain.Plain);
    expect(c.distance).toBeLessThan(20);
  });
});

describe('parseTerrain', () => {
  it('lists the position of colours far from every palette entry', () => {
    const img = imageFromRows(['gx'], { g: G, x: [255, 140, 0] });
    const grid = parseTerrain(img);
    expect(grid.unknownColors).toEqual([{ x: 1, y: 0, rgb: [255, 140, 0] }]);
    expect(grid.terrain[0]).toBe(Terrain.Plain);
  });
});

describe('classifyHeight', () => {
  it('maps the four grey levels and in-between greys', () => {
    expect([0, 85, 170, 255].map(classifyHeight)).toEqual([0, 1, 2, 3]);
    expect(classifyHeight(100)).toBe(1);
    expect(classifyHeight(230)).toBe(3);
  });
});

describe('groupCells', () => {
  it('merges adjacent same-value cells into one group with a centre', () => {
    const grid = Uint8Array.from([
      1, 1, 0, 0,
      1, 1, 0, 1,
      0, 0, 0, 1,
    ]);
    const groups = groupCells(grid, 4, 1);
    expect(groups).toHaveLength(2);
    expect(groups[0].cells).toHaveLength(4);
    expect(groups[0].center).toEqual({ x: 1, y: 1 });
    expect(groups[1].cells).toHaveLength(2);
  });

  it('joins two pieces through connector cells and includes them', () => {
    const groups = groupCells(Uint8Array.from([9, 5, 9, 0]), 4, 9, [5]);
    expect(groups).toHaveLength(1);
    expect(groups[0].cells).toHaveLength(3);
  });

  it('does not join diagonal neighbours', () => {
    expect(groupCells(Uint8Array.from([1, 0, 0, 1]), 2, 1)).toHaveLength(2);
  });
});

describe('measureScaleBar', () => {
  it('reads metres per cell from the 100 m line in the bottom white margin', () => {
    const img = imageFromRows(
      [
        'gggggggggg',
        'gkgggggggg',
        'wwwwwwwwww',
        'wkkkkkwwww',
        'wwwwwwwwww',
      ],
      { g: G, k: K, w: W },
    );
    expect(measureScaleBar(img)).toEqual({ marginRows: 3, barCells: 5, metersPerCell: 20 });
  });

  it('returns null when there is no margin', () => {
    expect(measureScaleBar(imageFromRows(['gg', 'gk'], { g: G, k: K }))).toBeNull();
  });

  it('crops the margin off', () => {
    const img = imageFromRows(['gg', 'ww'], { g: G, w: W });
    const cropped = cropBottom(img, 1);
    expect(cropped.height).toBe(1);
    expect(parseTerrain(cropped).terrain).toEqual(Uint8Array.from([Terrain.Plain, Terrain.Plain]));
  });
});

describe('downsampleMajority', () => {
  it('keeps the most common value of each block', () => {
    const grid = Uint8Array.from([
      1, 1, 2, 2,
      1, 3, 2, 4,
      0, 0, 5, 5,
      0, 1, 5, 5,
    ]);
    expect(downsampleMajority(grid, 4, 2)).toEqual(Uint8Array.from([1, 2, 0, 5]));
  });

  it('rejects sizes not divisible by the factor', () => {
    expect(() => downsampleMajority(new Uint8Array(9), 3, 2)).toThrow();
  });
});
