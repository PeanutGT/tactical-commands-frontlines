import Phaser from 'phaser';
import { clamp, fitZoom, scrollForZoomAt } from './cameraMath';

const MAX_ZOOM = 4;
const KEY_PAN_SPEED = 900; // screen px per second
const EDGE_PX = 14;
const EDGE_PAN_SPEED = 800;
/** A touch must move this far before it counts as a pan (keeps taps free for selection in M2). */
const TOUCH_PAN_THRESHOLD = 8;

/**
 * Camera pan and zoom.
 * PC: wheel zoom at cursor; middle-drag or Space+left-drag pan; WASD/arrows; edge scroll.
 * Touch: one-finger drag pan; two-finger pinch zoom and pan.
 * Left click/drag and right click are left free for selection and orders (M2).
 */
export class CameraController {
  private cam: Phaser.Cameras.Scene2D.Camera;
  private keys: Record<string, Phaser.Input.Keyboard.Key>;
  private dragging: { pointerId: number; x: number; y: number; moved: boolean } | null = null;
  private pinch: { dist: number; midX: number; midY: number } | null = null;
  private pointerInside = false;

  constructor(private scene: Phaser.Scene, private worldW: number, private worldH: number) {
    this.cam = scene.cameras.main;
    scene.input.addPointer(1); // two touch points for pinch
    scene.input.mouse?.disableContextMenu();

    const kb = scene.input.keyboard!;
    this.keys = kb.addKeys('W,A,S,D,UP,DOWN,LEFT,RIGHT,SPACE') as Record<string, Phaser.Input.Keyboard.Key>;

    scene.input.on('wheel', this.onWheel, this);
    scene.input.on('pointerdown', this.onDown, this);
    scene.input.on('pointermove', this.onMove, this);
    scene.input.on('pointerup', this.onUp, this);
    scene.input.on('pointerupoutside', this.onUp, this);
    scene.input.on('gameover', () => (this.pointerInside = true));
    scene.input.on('gameout', () => (this.pointerInside = false));
    scene.scale.on('resize', () => this.setZoom(Math.max(this.cam.zoom, this.minZoom())));

    this.fit();
  }

  /**
   * Phaser pins the world to the top-left when it is smaller than the view,
   * so pad the bounds on that axis to keep the map centred instead.
   */
  private setZoom(z: number): void {
    const cam = this.cam;
    cam.setZoom(z);
    const padX = Math.max(0, (cam.width / z - this.worldW) / 2);
    const padY = Math.max(0, (cam.height / z - this.worldH) / 2);
    cam.setBounds(-padX, -padY, this.worldW + padX * 2, this.worldH + padY * 2);
  }

  minZoom(): number {
    return fitZoom(this.cam.width, this.cam.height, this.worldW, this.worldH) * 0.9;
  }

  fit(): void {
    this.setZoom(fitZoom(this.cam.width, this.cam.height, this.worldW, this.worldH));
    this.cam.centerOn(this.worldW / 2, this.worldH / 2);
  }

  zoomAt(nextZoom: number, screenX: number, screenY: number): void {
    const cam = this.cam;
    const z = clamp(nextZoom, this.minZoom(), MAX_ZOOM);
    cam.scrollX = scrollForZoomAt(cam.scrollX, cam.width, cam.zoom, z, screenX);
    cam.scrollY = scrollForZoomAt(cam.scrollY, cam.height, cam.zoom, z, screenY);
    this.setZoom(z);
  }

  panScreen(dx: number, dy: number): void {
    this.cam.scrollX -= dx / this.cam.zoom;
    this.cam.scrollY -= dy / this.cam.zoom;
  }

  update(dtMs: number): void {
    const dt = dtMs / 1000;
    const k = this.keys;
    let vx = 0, vy = 0;
    if (k.A.isDown || k.LEFT.isDown) vx -= 1;
    if (k.D.isDown || k.RIGHT.isDown) vx += 1;
    if (k.W.isDown || k.UP.isDown) vy -= 1;
    if (k.S.isDown || k.DOWN.isDown) vy += 1;
    let speed = KEY_PAN_SPEED;

    const p = this.scene.input.activePointer;
    if (vx === 0 && vy === 0 && this.pointerInside && !p.wasTouch && !this.dragging) {
      if (p.x < EDGE_PX) vx = -1;
      else if (p.x > this.cam.width - EDGE_PX) vx = 1;
      if (p.y < EDGE_PX) vy = -1;
      else if (p.y > this.cam.height - EDGE_PX) vy = 1;
      speed = EDGE_PAN_SPEED;
    }
    if (vx || vy) this.panScreen(-vx * speed * dt, -vy * speed * dt);
  }

  private onWheel(_p: Phaser.Input.Pointer, _over: unknown, _dx: number, dy: number): void {
    const p = this.scene.input.activePointer;
    this.zoomAt(this.cam.zoom * Math.pow(1.0015, -dy), p.x, p.y);
  }

  private touches(): Phaser.Input.Pointer[] {
    return this.scene.input.manager.pointers.filter((p) => p.isDown && p.wasTouch);
  }

  private onDown(p: Phaser.Input.Pointer): void {
    if (p.wasTouch) {
      const t = this.touches();
      if (t.length >= 2) {
        this.dragging = null;
        this.pinch = this.pinchState(t[0], t[1]);
      } else {
        this.dragging = { pointerId: p.id, x: p.x, y: p.y, moved: false };
      }
      return;
    }
    if (p.middleButtonDown() || (p.leftButtonDown() && this.keys.SPACE.isDown)) {
      this.dragging = { pointerId: p.id, x: p.x, y: p.y, moved: true };
    }
  }

  private onMove(p: Phaser.Input.Pointer): void {
    if (this.pinch) {
      const t = this.touches();
      if (t.length < 2) return;
      const next = this.pinchState(t[0], t[1]);
      this.panScreen(next.midX - this.pinch.midX, next.midY - this.pinch.midY);
      this.zoomAt(this.cam.zoom * (next.dist / this.pinch.dist), next.midX, next.midY);
      this.pinch = next;
      return;
    }
    const d = this.dragging;
    if (!d || d.pointerId !== p.id) return;
    if (!d.moved && Math.hypot(p.x - d.x, p.y - d.y) < TOUCH_PAN_THRESHOLD) return;
    d.moved = true;
    this.panScreen(p.x - d.x, p.y - d.y);
    d.x = p.x;
    d.y = p.y;
  }

  private onUp(p: Phaser.Input.Pointer): void {
    if (this.pinch && this.touches().length < 2) this.pinch = null;
    if (this.dragging?.pointerId === p.id) this.dragging = null;
  }

  private pinchState(a: Phaser.Input.Pointer, b: Phaser.Input.Pointer) {
    return {
      dist: Math.max(1, Math.hypot(a.x - b.x, a.y - b.y)),
      midX: (a.x + b.x) / 2,
      midY: (a.y + b.y) / 2,
    };
  }
}
