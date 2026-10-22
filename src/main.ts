import Phaser from 'phaser';
import { HudScene } from './scenes/HudScene';
import { MapScene } from './scenes/MapScene';

const parent = document.getElementById('game')!;

/** WebGL framebuffers fail at boot if the parent is 0x0, so wait until it has a size. */
function start(): void {
  if (parent.clientWidth === 0 || parent.clientHeight === 0) {
    requestAnimationFrame(start);
    return;
  }
  new Phaser.Game({
    type: Phaser.AUTO,
    parent,
    backgroundColor: '#14180f',
    pixelArt: true,
    scale: { mode: Phaser.Scale.RESIZE, width: parent.clientWidth, height: parent.clientHeight },
    input: { activePointers: 3 },
    scene: [MapScene, HudScene],
  });
}

start();
