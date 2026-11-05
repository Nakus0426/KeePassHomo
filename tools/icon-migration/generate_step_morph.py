#!/usr/bin/env python3
"""为「步骤图标 → 对勾」生成逐点形变数据。

复用 generate_morph_points.py 的取样/匹配管线；对子路径数不一致的图标对
（步骤图标通常 2~4 条轮廓，对勾只有 1 条），把每个源轮廓都收拢到对勾轮廓，
保证 progress=0 显示完整图标、progress=1 全部重叠为对勾。

产物：products/default/src/main/ets/components/morph/StepMorphData.ets
用法：python tools/icon-migration/generate_step_morph.py [--preview]
"""

import math
import sys
from pathlib import Path

import numpy as np
from fontTools.ttLib import TTFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_morph_points as g

OUTPUT = g.ROOT / "products/default/src/main/ets/components/morph/StepMorphData.ets"

# (导出常量名, iconOff 资源键, iconOn 资源键)
PAIRS = [
    ("CLOUD_CHECK_MORPH", "symbol_cloud_sync", "symbol_check"),
    ("FOLDER_CHECK_MORPH", "symbol_folder", "symbol_check"),
    ("LOCK_CHECK_MORPH", "symbol_lock", "symbol_check"),
    ("FACT_CHECK_MORPH", "symbol_fact_check", "symbol_check"),
]


def build_plan_general(source, target):
    n = max(len(source), len(target))
    src = [source[min(i, len(source) - 1)] for i in range(n)]
    chosen = []
    for s in src:
        best = None
        for t in target:
            d = float(np.linalg.norm(s.mean(axis=0) - t.mean(axis=0))) + abs(g.perimeter(s) - g.perimeter(t))
            if best is None or d < best[0]:
                best = (d, t)
        chosen.append(best[1])
    source_points, target_points = [], []
    for i in range(n):
        shift, _ = g.best_shift(src[i], chosen[i])
        source_points.append(src[i])
        target_points.append(np.roll(chosen[i], -shift, axis=0))
    a = np.vstack(source_points)
    b = np.vstack(target_points)
    center_a, center_b = a.mean(axis=0), b.mean(axis=0)
    ap, bp = a - center_a, b - center_b
    cross = float((ap[:, 0] * bp[:, 1] - ap[:, 1] * bp[:, 0]).sum())
    dot = float((ap[:, 0] * bp[:, 0] + ap[:, 1] * bp[:, 1]).sum())
    theta = math.atan2(cross, dot)
    sigma = math.sqrt(float((bp ** 2).sum()) / float((ap ** 2).sum()))
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
        "subpath_count": n,
    }


def fmt_array(values):
    items = [f"{v:.2f}" for v in values]
    lines = ["    " + ", ".join(items[i:i + 10]) + "," for i in range(0, len(items), 10)]
    return "\n".join(lines)


def write_constant(name, plan):
    source = plan["source"].reshape(-1)
    target = plan["target"].reshape(-1)
    return f"""
export const {name}: StepMorphDataSpec = {{
  VIEW_BOX: {g.VIEW_BOX},
  SUBPATH_COUNT: {plan["subpath_count"]},
  SAMPLES_PER_SUBPATH: {g.SAMPLES},
  CENTER_FROM_X: {plan["center_source"][0]:.2f},
  CENTER_FROM_Y: {plan["center_source"][1]:.2f},
  CENTER_TO_X: {plan["center_target"][0]:.2f},
  CENTER_TO_Y: {plan["center_target"][1]:.2f},
  ROTATION: {plan["theta"]:.6f},
  SCALE: {plan["sigma"]:.6f},
  POINTS_FROM: [
{fmt_array(source)}
  ],
  POINTS_TO: [
{fmt_array(target)}
  ],
}}
"""


def main():
    cp = g.load_codepoints()
    font = TTFont(g.FONT)
    glyf = font["glyf"]
    cmap = font.getBestCmap()

    blocks = []
    for const_name, off, on in PAIRS:
        source = [g.resample(c) for c in g.region_contours(glyf[cmap[cp[off]]], glyf)]
        target = [g.resample(c) for c in g.region_contours(glyf[cmap[cp[on]]], glyf)]
        plan = build_plan_general(source, target)
        blocks.append(write_constant(const_name, plan))
        print(const_name, "subpaths", plan["subpath_count"], "theta", round(math.degrees(plan["theta"]), 1),
              "sigma", round(plan["sigma"], 3))
        if "--preview" in sys.argv:
            out = Path(g.ROOT) / ".screenshots"
            out.mkdir(exist_ok=True)
            g.preview(plan, out)
            src = out / "morph_points_preview.png"
            if src.exists():
                src.replace(out / f"step_{off.replace('symbol_', '')}.png")

    header = ("// 由 tools/icon-migration/generate_step_morph.py 从 symbol_all.ttf 生成，勿手改。\n"
              "// 步骤图标 -> 对勾的逐点形变数据；progress 0 = 步骤图标，1 = 对勾。\n"
              "import { StepMorphDataSpec } from './StepMorphShape'\n")
    OUTPUT.write_text(header + "".join(blocks), encoding="utf-8")
    print("wrote", OUTPUT, OUTPUT.stat().st_size, "B")


if __name__ == "__main__":
    main()
