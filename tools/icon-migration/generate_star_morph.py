#!/usr/bin/env python3
"""为「收藏星形 -> 实心星」生成逐点形变数据。

复用 generate_morph_points.py 的轮廓提取与重采样；实心星只有外轮廓，
按 morphicons region 规则让星形内孔收拢到质心，外轮廓保持不动。
产物：products/default/src/main/ets/components/morph/StarMorphData.ets
用法：python tools/icon-migration/generate_star_morph.py
"""

import sys
from pathlib import Path

import numpy as np
from fontTools.ttLib import TTFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_morph_points as g

OUTPUT = g.ROOT / "products/default/src/main/ets/components/morph/StarMorphData.ets"
SOURCE_KEY = "symbol_star"
TARGET_KEY = "symbol_star_filled"


def split_contours(contours):
    outer = max(contours, key=lambda contour: abs(g.signed_area(contour)))
    holes = [contour for contour in contours if contour is not outer and g.signed_area(contour) < 0]
    return outer, holes


def build_plan(source_contours, target_contours):
    source_outer, source_holes = split_contours(source_contours)
    target_outer, _ = split_contours(target_contours)
    if len(source_holes) != 1:
        raise ValueError("星形形变假定未选中态只有一个内孔")
    if not np.allclose(source_outer, target_outer, atol=0.01):
        raise ValueError("星形与实心星的外轮廓不一致，不能共用外轮廓数据")

    center = source_outer.mean(axis=0)
    hole = source_holes[0]
    source = np.vstack([hole, source_outer]) - center
    target = np.vstack([np.tile(hole.mean(axis=0), (g.SAMPLES, 1)), target_outer]) - center
    return {
        "source": source,
        "target": target,
        "center": center,
        "subpath_count": 2,
    }


def fmt_array(values):
    items = [f"{value:.2f}" for value in values]
    lines = ["    " + ", ".join(items[i:i + 10]) + "," for i in range(0, len(items), 10)]
    return "\n".join(lines)


def write_data(plan):
    source = plan["source"].reshape(-1)
    target = plan["target"].reshape(-1)
    content = f"""// 由 tools/icon-migration/generate_star_morph.py 从 symbol_all.ttf 生成，勿手改。
// 收藏星形 -> 实心星：外轮廓不动，内孔收拢到质心；progress 0 = symbol_star，1 = symbol_star_filled。
import {{ StepMorphDataSpec }} from './StepMorphShape'

export const STAR_FILLED_MORPH: StepMorphDataSpec = {{
  VIEW_BOX: {g.VIEW_BOX},
  SUBPATH_COUNT: {plan["subpath_count"]},
  SAMPLES_PER_SUBPATH: {g.SAMPLES},
  CENTER_FROM_X: {plan["center"][0]:.2f},
  CENTER_FROM_Y: {plan["center"][1]:.2f},
  CENTER_TO_X: {plan["center"][0]:.2f},
  CENTER_TO_Y: {plan["center"][1]:.2f},
  ROTATION: 0.000000,
  SCALE: 1.000000,
  POINTS_FROM: [
{fmt_array(source)}
  ],
  POINTS_TO: [
{fmt_array(target)}
  ],
}}
"""
    OUTPUT.write_text(content, encoding="utf-8")


def main():
    codepoints = g.load_codepoints()
    font = TTFont(g.FONT)
    glyf = font["glyf"]
    cmap = font.getBestCmap()
    source = [np.array(g.resample(c)) for c in g.region_contours(glyf[cmap[codepoints[SOURCE_KEY]]], glyf)]
    target = [np.array(g.resample(c)) for c in g.region_contours(glyf[cmap[codepoints[TARGET_KEY]]], glyf)]
    plan = build_plan(source, target)
    write_data(plan)
    print(f"wrote {OUTPUT} {OUTPUT.stat().st_size} B")


if __name__ == "__main__":
    main()
