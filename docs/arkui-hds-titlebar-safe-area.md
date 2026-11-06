# HDS 标题栏避让与滚动穿透

本文适用于使用 `HdsNavDestination` + `DsPageHeader` 的子页：首屏内容需要位于标题栏下方，滚动时内容又能进入标题栏下方，由标题栏的渐变模糊材质覆盖。

## 现象

- 首屏第一个字段与标题栏重叠、发灰，或被标题栏材质遮住。
- 或者内容区被安全区裁在标题栏下方，滚动时无法进入标题栏下方。
- 页面各自手写 `topInset + 标题栏高度 + gap`，标题栏内自定义插槽变高后避让失效。

## 根因

1. `HdsNavDestination` 的内容区从安全区顶部开始，标题栏覆盖在内容之上。`avoidLayoutSafeArea: true` 只让标题栏避让状态栏，不会自动给内容区增加标题栏高度的内边距。
2. `maskExtraHeight` 的语义是“标题栏高度之外的额外遮罩高度”，实际 mask 高度 = 标题栏高度 + `maskExtraHeight`。把它设成自定义头部总高度，会把材质遮罩延伸到首屏内容。
3. 页面手算 `topInset + 标题栏高度 + gap` 依赖固定常量，无法跟随状态栏和 `stackBuilder` 的实际测量高度。
4. 只设置 `enableComponentSafeArea: true` 会让内容区避让标题栏，但滚动容器默认被裁剪，滚动内容无法穿入标题栏下方。

## 最终方案

### 1. 标题栏启用组件级安全区

`products/default/src/main/ets/components/DsPageTitleBar.ets` 提供：

```ets
function pageTitleBarOptions(stackBuilder: CustomBuilder | undefined,
  componentSafeArea: boolean): HdsNavigationTitleBarOptions {
  return {
    avoidLayoutSafeArea: true,
    enableComponentSafeArea: componentSafeArea,
    // ...
  }
}

export function dsNavPageTitleBarOptions(stackBuilder?: CustomBuilder): HdsNavigationTitleBarOptions {
  return pageTitleBarOptions(stackBuilder, true)
}
```

`enableComponentSafeArea: true` 让内容区自动避让状态栏和标题栏，并使用标题栏的实际测量高度；`stackBuilder` 内的自定义内容把标题栏撑高时不需要改页面代码。

### 2. 滚动容器允许穿透

```ets
Scroll() {
  Column() {
    // 页面内容
  }
  .padding({ top: $r('app.float.ds_space_lg') })
}
.clip(false)
```

`Scroll.clip(false)` 是滚动穿透的关键。它允许滚动内容绘制到滚动容器边界之外，进入标题栏下方。

### 3. `maskExtraHeight` 与首屏间距对齐

```ets
const DS_PAGE_CONTENT_TOP_GAP_VP: number = 20
// mask 额外高度与首屏内容间距一致，避免材质盖住首屏内容。
const DS_PAGE_TITLE_BAR_MASK_EXTRA_HEIGHT_VP: number = DS_PAGE_CONTENT_TOP_GAP_VP
```

不要把 `maskExtraHeight` 设成 `DS_PAGE_HEADER_HEIGHT_VP` 或自定义头部总高度。实际 mask 高度 = 标题栏高度 + `maskExtraHeight`；额外高度大于首屏内容间距时，首屏内容会进入遮罩。

### 4. 页面结构

```ets
HdsNavDestination() {
  Stack({ alignContent: Alignment.Bottom }) {
    Scroll() {
      Column({ space: $r('app.float.ds_space_xl') }) {
        // 表单字段
      }
      .width('100%')
      .padding({
        top: $r('app.float.ds_space_lg'),
        bottom: 160,
        left: $r('app.float.ds_gutter'),
        right: $r('app.float.ds_gutter'),
      })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .clip(false)

    // 底部固定操作区
  }
  .width('100%')
  .height('100%')
}
.titleBar(dsNavPageTitleBarOptions((): void => this.pageHeaderBuilder()))
.hideBackButton(true)
```

无滚动容器或首屏固定的页面只使用 `dsNavPageTitleBarOptions`，不需要 `clip(false)`。

## 已接入页面

- `products/default/src/main/ets/pages/onboarding/CreateVaultPage.ets`
- `products/default/src/main/ets/pages/onboarding/WebDavConnectPage.ets`
- `products/default/src/main/ets/pages/onboarding/FileSummaryPage.ets`
- `products/default/src/main/ets/pages/vault/GroupManagerPage.ets`

这些页面只保留普通内容间距，不再计算状态栏高度、标题栏高度和 gap。

## 保险库首页的 HdsNavigation 接线

`AppShell` 的根 `HdsNavigation(appRouter.stack)` 只承载全局路由与 `HdsTabs`；四个一级页各自持有 `HdsNavigation()`，其中 `VaultHomePage` 的滚动列表与标题栏导航容器位于同一组件内。

- `VaultHomePage` 的 `titleBar` 开启 `enableComponentSafeArea: true`，`bottomBuilder` 承载搜索与筛选区（高度 112vp）或批量选择头（高度 56vp）。
- `HdsNavigation.bindToScrollable([scroller])` 绑定首页 `List`；标题栏渐变模糊与动态显隐都基于这条绑定。
- `dynamicHideTitleBar` 使用 `hideTitleArea: false`（标题行常驻）和 `hideBottomBuilder: true`（搜索/筛选区收起），模式为 `HideMode.SCROLL_UP`。
- `List` 使用 `EdgeEffect.Spring` 并在 `START | END` 两侧开启 `effectEdge`，保留触底回弹。HDS 在滚动到顶部/底部时会立即触发标题栏显示，这是官方文档明确的预期行为。
- 其他一级页的标题栏走 `dsPageTitleBarOptions`，不套用该配置；解锁、搜索、分组管理等二级页始终作为根栈的 `HdsNavDestination`，入栈后覆盖整个页签容器。

## 检查项

- 首屏第一个内容位于标题栏下方，并保留设计稿要求的内容间距。
- 向上滚动时，内容进入标题栏下方，由标题栏材质模糊覆盖，不被裁剪或突然消失。
- 修改 `stackBuilder` 内的自定义内容高度后，首屏内容自动下移，不需要改页面内边距。
- 深色模式下标题栏材质与首屏内容间距正常。

## 不要这样做

- 不要在页面内写 `topInset + 标题栏高度 + gap` 的避让公式。
- 不要把 `maskExtraHeight` 设成 `DS_PAGE_HEADER_HEIGHT_VP`。
- 需要滚动穿透时，不要只设置 `enableComponentSafeArea: true` 而漏掉 `Scroll.clip(false)`。
- 不要给其他模块直接套用本方案；保险库首页的 `HdsNavigation`、滚动列表和自定义标题栏在同一组件内，迁移前先核对结构。已接入页面见上一节。

## 参考

- UI Design Kit 开发指南《设置自定义区域》中的 `HdsNavDestination` 示例：`enableComponentSafeArea: true` 配合 `Scroll.clip(false)`，实现内容区避让标题栏并允许穿透。
- `HdsNavigationBackgroundStyle.maskExtraHeight`：实际 mask 高度 = 标题栏高度 + `maskExtraHeight`，默认值 32。
- 当前实现入口：`products/default/src/main/ets/components/DsPageTitleBar.ets`。
