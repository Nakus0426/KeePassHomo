# 图标资源生成

两个脚本，后者依赖前者的产物：

1. `generate_symbols.py`：按 `mapping.json` 从 Material Symbols Outlined 抽取字形，产出
   `products/default/src/main/resources/rawfile/symbol/symbol_all.ttf`、`symbol_all.json`
   与 `products/default/src/main/resources/base/element/string_symbols.json`。
2. `generate_morph_points.py`：按 morphicons 的 region morph 管线，从 `symbol_all.ttf` 的
   `symbol_eye` / `symbol_eye_off` 字形生成逐点形变数据，产出
   `products/default/src/main/ets/components/morph/EyeMorphData.ets`。
3. `generate_step_morph.py`：同一管线，为步骤图标 → 对勾生成形变数据，产出
   `products/default/src/main/ets/components/morph/StepMorphData.ets`。子路径数不一致时把每个源轮廓收拢到对勾轮廓。

## 用法

```bash
pip install fonttools
python tools/icon-migration/generate_symbols.py
python tools/icon-migration/generate_morph_points.py
python tools/icon-migration/generate_step_morph.py
```

`generate_morph_points.py --preview` 会额外输出 t=0 / 0.5 / 0.8 / 1 的对照图到 `.screenshots/`。

首次运行会从 `google/material-design-icons` 下载 Material Symbols Outlined 可变字体到 `.cache/`，该目录不提交。

`mapping.json` 的 `key` 是应用语义资源键，`material` 是 Material Symbols 名称，`fill` 为 0 或 1。修改映射后重跑脚本即可；
字形或字重变化会影响形变几何，需一并重跑 `generate_morph_points.py`。
