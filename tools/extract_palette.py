"""Extract a shared colour palette from the art reference images (DESIGN.md §9.2).

Runs k-means over pixels sampled from every image in the reference folder and
prints the cluster centres sorted by luminance, plus a swatch PNG for review.

Usage:
    python tools/extract_palette.py [--src Inspo] [--k 24] [--out tools/palette_swatch.png]
"""
import os
os.environ.setdefault("LOKY_MAX_CPU_COUNT", "4")

import argparse
import colorsys
import glob

import numpy as np
from PIL import Image, ImageDraw
from sklearn.cluster import KMeans

SAMPLES_PER_IMAGE = 20000


def load_pixels(path, rng):
    img = Image.open(path).convert("RGB")
    img.thumbnail((400, 400))
    px = np.asarray(img, dtype=np.float32).reshape(-1, 3)
    if len(px) > SAMPLES_PER_IMAGE:
        px = px[rng.choice(len(px), SAMPLES_PER_IMAGE, replace=False)]
    return px


def luminance(rgb):
    r, g, b = rgb / 255.0
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def to_hex(rgb):
    return "#{:02x}{:02x}{:02x}".format(*(int(round(c)) for c in rgb))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="Inspo")
    ap.add_argument("--k", type=int, default=24)
    ap.add_argument("--out", default="tools/palette_swatch.png")
    args = ap.parse_args()

    files = sorted(glob.glob(os.path.join(args.src, "*.jpg")) + glob.glob(os.path.join(args.src, "*.png")))
    if not files:
        raise SystemExit(f"No images found in {args.src}")

    rng = np.random.default_rng(42)
    pixels = np.concatenate([load_pixels(f, rng) for f in files])
    km = KMeans(n_clusters=args.k, n_init=4, random_state=42).fit(pixels)
    counts = np.bincount(km.labels_, minlength=args.k)
    centres = km.cluster_centers_

    order = sorted(range(args.k), key=lambda i: luminance(centres[i]))
    print(f"{len(files)} images, {len(pixels)} pixels, k={args.k}")
    print(f"{'hex':8}  {'share':>6}  {'lum':>5}  {'hue':>4}  {'sat':>4}")
    for i in order:
        h, l, s = colorsys.rgb_to_hls(*(centres[i] / 255.0))
        print(f"{to_hex(centres[i])}  {counts[i] / len(pixels):6.1%}  {luminance(centres[i]):5.2f}  {h * 360:4.0f}  {s:4.2f}")

    sw = 48
    swatch = Image.new("RGB", (sw * args.k, sw))
    draw = ImageDraw.Draw(swatch)
    for n, i in enumerate(order):
        draw.rectangle([n * sw, 0, (n + 1) * sw, sw], fill=tuple(int(c) for c in centres[i]))
    swatch.save(args.out)
    print(f"Swatch written to {args.out}")


if __name__ == "__main__":
    main()
