# 底部固定操作区与渐变淡出

适用于页面底部固定主操作区的场景，例如「创建并打开保险库」「保存」「继续」等提交按钮。

## 最终效果

- 主操作区固定在页面底部，不跟随滚动内容移动。
- 操作区没有实色底板，背景从透明逐渐过渡到页面底色，形成内容向下淡出的遮罩。
- 滚动内容按操作区实测高度预留底部空间；滚到底部时最后一个字段不会被按钮遮挡。
- 操作区自动包含底部安全区，安全区之上保留 8vp 间距。
- 浅色和深色模式使用各自的页面底色，不出现黑色或灰色过渡带。

## 复用组件

组件位置：`products/default/src/main/ets/components/DsBottomActionBar.ets`

组件职责：

- 提供底部固定操作区的统一内边距、安全区避让和渐变背景。
- 通过 `contentBuilder` 承载一个或多个操作控件。
- 通过 `onHeightChange` 回传操作区实测高度，供页面设置滚动内容底部避让。

组件不负责滚动容器本身，页面仍需提供 `Scroll` / `List` 并应用高度。

## 页面结构

```text
HdsNavDestination
└── Stack（Alignment.Bottom）
    ├── Scroll（100% 高，clip(false)）
    │   └── 内容 Column（padding.bottom = 操作区实测高度）
    └── DsBottomActionBar
        └── DsButton
```

不要在 `Scroll` 内容末尾直接放按钮；按钮必须位于 `Stack` 的底部层级，才能保持固定并让内容从下方穿过。

## 接入模板

```ts
@Local private bottomBarHeight: number = 0

@Builder
private bottomActionContent() {
  DsButton({
    label: $r('app.string.create_open_vault'),
    fullWidth: true,
    onTap: () => {
      // 提交
    },
  })
}

@Builder
private bottomActionBar() {
  DsBottomActionBar({
    onHeightChange: (height: number) => {
      this.bottomBarHeight = height
    },
    contentBuilder: () => {
      this.bottomActionContent()
    },
  })
}

build() {
  Stack({ alignContent: Alignment.Bottom }) {
    Scroll() {
      Column() {
        // 页面内容
      }
      .width('100%')
      .padding({
        top: $r('app.float.ds_space_lg'),
        bottom: this.bottomBarHeight,
        left: $r('app.float.ds_gutter'),
        right: $r('app.float.ds_gutter'),
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .clip(false)
    .align(Alignment.Top)

    this.bottomActionBar()
  }
  .width('100%')
  .height('100%')
}
```

`contentBuilder` 必须委托给页面内的 `@Builder` 方法，不能把 `DsButton` 等自定义组件直接写在箭头函数里；否则 ArkTS 会把组件构造按普通函数调用，运行时抛出 `class constructor cannot called without 'new'`。

## 关键约束

### 渐变

操作区只使用 `ds_surface_canvas_transparent` → `ds_surface_canvas` 的垂直渐变：

```ts
.linearGradient({
  angle: 180,
  colors: [
    [$r('app.color.ds_surface_canvas_transparent'), 0],
    [$r('app.color.ds_surface_canvas'), 1],
  ],
})
```

- 不使用实色 `backgroundColor` 作为操作区底板，否则内容无法淡出。
- 不在页面内复制渐变代码；统一通过 `DsBottomActionBar` 实现。
- 该渐变是保证内容可读性的功能性遮罩，不属于装饰性渐变。
- 不使用 `Scroll.fadingEdge` 代替本效果，原因见下一节。

### 透明端点的 Token

`ds_surface_canvas_transparent` 在浅色模式为 `#01FFFFFF`，深色模式为 `#010E1011`。

透明度必须是 `01`，不能写成 `00`：`linearGradient` 的完全透明端点在当前渲染链路中会被按不透明黑色处理，产生黑色渐变带。`01` 表示 1/255 透明度，视觉上等同透明，同时保留页面底色的 RGB。

### 高度回传

- `DsBottomActionBar` 使用 `onAreaChange` 实测自身高度，并通过 `onHeightChange` 回传。
- 页面必须把该高度应用为滚动内容 `padding.bottom`，不要写固定数值。
- 操作区高度包含顶部渐变区、操作控件和底部安全区，不需要在页面重复计算安全区。

### 安全区与标题栏

- 操作区内部通过 `immersiveLayoutState.bottomAvoidAreaHeightPx` 计算底部安全区。
- 内容仍使用 `HdsNavDestination` 的统一标题栏方案，滚动容器保留 `clip(false)`，不要因为底部操作区改动破坏标题栏穿透，详见 `docs/arkui-hds-titlebar-safe-area.md`。

## 为什么不用 Scroll.fadingEdge

`Scroll.fadingEdge` 不适合本场景：

- 它作用在 `Scroll` 自身可视边缘，无法定位到悬浮操作区的上沿。
- 它没有仅底部渐隐的选项，会同时影响两端。
- 官方文档说明 `fadingEdge` 生效时滚动组件会裁剪到边界，`clip(false)` 不生效，会破坏内容穿过 HDS 标题栏的效果。

因此底部固定操作区使用自身渐变遮罩，不使用 `fadingEdge`。

## 已接入页面

- `products/default/src/main/ets/pages/onboarding/CreateVaultPage.ets`

后续新增或改版页面遇到底部固定操作区时，直接复用 `DsBottomActionBar`，不要复制页面级实现。

## 检查清单

- 操作区在 `Stack` 底部，滚动内容可穿过其下方。
- 操作区无实色底板，渐变端点为 `ds_surface_canvas_transparent` 和 `ds_surface_canvas`。
- 透明端点 Token 的 alpha 为 `01`，不是 `00`。
- 滚动内容底部 padding 来自 `onHeightChange` 实测值。
- `contentBuilder` 通过页面 `@Builder` 方法提供，箭头函数内没有直接构造自定义组件。
- 底部安全区由操作区处理，页面没有重复加安全区。
- 滚动容器保留 `clip(false)`，标题栏穿透未回退。
- 浅色、深色模式各检查一次渐变颜色。

## 参考

- 颜色渐变：`API参考/ArkUI_方舟UI框架/ArkTS组件/通用属性/视效与模糊/颜色渐变/ts-universal-attributes-gradient-color`
- 滚动组件通用接口：`API参考/ArkUI_方舟UI框架/ArkTS组件/滚动与滑动/滚动组件通用接口/ts-container-scrollable-common`
