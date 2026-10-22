import { COLOR_TOLERANCE, classifyColor, classifyHeight } from './palette';
import type { CellGroup, RgbaImage, UnknownColor } from './types';

export interface TerrainGrid {
  width: number;
  height: number;
  terrain: Uint8Array;
  unknownColors: UnknownColor[];
}

/** One pixel = one cell. Off-palette pixels snap to the nearest color and are reported. */
export function parseTerrain(img: RgbaImage): TerrainGrid {
  const { width, height, data } = img;
  const terrain = new Uint8Array(width * height);
  const unknownColors: UnknownColor[] = [];
  for (let i = 0; i < width * height; i++) {
    const r = data[i * 4], g = data[i * 4 + 1], b = data[i * 4 + 2];
    const c = classifyColor(r, g, b);
    terrain[i] = c.terrain;
    if (c.distance > COLOR_TOLERANCE) {
      unknownColors.push({ x: i % width, y: Math.floor(i / width), rgb: [r, g, b] });
    }
  }
  return { width, height, terrain, unknownColors };
}

/** Grey (red channel) to height level 0..3. */
export function parseHeight(img: RgbaImage): Uint8Array {
  const out = new Uint8Array(img.width * img.height);
  for (let i = 0; i < out.length; i++) out[i] = classifyHeight(img.data[i * 4]);
  return out;
}

/**
 * 4-connected components of cells with the given value.
 * `connectors` are values that join a group once reached from it (e.g. a POI
 * painted on the middle of a bridge); they become part of the group.
 */
export function groupCells(grid: Uint8Array, width: number, value: number, connectors: number[] = []): CellGroup[] {
  const height = grid.length / width;
  const seen = new Uint8Array(grid.length);
  const joins = (v: number) => v === value || connectors.includes(v);
  const groups: CellGroup[] = [];
  for (let start = 0; start < grid.length; start++) {
    if (grid[start] !== value || seen[start]) continue;
    const cells: CellGroup['cells'] = [];
    const stack = [start];
    seen[start] = 1;
    while (stack.length) {
      const i = stack.pop()!;
      const x = i % width, y = (i - x) / width;
      cells.push({ x, y });
      const next = [
        x > 0 ? i - 1 : -1,
        x < width - 1 ? i + 1 : -1,
        y > 0 ? i - width : -1,
        y < height - 1 ? i + width : -1,
      ];
      for (const n of next) {
        if (n >= 0 && !seen[n] && joins(grid[n])) {
          seen[n] = 1;
          stack.push(n);
        }
      }
    }
    // Centre of the cells, +0.5 so a 3x3 block centred on cell 5 reports 5.5.
    const cx = cells.reduce((s, c) => s + c.x, 0) / cells.length + 0.5;
    const cy = cells.reduce((s, c) => s + c.y, 0) / cells.length + 0.5;
    groups.push({ id: groups.length, cells, center: { x: cx, y: cy } });
  }
  return groups;
}

const isWhite = (d: RgbaImage['data'], i: number) => d[i] > 200 && d[i + 1] > 200 && d[i + 2] > 200;
const isBlack = (d: RgbaImage['data'], i: number) => d[i] < 60 && d[i + 1] < 60 && d[i + 2] < 60;

export interface ScaleBar {
  /** Rows of white margin at the bottom of the image. */
  marginRows: number;
  /** Length of the 100 m black line, in cells. */
  barCells: number;
  metersPerCell: number;
}

/**
 * Section 4.3: a white margin at the bottom holds a black line that is always 100 m.
 * Returns null when the image has no such margin.
 */
export function measureScaleBar(img: RgbaImage, barMeters = 100): ScaleBar | null {
  const { width, height, data } = img;
  let marginRows = 0;
  let barCells = 0;
  for (let y = height - 1; y >= 0; y--) {
    let white = 0;
    let run = 0;
    let longest = 0;
    let other = false;
    for (let x = 0; x < width; x++) {
      const i = (y * width + x) * 4;
      if (isWhite(data, i)) {
        white++;
        run = 0;
      } else if (isBlack(data, i)) {
        longest = Math.max(longest, ++run);
      } else {
        other = true;
        break;
      }
    }
    if (other || white < width / 2) break;
    marginRows++;
    barCells = Math.max(barCells, longest);
  }
  if (marginRows === 0 || barCells === 0) return null;
  return { marginRows, barCells, metersPerCell: barMeters / barCells };
}

export function cropBottom(img: RgbaImage, rows: number): RgbaImage {
  const height = img.height - rows;
  return { width: img.width, height, data: img.data.slice(0, img.width * height * 4) };
}

/**
 * Shrinks a grid by an integer factor, each output cell taking the most common
 * value of its block (e.g. 1024x1024 generator output -> 128x128).
 * Ties go to the lowest value so the result is deterministic.
 */
export function downsampleMajority(grid: Uint8Array, width: number, factor: number): Uint8Array {
  const height = grid.length / width;
  if (width % factor || height % factor) throw new Error(`${width}x${height} is not divisible by ${factor}`);
  const ow = width / factor, oh = height / factor;
  const out = new Uint8Array(ow * oh);
  const counts = new Uint32Array(256);
  for (let oy = 0; oy < oh; oy++) {
    for (let ox = 0; ox < ow; ox++) {
      counts.fill(0);
      for (let y = oy * factor; y < (oy + 1) * factor; y++) {
        for (let x = ox * factor; x < (ox + 1) * factor; x++) counts[grid[y * width + x]]++;
      }
      let best = 0;
      for (let v = 1; v < 256; v++) if (counts[v] > counts[best]) best = v;
      out[oy * ow + ox] = best;
    }
  }
  return out;
}
