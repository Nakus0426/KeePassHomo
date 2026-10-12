# 分段按钮与 Tabs 联动的切换动画（TabSegmentButtonV2 + Tabs）

页面里出现「分段按钮选类型 + 下方内容跟着切换」时，两边的状态必须分开维护、按固定时机写回，否则会出现空白页签、指示块错位滑动、内容反向抖动等症状。本文是接线约束与排查表，改动这类界面之前先读。

当前使用该模式的实现：

- `products/default/src/main/ets/pages/generator/GeneratorComponents.ets`（密码生成器，`parameterTabs()` / `selectMode()`）
- `products/default/src/main/ets/pages/vault/SshKeyGeneratorSheet.ets`（SSH 密钥生成半模态，`typeSelector()` /
  `selectType()`）

## 正确接线

```ets
  // 指示块状态：点击回调里立刻写
  @Local private segmentIndex: number = 0
  // 页签下标：只由 Tabs.onChange 回写
  @Local private currentTabIndex: number = 0
  @Local private tabOpacity: number[] = [1, 0]
  @Local private tabOffsetX: number[] = [0, 0]
  @Local private tabZIndex: number[] = [1, 0]
  private readonly tabsController: TabsController = new TabsController()

  private selectType(index: number): void {
    this.segmentIndex = index                  // 只写指示块状态
    this.tabsController.changeIndex(index)     // 页签带动画切换，才会执行 customContentTransition
  }

  @LocalBuilder
  private typeSelector() {
    TabSegmentButtonV2({
      items: this.typeItems,
      selectedIndex: this.segmentIndex,
      backgroundSystemMaterial: this.typeBarMaterial,
      $selectedIndex: (index: number) => this.selectType(index),
    })
  }

  Tabs({ index: $$this.currentTabIndex, controller: this.tabsController }) {
    this.typeTabContent(0)
    this.typeTabContent(1)
  }
  .scrollable(false)
  .barHeight(0)
  .divider(null)
  .customContentTransition((from: number, to: number) => this.tabContentTransition(from, to))
  .onChange((index: number) => this.currentTabIndex = index)
  .clip(true)
```

页签内容节点：

```ets
  @LocalBuilder
  private typeTabContent(type: number) {
    TabContent() {
      Column() { /* 表单内容 */ }
        .width('100%')
        .translate({ x: this.tabOffsetX[type] })   // 位移挂在内容节点
    }
    .align(Alignment.Top)
    .opacity(this.tabOpacity[type])                // TabContent 只承担透明度与层级
    .zIndex(this.tabZIndex[type])
    .clip(true)
  }
```

`tabContentTransition(from, to)` 与 `customContentTransition` 的写法照抄上述两个实现：`UIUtils.applySync` 摆初始位移与透明度，再
`animateTo` 播放，`onFinish` 里 `proxy.finishTransition()`；`from === to` 时返回 `timeout: 0` 并直接 `finishTransition()`。

## 约束

1. **指示块状态与页签下标必须是两个状态。** 指示块绑 `TabSegmentButtonV2.selectedIndex`，页签绑 `Tabs.index`，两者不要共用一个变量。
2. **点击回调里不要写 `Tabs.index` 绑定的状态。** 在切换动画进行中改写它，页签会把它当成一次新的索引请求，重新执行转场的初始位移，表现为一次反方向抖动（首次切换最明显）。
3. **点击回调里必须调 `tabsController.changeIndex(index)`。** 只写状态、不调 `changeIndex`，页签按无动画跳转处理，
   `customContentTransition` 落到 `from === to` 分支直接返回，没人把新页签的 `tabOpacity` 置 1，而它的初始值是 0 ——
   结果就是新页签内容空白。
4. **`translate` 必须挂在内层内容节点上。** `TabContent` 只挂 `opacity` 与 `zIndex`；把位移漏在内容节点之外，切换就只剩淡入淡出。
5. **转场位移量取稳定的容器宽度。** 用外层内容列的实测宽度，不要用 `Tabs` 自身的 `onAreaChange`：切换瞬间页签内容会超出
   `Tabs` 边界，实测宽度会被污染，位移量随之跳变。
6. **`clip(true)` 收住溢出。** 密码生成器是历史写法 `clip(false)`，新页面统一用 `true`，否则滑动的页签内容会渲染到界面之外。
7. **指示块状态的写入只能有一处。** 若该写入带副作用（生成器的 `setMode` 会重生成密码），不要同时在 `onAnimationStart`
   里再写一次，否则一次点击执行两遍。
8. **`$selectedIndex` 是 @Event 回调，不是双向绑定**；`selectedIndex` 是只读 @Param。回调里必须自己写状态，组件才会按新的
   `selectedIndex` 播指示块动画。详见 SegmentButtonV2 组件文档。

## 症状速查

| 现象                       | 原因                                                                   | 处置                                            |
|--------------------------|----------------------------------------------------------------------|-----------------------------------------------|
| 切到第二个页签内容空白，只有首个页签有内容    | 回调只写状态、没调 `changeIndex`，转场走 `from === to` 提前返回，新页签停在初始 `opacity = 0` | 回调里补 `this.tabsController.changeIndex(index)` |
| 指示块从按钮外部进入，在旧选项处停一下再滑到目标 | 指示块状态与页签下标共用一个变量，且只在 `onChange` 写回                                   | 拆成两个状态，指示块状态在点击回调里立刻写                         |
| 切换时出现一次反方向抖动             | 动画进行中改写了 `Tabs.index` 绑定的状态                                          | 页签下标只由 `onChange` 回写                          |
| 切换只有淡入淡出、没有横滑            | 内容节点漏了 `.translate(...)`                                             | 位移挂到内容节点                                      |
| 内容滑到界面外                  | `Tabs` / `TabContent` 用了 `clip(false)`                               | 改成 `clip(true)`                               |
| 位移量忽大忽小、内容跳变             | 位移量取自 `Tabs` 自身实测宽度                                                  | 改取外层稳定容器的实测宽度                                 |
| 一次切换密码生成两次               | 指示块状态的写入既在回调里又在 `onAnimationStart` 里                                 | 只保留回调里那一处                                     |
