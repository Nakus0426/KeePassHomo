# 半模态弹窗（DsHalfModalSheet）用法与最佳实践

适用于所有 `bindSheet` 半模态内容：统一的悬浮标题栏 + 滚动穿透 + 可选底部操作区。

## 最终效果

- 顶部标题栏悬浮在内容之上，滚动内容可穿透到标题栏下方，由标题栏的渐变模糊材质覆盖。
- 内容区由父组件提供，自带滚动容器；可选底部固定操作区，内容可穿过其下方。
- 半模态面底为设计系统实色 `ds_surface_lowest`，不使用系统材质。
- 支持「内容避让标题栏」和「内容绘制到标题栏下方（沉浸式预览）」两种模式。

## 复用组件

组件位置：`products/default/src/main/ets/components/DsHalfModalSheet.ets`

职责边界：

- 负责 `HdsNavigation` 标题栏容器：`HdsNavigationTitleMode.MODAL` + `ScrollEffectType.GRADIENT_BLUR` + `hdsMaterial.MaterialType.ADAPTIVE`。
- 默认标题栏内容为 `DsPageHeader`（`headerSize: Small`，图标按钮随档位缩小为 32vp/18vp）。
- 通过 `bodyBuilder` 承载内容，`Stack(Alignment.Bottom)` 叠加可选 `bottomBarBuilder`。
- **不持有 `bindSheet`、不控制高度**：容器参数（`detents`、`height`、`radius`、`onWillDismiss`、`onDisappear` 等）仍由宿主 `bindSheet` 配置。

属性：

| 属性 | 类型 | 说明 |
|---|---|---|
| `title` | `ResourceStr` | 标题文案（普通标题栏用）。 |
| `showBack` / `onBack` | `boolean` / `() => void` | 是否显示返回按钮及回调。 |
| `actions` | `DsPageHeaderAction[]` | 右侧图标动作（关闭/保存/确认等）。 |
| `titleBarBuilder` | `@BuilderParam` | 整条自定义标题栏（如分组选择带搜索栏）；传了则忽略 title/showBack/actions。 |
| `bodyBuilder` | `@BuilderParam` | 必填，内容区；内容自带 `Scroll.clip(false)`。 |
| `bottomBarBuilder` | `@BuilderParam` | 可选，底部操作区，通常放 `DsBottomActionBar`。 |
| `contentBehindTitleBar` | `boolean` | 默认 `false`（内容避让标题栏）；`true` 时内容绘制到标题栏下方，用于沉浸式预览。 |

## 页面结构

```text
宿主组件
└── .bindSheet($$visible, this.sheetContent(), {
      backgroundColor: ds_surface_lowest, showClose: false, dragBar: ... })
    └── DsHalfModalSheet
        ├── HdsNavigation(titleMode=MODAL) titleBar(stackBuilder = DsPageHeader / titleBarBuilder)
        └── Stack(Alignment.Bottom)
            ├── bodyBuilder()        // 自带 Scroll.clip(false)
            └── bottomBarBuilder()   // 可选 DsBottomActionBar
```

## 最佳实践示例：密码生成器半模态

参考实现：`CreateVaultPage.ets`、`EntryEditorView.ets` 的 `generatorSheet()`。

要点：

- 生成结果预览底色要「上探」到标题栏底部，沉浸感更强，用 `contentBehindTitleBar: true`。
- `GeneratorContent` 的 `topOffset` 传标题栏高度，用它内部的 `ds_surface_low` 顶块把预览底色铺满标题栏下方；预览与页签栏固定在顶部，只有参数区在下方独立 `Scroll` 中滚动回弹，避免整块下拉回弹在顶部露出空白。
- 底部「重新生成 / 填入」固定在 `DsBottomActionBar`，高度回填给 `GeneratorContent` 的底部避让。

```ts
// 宿主：bindSheet 容器参数（高度/挡位仍在这里定）
.bindSheet($$this.generatorSheetVisible, this.generatorSheet(), {
  backgroundColor: $r('app.color.ds_surface_lowest'),
  showClose: false,
  dragBar: false,
  onDisappear: () => this.closeGenerator(),
})

@LocalBuilder
private generatorSheet() {
  DsHalfModalSheet({
    title: $r('app.string.generate_password'),
    actions: this.generatorActions(),
    bodyBuilder: this.generatorBody,
    bottomBarBuilder: this.generatorBottomBar,
    contentBehindTitleBar: true,
  })
}

@LocalBuilder
private generatorBody() {
  Stack() {
    GeneratorContent({
      viewModel: this.viewModel.generator,
      controller: this.generatorController,
      topOffset: this.sheetTitleBarHeightVp, // 预览底色上探量 = 标题栏高度
      bottomOffset: this.generatorBottomBarHeight,
      onSheet: true,
    })
  }
  .width('100%')
  .height('100%')
}

@LocalBuilder
private generatorBottomBar() {
  DsBottomActionBar({
    surfaceColor: $r('app.color.ds_surface_lowest'),
    fadeColor: $r('app.color.ds_surface_lowest_transparent'),
    onHeightChange: (height: number) => {
      this.generatorBottomBarHeight = height
    },
    contentBuilder: () => {
      this.generatorBottomActions()
    },
  })
}

private generatorActions(): DsPageHeaderAction[] {
  return [{ icon: $r('sys.symbol.xmark'), label: $r('app.string.close'), onTap: () => this.closeGenerator() }]
}

@Computed
get sheetTitleBarHeightVp(): number {
  const titleBarPx: number = ResUtil.getNumber($r('app.float.ds_page_header_height_sm').id)
  return this.getUIContext().px2vp(titleBarPx)
}
```

## 普通面板（内容避让标题栏）

不涉及预览底色上探的面板（类型选择、SSH 生成、模板选择等）用默认模式：内容避让标题栏，`body` 顶部用常规间距。

```ts
@Builder
private typeSheet() {
  DsHalfModalSheet({
    title: $r('app.string.select_type'),
    actions: [{ icon: $r('sys.symbol.xmark'), label: $r('app.string.close'), onTap: () => this.closeTypeSheet() }],
    bodyBuilder: this.typeSheetBody,
  })
}

@LocalBuilder
private typeSheetBody() {
  Scroll() {
    Column() { /* 内容 */ }
      .width('100%')
      .padding({ top: $r('app.float.ds_space_lg'), bottom: this.bottomOffset })
  }
  .width('100%')
  .height('100%')
  .scrollBar(BarState.Off)
  .edgeEffect(EdgeEffect.Spring)
  .clip(false)
}
```

分组选择这类特殊标题栏（条件返回 + 搜索栏）用 `titleBarBuilder` 整条自定义：

```ts
@LocalBuilder
private titleBarContent() {
  Column() {
    DsPageHeader({
      title: $r('app.string.select_group'),
      headerSize: DsPageHeaderSize.Small,
      showBack: this.pathGroups.length > 0,
      actions: this.groupActions(),
      onBack: () => this.navigateUp(),
    })
    this.searchBuilder()
  }
  .width('100%')
}

build() {
  DsHalfModalSheet({ titleBarBuilder: this.titleBarContent, bodyBuilder: this.bodyContent })
}
```

## 关键约束与反例

- 宿主 `bindSheet` 必须 `backgroundColor: $r('app.color.ds_surface_lowest')`；禁止 `systemMaterial`、禁止 `backgroundColor: Color.Transparent`。
- 标题栏统一 `ADAPTIVE` + `GRADIENT_BLUR`；不要在半模态上用其它材质档位。
- 内容区不要手算 `titleBarOffset` / 状态栏高度 / 标题栏高度；避让交给 `enableComponentSafeArea`，穿透交给 `Scroll.clip(false)`。生成器改为「固定预览/页签 + 参数区独立 `Scroll`」，不再整块 `Scroll.clip(false)`。
- 只有沉浸式预览开 `contentBehindTitleBar: true`，并在内容里用 `topOffset` 填充上探底色；普通面板保持默认。
- `titleBarBuilder` / `bodyBuilder` / `bottomBarBuilder` 必须传 `@LocalBuilder` 方法引用，不要在箭头函数里直接构造自定义组件；详见 `docs/arkui-builder-slot.md`。
- 底部操作区高度必须由 `DsBottomActionBar.onHeightChange` 实测回填内容的 `padding.bottom`；详见 `docs/arkui-bottom-action-bar.md`。
- 高度由宿主 `bindSheet` 决定（`detents`/`height`）：现有用法只有默认 / `MEDIUM`（约半屏）/ `LARGE`（约全屏）；未提供百分比高度 API，需要时再按真实用例补。

## 已接入位置

- `products/default/src/main/ets/pages/vault/EntrySheet.ets`（条目预览/编辑宿主）
- `products/default/src/main/ets/pages/vault/EntryPreviewView.ets`、`EntryEditorView.ets`（预览、编辑、生成器）
- `products/default/src/main/ets/pages/vault/EntryGroupPicker.ets`（分组选择，`titleBarBuilder`）
- `products/default/src/main/ets/pages/vault/EntryCustomFields.ets`（类型选择）
- `products/default/src/main/ets/pages/vault/SshKeyGeneratorSheet.ets`、`EntrySshKeysField.ets`（SSH 生成）
- `products/default/src/main/ets/pages/vault/EntryTemplatePicker.ets`（模板选择）
- `products/default/src/main/ets/pages/onboarding/CreateVaultPage.ets`（生成器）

## 检查清单

- 标题栏悬浮在内容之上，向上滚动时内容进入标题栏下方并被模糊覆盖，无裁剪或突然消失。
- 沉浸式预览（生成器）底色从标题栏底部连贯铺满；普通面板首屏内容位于标题栏下方并保留正常间距。
- 关闭/返回等标题栏图标按钮尺寸与标题栏档位匹配，不盖过标题。
- 半模态面底为 `ds_surface_lowest`，无系统材质。
- 底部操作区无实色底板，滚动到底部时最后一项不被遮挡。
- 浅色、深色模式各检查一次。

## 参考

- 半模态标题栏样式（UI Design Kit）：`devecocli docs read`《半模态样式》，`HdsNavigationTitleMode.MODAL` 下的标题栏模糊。
- 标题栏避让与滚动穿透：`docs/arkui-hds-titlebar-safe-area.md`
- 底部固定操作区：`docs/arkui-bottom-action-bar.md`
- 内容插槽：`docs/arkui-builder-slot.md`
