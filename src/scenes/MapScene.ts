import Phaser from 'phaser';
import { CameraController } from '../input/CameraController';
import { buildGameMap } from '../sim/map/buildMap';
import type { GameMap, MapConfig } from '../sim/map/types';
import { Terrain } from '../sim/map/types';
import { drawTerrain } from '../render/drawTerrain';
import { imageToRgba } from '../render/imageToRgba';
import { DEV_STYLE } from '../render/stylePacks';
import type { StylePack } from '../render/stylePacks';

export interface MapSceneData {
  mapId: string;
}

export interface CursorInfo {
  map: GameMap;
  cell: { x: number; y: number } | null;
  zoom: number;
}

const TERRAIN_NAMES: Record<Terrain, string> = {
  [Terrain.Plain]: '平地',
  [Terrain.Forest]: '樹林',
  [Terrain.Road]: '道路',
  [Terrain.Water]: '水域',
  [Terrain.Building]: '建築',
  [Terrain.Poi]: '據點',
  [Terrain.EnemySpawn]: '敵方出兵區',
  [Terrain.PlayerSpawn]: '我方出兵區',
  [Terrain.Hq]: '總部',
  [Terrain.Bridge]: '橋梁',
  [Terrain.Ford]: '淺灘',
};
export const terrainName = (t: Terrain) => TERRAIN_NAMES[t];

export class MapScene extends Phaser.Scene {
  private mapId = 'hecheng';
  private style: StylePack = DEV_STYLE;
  private camCtl!: CameraController;
  private grid!: Phaser.GameObjects.Graphics;
  map!: GameMap;

  constructor() {
    super('map');
  }

  init(data: MapSceneData): void {
    if (data?.mapId) this.mapId = data.mapId;
  }

  preload(): void {
    const base = `maps/${this.mapId}/`;
    const cfgKey = `map-config-${this.mapId}`;
    this.load.json(cfgKey, `${base}map.json`);
    this.load.once(`filecomplete-json-${cfgKey}`, (_key: string, _type: string, cfg: MapConfig) => {
      this.load.image(`terrain-${this.mapId}`, base + cfg.files.terrain);
      if (cfg.files.height) this.load.image(`height-${this.mapId}`, base + cfg.files.height);
    });
  }

  create(): void {
    const cfg = this.cache.json.get(`map-config-${this.mapId}`) as MapConfig;
    const src = (key: string) => this.textures.get(key).getSourceImage() as HTMLImageElement;
    const heightKey = `height-${this.mapId}`;
    this.map = buildGameMap(
      cfg,
      imageToRgba(src(`terrain-${this.mapId}`)),
      this.textures.exists(heightKey) ? imageToRgba(src(heightKey)) : null,
    );
    if (this.map.unknownColors.length) {
      console.warn(`${cfg.id}: ${this.map.unknownColors.length} unrecognised colours`, this.map.unknownColors.slice(0, 20));
    }

    const s = this.style.cellPx;
    const worldW = this.map.width * s, worldH = this.map.height * s;
    const tex = this.textures.createCanvas(`terrain-layer-${this.mapId}`, worldW, worldH)!;
    drawTerrain(tex.getContext(), this.map, this.style);
    tex.refresh();
    this.add.image(0, 0, tex.key).setOrigin(0);

    this.drawMarkers();
    this.grid = this.drawGrid(worldW, worldH).setVisible(false);
    this.camCtl = new CameraController(this, worldW, worldH);

    const kb = this.input.keyboard!;
    kb.on('keydown-G', () => this.grid.setVisible(!this.grid.visible));
    kb.on('keydown-HOME', () => this.camCtl.fit());
    kb.on('keydown-F', () => this.camCtl.fit());

    this.scene.launch('hud');
  }

  update(_t: number, dt: number): void {
    this.camCtl.update(dt);
  }

  cursorInfo(): CursorInfo {
    const p = this.input.activePointer;
    const w = this.cameras.main.getWorldPoint(p.x, p.y);
    const s = this.style.cellPx;
    const x = Math.floor(w.x / s), y = Math.floor(w.y / s);
    const inside = x >= 0 && y >= 0 && x < this.map.width && y < this.map.height;
    return { map: this.map, cell: inside ? { x, y } : null, zoom: this.cameras.main.zoom };
  }

  private drawMarkers(): void {
    const s = this.style.cellPx;
    const g = this.add.graphics();
    for (const poi of this.map.pois) {
      const r = (Math.sqrt(poi.cells.length) / 2 + 0.6) * s;
      g.fillStyle(this.style.poiRing, 0.35).fillCircle(poi.center.x * s, poi.center.y * s, r);
      g.lineStyle(3, this.style.poiRing, 1).strokeCircle(poi.center.x * s, poi.center.y * s, r);
    }
    for (const hq of this.map.hqs) {
      const color = this.style.hq[hq.owner];
      const xs = hq.cells.map((c) => c.x), ys = hq.cells.map((c) => c.y);
      const x0 = Math.min(...xs) * s, y0 = Math.min(...ys) * s;
      const w = (Math.max(...xs) + 1) * s - x0, h = (Math.max(...ys) + 1) * s - y0;
      g.fillStyle(color, 1).fillRect(x0, y0, w, h);
      g.lineStyle(3, 0x111111, 1).strokeRect(x0, y0, w, h);
      g.lineStyle(2, 0xffffff, 0.9).strokeRect(x0 + 5, y0 + 5, w - 10, h - 10);
    }
  }

  private drawGrid(worldW: number, worldH: number): Phaser.GameObjects.Graphics {
    const s = this.style.cellPx;
    const g = this.add.graphics().lineStyle(1, this.style.grid, 0.18);
    for (let x = 0; x <= worldW; x += s) g.lineBetween(x, 0, x, worldH);
    for (let y = 0; y <= worldH; y += s) g.lineBetween(0, y, worldW, y);
    return g;
  }
}
