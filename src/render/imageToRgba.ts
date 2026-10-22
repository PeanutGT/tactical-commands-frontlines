import type { RgbaImage } from '../sim/map/types';

/** Reads the pixels of a loaded browser image. */
export function imageToRgba(img: HTMLImageElement | HTMLCanvasElement): RgbaImage {
  const canvas = document.createElement('canvas');
  canvas.width = img.width;
  canvas.height = img.height;
  const ctx = canvas.getContext('2d', { willReadFrequently: true })!;
  ctx.drawImage(img, 0, 0);
  const { data } = ctx.getImageData(0, 0, img.width, img.height);
  return { width: img.width, height: img.height, data };
}
