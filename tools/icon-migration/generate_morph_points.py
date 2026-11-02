#!/usr/bin/env python3
"""按 morphicons 的 region morph 管线，为眼睛图标对生成逐点形变数据。

管线：提取可见面轮廓 -> 每个子路径按弧长重采样 64 点 -> 子路径配对（位置+长度，
尝试全部起点）-> Procrustes 求全局旋转 θ 与缩放 σ -> 输出运行时插值所需数据。
"""

import itertools
import json
import math
import sys
from pathlib import Path

import numpy as np
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[2]
FONT = ROOT / "products/default/src/main/resources/rawfile/symbol/symbol_all.ttf"
STRINGS = ROOT / "products/default/src/main/resources/base/element/string_symbols.json"
OUTPUT = ROOT / "products/default/src/main/ets/components/morph/EyeMorphData.ets"

SAMPLES = 64
MIN_AREA = 100
VIEW_BOX = 960


def load_codepoints():
    data = json.loads(STRINGS.read_text(encoding="utf-8"))
    return {item["name"]: int(item["value"], 16) for item in data["string"]}


def flatten_contours(glyph, glyf):
    coords, ends, flags = glyph.getCoordinates(glyf)
    contours, start = [], 0
    for end in ends:
        raw = [(float(coords[i][0]), float(coords[i][1]), bool(flags[i] & 1)) for i in range(start, end + 1)]
        start = end + 1
        n = len(raw)
        seq = []
        for i in range(n):
            x, y, on = raw[i]
            seq.append((x, y, on))
            nx, ny, next_on = raw[(i + 1) % n]
            if not on and not next_on:
                seq.append(((x + nx) / 2, (y + ny) / 2, True))
        first = next(i for i, p in enumerate(seq) if p[2])
        seq = seq[first:] + seq[:first]
        poly = [seq[0][:2]]
        current = seq[0][:2]
        i = 1
        while i < len(seq):
            x, y, on = seq[i]
            if on:
                poly.append((x, y))
                current = (x, y)
                i += 1
                continue
            nx, ny, _ = seq[(i + 1) % len(seq)]
            for step in range(1, 13):
                t = step / 12
                poly.append((
                    (1 - t) ** 2 * current[0] + 2 * (1 - t) * t * x + t ** 2 * nx,
                    (1 - t) ** 2 * current[1] + 2 * (1 - t) * t * y + t ** 2 * ny,
                ))
            current = (nx, ny)
            i += 2
        contours.append(poly)
    return contours


def signed_area(poly):
    total = 0.0
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % len(poly)]
        total += x1 * y2 - x2 * y1
    return total / 2


def region_contours(glyph, glyf):
    """可见面轮廓；字体坐标 y 向上，这里翻成画布坐标 y 向下。"""
    result = []
    for poly in flatten_contours(glyph, glyf):
        if abs(signed_area(poly)) < MIN_AREA:
            continue
        result.append([(x, VIEW_BOX - y) for x, y in poly])
    return result


def resample(poly, samples=SAMPLES):
    pts = np.array(poly + [poly[0]], dtype=float)
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    total = seg.sum()
    acc = np.concatenate([[0.0], np.cumsum(seg)])
    out = np.empty((samples, 2), dtype=float)
    for k in range(samples):
        target = total * k / samples
        i = min(int(np.searchsorted(acc, target, side="right") - 1), len(seg) - 1)
        t = (target - acc[i]) / seg[i]
        out[k] = pts[i] + t * (pts[i + 1] - pts[i])
    return out


def perimeter(poly):
    pts = np.vstack([poly, poly[:1]])
    return float(np.linalg.norm(np.diff(pts, axis=0), axis=1).sum())


def best_shift(a, b):
    """闭合路径：找使 |a - roll(b)|² 最小的起点。"""
    best_error, best_shift_index = float("inf"), 0
    for k in range(len(b)):
        rolled = np.roll(b, -k, axis=0)
        error = float(((a - rolled) ** 2).sum())
        if error < best_error:
            best_error, best_shift_index = error, k
    return best_shift_index, best_error


def match_subpaths(source, target):
    cost = {}
    for i, a in enumerate(source):
        for j, b in enumerate(target):
            distance = float(np.linalg.norm(a.mean(axis=0) - b.mean(axis=0)))
            cost[(i, j)] = distance + abs(perimeter(a) - perimeter(b))
    count = min(len(source), len(target))
    best = None
    for perm in itertools.permutations(range(len(target)), count):
        total = sum(cost[(i, perm[i])] for i in range(count))
        if best is None or total < best[0]:
            best = (total, perm)
    if best is None:
        raise ValueError("子路径无法配对")
    return [(i, best[1][i]) for i in range(count)]


def build_plan(source, target):
    pairs = match_subpaths(source, target)
    source_points, target_points = [], []
    for i, j in pairs:
        shift, _ = best_shift(source[i], target[j])
        source_points.append(source[i])
        target_points.append(np.roll(target[j], -shift, axis=0))
    a = np.vstack(source_points)
    b = np.vstack(target_points)

    center_a, center_b = a.mean(axis=0), b.mean(axis=0)
    ap, bp = a - center_a, b - center_b
    cross = float((ap[:, 0] * bp[:, 1] - ap[:, 1] * bp[:, 0]).sum())
    dot = float((ap[:, 0] * bp[:, 0] + ap[:, 1] * bp[:, 1]).sum())
    theta = math.atan2(cross, dot)
    sigma = math.sqrt(float((bp ** 2).sum()) / float((ap ** 2).sum()))

    # 把 target 归一到 source 坐标系
    cos_t, sin_t = math.cos(-theta), math.sin(-theta)
    normalized = np.empty_like(bp)
    normalized[:, 0] = (cos_t * bp[:, 0] - sin_t * bp[:, 1]) / sigma
    normalized[:, 1] = (sin_t * bp[:, 0] + cos_t * bp[:, 1]) / sigma
    return {
        "source": ap,
        "target": normalized,
        "center_source": center_a,
        "center_target": center_b,
        "theta": theta,
        "sigma": sigma,
        "subpath_count": len(pairs),
    }


def frame(plan, t):
    cos_t, sin_t = math.cos(t * plan["theta"]), math.sin(t * plan["theta"])
    scale = plan["sigma"] ** t
    center = plan["center_source"] + (plan["center_target"] - plan["center_source"]) * t
    points = (1 - t) * plan["source"] + t * plan["target"]
    x = scale * (cos_t * points[:, 0] - sin_t * points[:, 1]) + center[0]
    y = scale * (sin_t * points[:, 0] + cos_t * points[:, 1]) + center[1]
    return np.column_stack([x, y])


def write_data(plan):
    def fmt(values):
        items = [f"{v:.2f}" for v in values]
        lines = ["    " + ", ".join(items[i:i + 10]) + "," for i in range(0, len(items), 10)]
        return "\n".join(lines)

    source = plan["source"].reshape(-1)
    target = plan["target"].reshape(-1)
    content = f"""// 由 tools/icon-migration/generate_morph_points.py 从 symbol_all.ttf 生成，勿手改。
// 逐点形变：progress 0 = symbol_eye_off，1 = symbol_eye，公式见 docs/arkui-symbol-morph.md
export class EyeMorphData {{
  static readonly VIEW_BOX: number = {VIEW_BOX}
  static readonly SUBPATH_COUNT: number = {plan["subpath_count"]}
  static readonly SAMPLES_PER_SUBPATH: number = {SAMPLES}
  static readonly CENTER_FROM_X: number = {plan["center_source"][0]:.2f}
  static readonly CENTER_FROM_Y: number = {plan["center_source"][1]:.2f}
  static readonly CENTER_TO_X: number = {plan["center_target"][0]:.2f}
  static readonly CENTER_TO_Y: number = {plan["center_target"][1]:.2f}
  static readonly ROTATION: number = {plan["theta"]:.6f}
  static readonly SCALE: number = {plan["sigma"]:.6f}

  static readonly POINTS_FROM: number[] = [
{fmt(source)}
  ]

  static readonly POINTS_TO: number[] = [
{fmt(target)}
  ]
}}
"""
    OUTPUT.write_text(content, encoding="utf-8")


def preview(plan, directory):
    from PIL import Image

    def raster(points, width=480):
        scale = width / VIEW_BOX
        img = np.zeros((width, width), np.float32)
        edges = []
        for index in range(plan["subpath_count"]):
            poly = points[index * SAMPLES:(index + 1) * SAMPLES]
            for i in range(len(poly)):
                x1, y1 = poly[i]
                x2, y2 = poly[(i + 1) % len(poly)]
                if y1 != y2:
                    edges.append((x1, y1, x2, y2))
        for row in range(width):
            fy = (row + 0.5) / scale
            xs = []
            for x1, y1, x2, y2 in edges:
                if (y1 <= fy < y2) or (y2 <= fy < y1):
                    xs.append((x1 + (fy - y1) / (y2 - y1) * (x2 - x1), 1 if y2 > y1 else -1))
            xs.sort()
            wind = 0
            for i in range(len(xs) - 1):
                wind += xs[i][1]
                if wind != 0:
                    a = max(0, int(xs[i][0] * scale))
                    b = min(width, int(xs[i + 1][0] * scale) + 1)
                    if b > a:
                        img[row, a:b] = 1.0
        return img

    tiles = [raster(frame(plan, t)) for t in (0.0, 0.5, 0.8, 1.0)]
    directory.mkdir(parents=True, exist_ok=True)
    Image.fromarray(((1 - np.hstack(tiles)) * 255).astype(np.uint8)).save(directory / "morph_points_preview.png")
    print(f"preview -> {directory / 'morph_points_preview.png'}")


def main():
    codepoints = load_codepoints()
    font = TTFont(FONT)
    glyf = font["glyf"]
    cmap = font.getBestCmap()
    source = [resample(c) for c in region_contours(glyf[cmap[codepoints["symbol_eye_off"]]], glyf)]
    target = [resample(c) for c in region_contours(glyf[cmap[codepoints["symbol_eye"]]], glyf)]
    plan = build_plan(source, target)
    write_data(plan)
    print(f"subpaths={plan['subpath_count']} theta={math.degrees(plan['theta']):.2f} "
          f"sigma={plan['sigma']:.4f} size={OUTPUT.stat().st_size} B")
    if "--preview" in sys.argv:
        preview(plan, ROOT / ".screenshots")


if __name__ == "__main__":
    main()
