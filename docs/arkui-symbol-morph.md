# Symbol 图标形变（morphicons region morph 落地）

## 结论

`MorphIcon` 是通用双图标切换组件：传两个 `Resource` 图标和 `checked`，点击时在两者之间切换。
已登记形变几何的图标对走 Canvas 逐点形变，其余直接换图标。当前登记的是 `symbol_eye_off ↔ symbol_eye`。

眼睛这一对用的是 morphicons 的 **filled surface / region morph** 管线：对填充图标先取可见面闭合轮廓，
再逐点插值。官方的 Material Symbols eye → eye-off 示例也是这个效果——中间帧是「融化」形态，
不是描边图标的线条变形。

## 管线（与官方一致）

1. **提取可见面**：从 `symbol_all.ttf` 取两个字形的闭合轮廓，外轮廓与洞按相反绕向保留。
2. **重采样**：每个子路径按弧长均分 64 点，点 i 对 A 与点 i 对 B 一一对应。
3. **配对**：子路径按「质心距离 + 周长差」配对（4↔4 用全排列取总代价最小）；
   每个闭合子路径再遍历所有起点，取逐点平方误差最小的起点。
4. **对齐**：全局 Procrustes 解最优旋转与缩放

   ```
   θ* = atan2(Σ aₓbᵧ − aᵧbₓ,  Σ aₓbₓ + aᵧbᵧ)
   σ* = sqrt(Σ‖bᵢ‖² / Σ‖aᵢ‖²)
   ```

   本次结果：`θ = −8.53°`、`σ = 0.8737`。
5. **插值**：旋转、缩放、形状分开插，避免旋转在中间塌陷

   ```
   P(t) = c(t) + σ*^t · R(t·θ*) · [(1−t)·aᵢ + t·b̃ᵢ]
   ```

   `c(t)` 是质心线性插值，`b̃ᵢ` 是 B 变换回 A 坐标系后的点。

第 1–4 步离线完成（`tools/icon-migration/generate_morph_points.py`），运行时只算第 5 步。

## 端点一致性

| 端点 | 与字体字形 IoU |
|------|---------------|
| t=0（`symbol_eye_off`） | 0.993 |
| t=1（`symbol_eye`）     | 0.996 |

残差来自 64 点对曲线的多边形逼近，属亚像素级。

## 组成

| 文件 | 职责 |
|------|------|
| `tools/icon-migration/generate_morph_points.py` | 离线生成：轮廓提取、64 点重采样、子路径配对、Procrustes，写数据文件 |
| `components/morph/EyeMorphData.ets` | 生成产物，勿手改：两组点、质心、θ、σ |
| `components/morph/MorphShape.ets` | 形变契约：`draw(canvas, iconSize, color, progress)`，progress 0 = iconOff，1 = iconOn |
| `components/morph/EyeMorphShape.ets` | 按公式逐点插值并绘制（Canvas，`nonzero` 填充保留洞） |
| `components/morph/MorphRegistry.ets` | 图标对 → 形变几何的登记表 |
| `components/MorphIcon.ets` | 通用双图标组件：Canvas/帧驱动/颜色，未登记的对退回 `SymbolGlyph` |
| `components/IconToggleButton.ets` | 基于 `DsButton` 内容插槽的图标按钮，`symbolChecked` 有值时按 `checked` 切换 |

## 用法

```ets
IconToggleButton({
  symbol: $r('app.string.symbol_eye_off'),
  symbolChecked: $r('app.string.symbol_eye'),
  checked: this.passwordVisible,
  symbolColor: $r('app.color.ds_text_tertiary'),
  accessibilityLabel: this.passwordVisible ? $r('app.string.hide') : $r('app.string.show'),
  onToggle: () => this.passwordVisible = !this.passwordVisible,
})
```

## 运行期约束

- **尺寸单位**：`ResUtil.getNumber` 返回 px，`Canvas` 的宽高与坐标都是 vp，必须 `px2vp` 转换。
- **Canvas 重绘**：绘制内容不响应状态变量，必须让 `progress` 成为 `@Local` 并在 `@Monitor('progress')`
  里调 `draw()`；直接在 `displaySync` 帧回调里画，中间帧不会呈现。
- **帧驱动**：`displaySync` 逐帧回调，时长与曲线用项目通用过渡 `STATE_TRANSITION_DURATION`（300ms）+
  `STATE_TRANSITION_CURVE`，进度按该曲线的 `interpolate()` 求值。
- **首次绘制**：`onReady` 也会在尺寸变化时重入，用 `ready` 标记保证只定档一次，重入只重绘。
- **颜色**：`Canvas.fillStyle` 不吃 `ResourceColor`，用 `ColorUtil.withAlpha(color, 1)` 解析成 ARGB；
  Canvas 不跟随深浅色，监听 `colorMode.isDark` 重新解析并重绘。
- **按钮反馈**：`IconToggleButton` 直接把图标塞进 `DsButton` 的内容插槽（Text / Default / Small / `iconOnly`），
  按压 `ds_overlay_muted`、悬停 `ds_overlay_subtle`、300ms `EASE_STATE` 全部由 `DsButton` 提供。
- **插槽里的 `this`**：`contentBuilder` 的 builder 必须用 `@LocalBuilder` 声明并传方法引用；普通 `@Builder` 的
  `this` 会指向 `DsButton`，图标整块不渲染。详见 `docs/arkui-builder-slot.md`。
- **按钮尺寸**：输入框高 48vp，中号 44vp 会贴着上下边框，所以 `IconToggleButton` 用 `DsButtonSize.Small`（32vp）。

## 边界

- 只对已登记的图标对生效。新增对：在生成脚本里补字形、在 `MorphRegistry` 登记，不要用「先换图标再淡入」兜底。
- 填充图标只能走 region morph：拓扑不同的两个填充字形逐点插值必然是「融化」形态，官方 playground 同样如此，
  这不是实现缺陷。
- 不要在 Canvas 上再叠加 `SymbolGlyph` 做端点兜底：两套栅格化对不齐，反而暴露跳动。
