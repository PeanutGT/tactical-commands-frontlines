/**
 * Section 4.3: unit stats are stored in metres and converted per map.
 * Range, vision, speed and effect radius scale; HP, damage, cost, weight,
 * cooldowns and supply do not. There is no minimum-range floor.
 */

/** The doc's tables are written for 1 cell = 20 m. */
export const STANDARD_METERS_PER_CELL = 20;

export const metersToCells = (meters: number, metersPerCell: number) => meters / metersPerCell;

/** Doc table value (cells at 20 m/cell) to metres. */
export const standardCellsToMeters = (cells: number) => cells * STANDARD_METERS_PER_CELL;

export interface DistanceStats {
  /** All in metres (speed in m/s). */
  range: number;
  vision: number;
  speed: number;
  radius?: number;
}

export function toMapCells(stats: DistanceStats, metersPerCell: number): DistanceStats {
  const c = (m: number) => metersToCells(m, metersPerCell);
  return {
    range: c(stats.range),
    vision: c(stats.vision),
    speed: c(stats.speed),
    ...(stats.radius !== undefined ? { radius: c(stats.radius) } : {}),
  };
}
