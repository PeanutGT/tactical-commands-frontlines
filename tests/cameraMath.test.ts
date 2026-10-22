import { describe, expect, it } from 'vitest';
import { fitZoom, scrollForZoomAt } from '../src/input/cameraMath';

const worldAt = (scroll: number, view: number, zoom: number, screen: number) =>
  scroll + view / 2 + (screen - view / 2) / zoom;

describe('scrollForZoomAt', () => {
  it('keeps the world point under the cursor fixed while zooming', () => {
    const before = worldAt(100, 800, 1, 650);
    const scroll = scrollForZoomAt(100, 800, 1, 2.5, 650);
    expect(worldAt(scroll, 800, 2.5, 650)).toBeCloseTo(before);
  });

  it('does not move the camera when zooming at the viewport centre', () => {
    expect(scrollForZoomAt(100, 800, 1, 3, 400)).toBeCloseTo(100);
  });
});

describe('fitZoom', () => {
  it('uses the tighter axis', () => {
    expect(fitZoom(1600, 900, 2048, 2048)).toBeCloseTo(900 / 2048);
  });
});
