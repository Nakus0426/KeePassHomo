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
- 按 pen 自绘顶部拖拽条（16 高行内 36×2，`ds_outline_variant`）：系统 `dragBar` 在 MODAL 标题栏下不显示，但保留其手势区域（`dsSheetOptions()` 里 `dragBar: true`），拖动顶部即可调整高度/关闭。
- 拖拽条必须画在标题栏 `stackBuilder` 内部（`titleBarContent` 的第一行），与标题栏共用同一层渐变模糊材质；放在标题栏外会与标题栏出现底色断层。沉浸式预览（`contentBehindTitleBar: true`）不画拖拽条。
- 默认标题栏内容为 `DsPageHeader`（`headerSize: Small`，图标按钮与所有页头一致为 44vp/20vp）。
- `titleBarBottomBuilder` 承载标题栏底部扩展区（如搜索行 + 面包屑），由 HDS 计入标题栏高度并一起悬浮。
- 通过 `bodyBuilder` 承载内容，`Stack(Alignment.Bottom)` 叠加可选 `bottomBarBuilder`。
- **不持有 `bindSheet`、不控制高度**：容器参数（`detents`、`height`、`radius`、`onWillDismiss`、`onDisappear` 等）仍由宿主 `bindSheet` 配置。

属性：

| 属性 | 类型 | 说明 |
|---|---|---|
| `title` | `ResourceStr` | 标题文案（普通标题栏用）。 |
| `showBack` / `onBack` | `boolean` / `() => void` | 是否显示返回按钮及回调。 |
| `actions` | `DsPageHeaderAction[]` | 右侧图标动作（关闭/保存/确认等）。 |
| `titleBarBuilder` | `@BuilderParam` | 整条自定义标题栏（如分组选择带搜索栏）；传了则忽略 title/showBack/actions。 |
| `titleBarBottomBuilder` | `@BuilderParam` | 可选，标题栏底部扩展区（如搜索行 + 面包屑），随标题栏材质一起悬浮。 |
| `titleBarBottomHeight` | `Length` | 扩展区高度；HDS 用它计入标题栏占位与遮罩。 |
| `scrollableScroller` | `Scroller` | 内容区有滚动容器时必填；不绑定则标题栏材质常驻，内容还没滚到顶部就出现模糊带（模板选择器踩过）。 |
| `bodyBuilder` | `@BuilderParam` | 必填，内容区；内容自带 `Scroll/List.clip(false)`。 |
| `bottomBarBuilder` | `@BuilderParam` | 可选，底部操作区，通常放 `DsBottomActionBar`。 |
| `contentBehindTitleBar` | `boolean` | 默认 `false`（内容避让标题栏）；`true` 时内容绘制到标题栏下方，用于沉浸式预览。 |

## 页面结构

```text
宿主组件
└── .bindSheet($$visible, this.sheetContent(), dsSheetOptions({ detents, onDisappear, ... }))
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
.bindSheet($$this.generatorSheetVisible, this.generatorSheet(), dsSheetOptions({
  topBorder: true,
  onDisappear: () => this.closeGenerator(),
}))

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

分组选择这类「标题栏 + 搜索 + 面包屑」的形态，标题用 `titleBarBuilder`、搜索与面包屑放 `titleBarBottomBuilder`，滚动列表通过 `scrollableScroller` 绑定，内容从悬浮区下方穿透：

```ts
build() {
  DsHalfModalSheet({
    titleBarBuilder: this.headerBar,
    titleBarBottomBuilder: this.searchAndBreadcrumb,
    titleBarBottomHeight: this.titleBarBottomHeight,
    scrollableScroller: this.scroller,
    bodyBuilder: this.bodyContent,
    bottomBarBuilder: this.footerBar,
  })
}
```

通用分组选择已抽为 `products/default/src/main/ets/components/DsGroupPicker.ets`，新页面直接复用，不要再手写一层选择器：

```ts
DsGroupPicker({
  // 每次求值都读取最新分组（含条目数）；root 直接取 groups() 首项，避免重复扁平化。
  groupSource: (): GroupPickerSource => {
    const allGroups: VaultGroup[] = this.viewModel.groups()
    return { rootGroup: allGroups[0], topLevelGroups: this.viewModel.topLevelGroups(), allGroups }
  },
  initialGroupUuid: this.groupUuid,
  busy: this.viewModel.busy,
  onPicked: (groupUuid: string) => { /* 落稿分组并收起半模态 */ },
  onClose: () => this.groupPickerVisible = false,
  onCreateGroup: (parentUuid: string, name: string) =>
  createGroupFromPicker(this.getUIContext(), this.viewModel, parentUuid, name),
  onActivity: () => this.viewModel.recordActivity(),
  onBackHandler: (handler: () => boolean) => this.groupPickerBackHandler = handler,
})
```

## 关键约束与反例

- 宿主 `bindSheet` 的容器参数统一用 `dsSheetOptions()`（`products/default/src/main/ets/components/DsSheetOptions.ets`）：直角面板、`ds_surface_lowest` 面底、无系统关闭按钮。禁止在调用处手写选项字面量或遗漏 `radius`。
- 注册了 `onWillDismiss` 时，系统默认「先回弹到原位、再关闭」，拖动一半松手会看到闪回顶部再下滑消失。`dsSheetOptions()` 已注册空的 `onWillSpringBackWhenDismiss` 取消回弹，关闭动画直接从当前位置开始；不要在调用处再覆盖该回调。
- 禁止 `systemMaterial`、禁止 `backgroundColor: Color.Transparent`。
- 标题栏统一 `ADAPTIVE` + `GRADIENT_BLUR`；不要在半模态上用其它材质档位。
- 内容区不要手算 `titleBarOffset` / 状态栏高度 / 标题栏高度；避让交给 `enableComponentSafeArea`，穿透交给 `Scroll.clip(false)`。生成器改为「固定预览/页签 + 参数区独立 `Scroll`」，不再整块 `Scroll.clip(false)`。
- 内容区的 `Scroll` / `List` 必须 `edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true, effectEdge: EffectEdge.START | EffectEdge.END })`：内容不足一屏时也由滚动容器接管竖向手势并回弹，否则上下滑动会拖动整个半模态（只剩顶部拖拽条可拖动）。内容区的 `Scroll` 还必须 `.align(Alignment.Top)`：通用属性 `align` 默认居中，内容不足一屏时整块表单会悬在面板中部。
- 列表底部按 `bottomBarBuilder` 实测高度留 `padding.bottom`，顶部由 `enableComponentSafeArea` 避让标题栏，禁止让首行/末行被悬浮标题栏或底栏压住。
- 只有沉浸式预览开 `contentBehindTitleBar: true`，并在内容里用 `topOffset` 填充上探底色；普通面板保持默认。
- `titleBarBuilder` / `bodyBuilder` / `bottomBarBuilder` 必须传 `@LocalBuilder` 方法引用，不要在箭头函数里直接构造自定义组件；详见 `docs/arkui-builder-slot.md`。
- 底部操作区高度必须由 `DsBottomActionBar.onHeightChange` 实测回填内容的 `padding.bottom`；详见 `docs/arkui-bottom-action-bar.md`。
- 高度由宿主 `bindSheet` 决定（`detents`/`height`）：固定挡位用默认 / `MEDIUM` / `LARGE`，需要「刚好放下内容」时也可以用百分比或数值挡位。模板选择器取 `[MEDIUM, LARGE]` 两档，初始半屏、可上拖展开，未展开时卡片区内部滚动。
- 多档位 `detents`（如 `[MEDIUM, LARGE]`）会让系统显示自己的控制条，样式不受设计系统控制，且与自绘拖拽条叠成两根：用 `dsSheetOptions({ dragBar: false })` 关掉系统那根，保留 `DsHalfModalSheet` 自绘的。
- 多档位拖拽时，内容刷新时机由 `scrollSizeMode` 决定，默认 `FOLLOW_DETENT`——拖动过程中新露出的区域**不会渲染**，要等吸附到目标挡位才出内容。需要跟手实时展开时传 `scrollSizeMode: ScrollSizeMode.CONTINUOUS`（官方提示该模式对内容渲染性能要求更高，builder 内避免重活）。模板选择器踩过这个坑。
- **不要用 `SheetSize.FIT_CONTENT`**：自适应高度要求 builder 根节点由内容决定，而本壳的根是 `HdsNavigation`，它和内容里的 `Scroll` 在无界高度下都会撑满可用空间，实测面板被撑到接近 `LARGE`（底部大片空白）。HDS 外壳与 FIT_CONTENT 不兼容。

## 已接入位置

- `products/default/src/main/ets/pages/vault/EntrySheet.ets`（条目预览/编辑宿主）
- `products/default/src/main/ets/pages/vault/EntryPreviewView.ets`、`EntryEditorView.ets`（预览、编辑、生成器）
- `products/default/src/main/ets/components/DsGroupPicker.ets`（通用分组选择：自定义标题栏 + 底部扩展区 + 滚动穿透）
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
