"""Turns the generated terrain pictures into game textures.

Usage: python3 tools/prepare_terrain.py <art_src dir> art/terrain

Each source is 1024 px for 8 cells. Large brightness gradients are flattened
(so the texture does not visibly repeat every 8 cells), the edges are blended
with a half-offset copy so it tiles without seams, and the result is saved at
OUT_PX. Needs Pillow and numpy.
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

NAMES = ["plain", "forest", "road", "water", "building", "bridge", "ford"]
OUT_PX = 512
# Blur radius (px of the 1024 source) that counts as "gradient", per texture;
# busy textures keep more of their own shading.
FLATTEN = {"plain": 120, "forest": 160, "road": 50, "water": 50, "building": 200, "bridge": 120, "ford": 70}
# Width of the cross-fade band at each edge, as a share of the size.
BLEND = 0.3


def flatten(img: np.ndarray, radius: int) -> np.ndarray:
    pil = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    # Wrap so the blur near an edge sees the opposite edge.
    h, w = img.shape[:2]
    tiled = Image.new("RGB", (w * 3, h * 3))
    for x in range(3):
        for y in range(3):
            tiled.paste(pil, (x * w, y * h))
    low = np.asarray(tiled.filter(ImageFilter.GaussianBlur(radius)), dtype=np.float32)[h:2 * h, w:2 * w]
    mean = img.reshape(-1, 3).mean(axis=0)
    return img / np.maximum(low, 1.0) * mean


def make_seamless(img: np.ndarray) -> np.ndarray:
    # One axis at a time: cross-fade with a copy rolled by half along that
    # axis, taking the copy near the edges (where it is continuous) and the
    # original in the middle (where the copy has its own seam).
    for axis in (0, 1):
        n = img.shape[axis]
        rolled = np.roll(img, n // 2, axis=axis)
        d = np.minimum(np.arange(n), np.arange(n)[::-1]) / (n * BLEND)
        m = np.clip(d, 0.0, 1.0)
        m = m * m * (3 - 2 * m)
        m = m[:, None, None] if axis == 0 else m[None, :, None]
        img = img * m + rolled * (1 - m)
    return img


def main(src: str, out: str) -> None:
    for n in NAMES:
        img = np.asarray(Image.open(f"{src}/terrain_{n}.png").convert("RGB"), dtype=np.float32)
        img = make_seamless(flatten(img, FLATTEN[n]))
        Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize((OUT_PX, OUT_PX), Image.LANCZOS).save(f"{out}/{n}.png", optimize=True)
        print(n)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
