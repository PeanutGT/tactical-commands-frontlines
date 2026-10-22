import Phaser from 'phaser';
import { MapScene, terrainName } from './MapScene';
import type { Terrain } from '../sim/map/types';

/** Screen-space debug overlay: map info and the cell under the cursor. */
export class HudScene extends Phaser.Scene {
  private text!: Phaser.GameObjects.Text;
  private help!: Phaser.GameObjects.Text;

  constructor() {
    super('hud');
  }

  create(): void {
    const style = {
      fontFamily: 'system-ui, "Noto Sans TC", "Microsoft JhengHei", sans-serif',
      fontSize: '14px',
      color: '#e8ecdf',
      backgroundColor: 'rgba(16,20,14,0.72)',
      padding: { x: 10, y: 8 },
    };
    this.text = this.add.text(12, 12, '', style);
    this.help = this.add
      .text(12, 0, '滾輪縮放｜中鍵或空白鍵+左鍵拖曳平移｜WASD／方向鍵／邊緣捲動｜G 格線｜F 全圖\n手機：單指拖曳平移｜雙指縮放', {
        ...style,
        fontSize: '12px',
        color: '#c4c9b8',
      });
    this.layout();
    this.scale.on('resize', this.layout, this);
  }

  private layout(): void {
    this.help.setY(this.scale.height - this.help.height - 12);
  }

  update(): void {
    const mapScene = this.scene.get('map') as MapScene;
    if (!mapScene.map) return;
    const { map, cell, zoom } = mapScene.cursorInfo();
    const c = map.config;
    const lines = [
      `${c.name}  ${map.width}×${map.height} 格｜${c.metersPerCell} 公尺/格｜縮放 ${zoom.toFixed(2)}`,
    ];
    if (cell) {
      const i = cell.y * map.width + cell.x;
      lines.push(`(${cell.x}, ${cell.y})  ${terrainName(map.terrain[i] as Terrain)}｜高度 ${map.elevation[i]}`);
    }
    this.text.setText(lines);
  }
}
