import { readFileSync } from 'node:fs';
import { PNG } from 'pngjs';
import type { RgbaImage } from '../src/sim/map/types';

/** Builds an image from rows of single-character keys mapped to colours. */
export function imageFromRows(rows: string[], colors: Record<string, [number, number, number]>): RgbaImage {
  const width = rows[0].length, height = rows.length;
  const data = new Uint8Array(width * height * 4);
  rows.forEach((row, y) =>
    [...row].forEach((ch, x) => {
      const [r, g, b] = colors[ch];
      data.set([r, g, b, 255], (y * width + x) * 4);
    }),
  );
  return { width, height, data };
}

export function readPng(path: string): RgbaImage {
  const png = PNG.sync.read(readFileSync(path));
  return { width: png.width, height: png.height, data: png.data };
}
