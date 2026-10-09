import { BusinessError } from '@kit.BasicServicesKit'
import { LengthMetrics, promptAction, SymbolGlyphModifier, UIContext, uiMaterial, UIUtils } from '@kit.ArkUI'
import {
  BottomBuilderShowType,
  hdsMaterial,
  HdsNavigation,
  HdsNavigationIconOptions,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleMode,
  IconStyleMode,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { AnimationTokens, AppToast, VaultGroup } from '@ohos/common'
import { LogUtil, ResUtil } from '@pura/harmony-utils'
import { GroupRow, GroupRowShift, groupRowTransition } from '../../components/GroupRow'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { EntryEditorViewModel } from '../../viewmodel/EntryEditorViewModel'

/** 新建分组名的长度上限：防异常输入，KDBX 组名本身无硬性限制。 */
const NEW_GROUP_NAME_MAX_LENGTH: number = 64

/** 标题栏下方搜索区高度，与官方自定义区域示例一致。 */
const SEARCH_BAR_HEIGHT_VP: number = 56

/** 层级切换横移距离占比：与生成器页签切换动画同参，横移自身宽度的 20%。 */
const LEVEL_TRANSITION_OFFSET_RATIO: number = 0.2

/** 从 group 向上回溯到目标组的链路（含首尾）；目标不在子树内返回 undefined。 */
function findGroupChain(group: VaultGroup, targetUuid: string): VaultGroup[] | undefined {
  if (group.uuid === targetUuid) {
    return [group]
  }
  for (const child of group.groups) {
    const chain: VaultGroup[] | undefined = findGroupChain(child, targetUuid)
    if (chain !== undefined) {
      chain.unshift(group)
      return chain
    }
  }
  return undefined
}

/** 两轮可见顺序是否一致：一致就不重建行，避免逐字输入时无谓地整表重播转场。 */
function sameOrder(previous: string[], next: string[]): boolean {
  return previous.length === next.length
    && previous.every((uuid: string, index: number) => uuid === next[index])
}

/**
 * 分组选择器：编辑半模态内的第二层半模态，形态对齐官方文件选择器（保存位置模式）——
 * 面包屑 + 文件夹列表 + 搜索 + 新建分组。
 * 只读数据来自 AppViewModel；editor 仅确认按钮经 setGroup 单一入口写回编辑草稿；
 * 浏览栈、搜索词、瞬态选中与弹窗草稿是本组件的瞬态 UI 状态，随半模态销毁而重置。
 */
@ComponentV2
export struct EntryGroupPicker {
  @Param editor: EntryEditorViewModel = new EntryEditorViewModel()
  /** 底部避让尺寸由宿主按半模态测量结果下发（手势区随窗口变化，宿主统一感知）。 */
  @Param bottomOffset: number = 0
  /** 选中分组后由宿主收起半模态：开合状态归宿主，本组件只发信号。 */
  @Event onPicked: () => void = () => {
  }
  /** 关闭选择器：不改变已选分组，仅收起半模态。 */
  @Event onClose: () => void = () => {
  }
  @Event onActivity: () => void = () => {
  }
  /**
   * 把「返回已被消费」的判定交给宿主：宿主拦截到返回类事件时调用注册进来的回调，
   * 返回 true 表示这次返回已用于回退层级（或退出搜索），半模态保持打开。
   */
  @Event onBackHandler: (handler: () => boolean) => void = () => {
  }
  /** 浏览栈：根下顶层到当前层的分组链；空链表示停在根层。 */
  @Local private pathGroups: VaultGroup[] = []
  /** 瞬态选中分组：点击与进层只写这里，确认按钮才经 editor.setGroup 落稿；初始值为进入时的分组。 */
  @Local private selectedGroupUuid: string = ''
  @Local private searchDraft: string = ''
  /** 新建分组弹窗的输入草稿：弹窗内容是组件内 @Builder，直接读写本状态，无需参数中介。 */
  @Local private newGroupName: string = ''
  /** 层级切换动画状态：横移量与透明度由 switchLevel 两段式驱动，宽度经 onAreaChange 实测。 */
  @Local private levelOffsetX: number = 0
  @Local private levelOpacity: number = 1
  @Local private levelWidthVp: number = 0
  @Local private levelSwitching: boolean = false
  /** 行版本号：换词后自增让 ForEach 重建行，重排才有转场可播。 */
  @Local private rowVersion: number = 0
  private readonly rowShift: GroupRowShift = new GroupRowShift()
  /** 面包屑滚动控制器：层级变化后把当前层级滚回视野。 */
  private readonly breadcrumbScroller: Scroller = new Scroller()
  private readonly viewModel: AppViewModel = appViewModel
  private readonly dialogController: promptAction.DialogController = new promptAction.DialogController()
  private readonly confirmIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.checkmark'))
    .fontColor([$r('sys.color.confirm')])
  private readonly newGroupIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.folder_badge_plus'))
      .fontColor([$r('sys.color.titlebar_icon_color')])
  private readonly closeIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.xmark'))
    .fontColor([$r('sys.color.titlebar_icon_color')])
  private readonly backIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.chevron_backward'))
    .fontColor([$r('sys.color.titlebar_icon_color')])
  /**
   * 纯淡入淡出：面包屑在搜索态直接淡出，列表与空态整块互换也用它——
   * 缩放交给行本身（与首页列表/空态切换同款）。
   */
  private readonly fadeTransition: TransitionEffect = TransitionEffect.OPACITY
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })

  aboutToAppear(): void {
    this.searchDraft = ''
    this.pathGroups = this.chainToGroup(this.editor.groupUuid)
    this.selectedGroupUuid = this.editor.groupUuid
    this.onBackHandler(() => this.navigateUp())
  }

  /** 半模态销毁时连带关闭新建弹窗：拖拽收起不应把输入弹窗留在窗口上。 */
  aboutToDisappear(): void {
    this.dialogController.close()
  }

  @Computed
  private get searching(): boolean {
    return this.searchDraft.trim().length > 0
  }

  /** 当前层分组：根层取根分组，否则取浏览栈末项，恒有值。 */
  @Computed
  private get currentGroup(): VaultGroup {
    if (this.pathGroups.length === 0) {
      return this.viewModel.rootGroup()
    }
    return this.pathGroups[this.pathGroups.length - 1]
  }

  @Computed
  private get currentGroups(): VaultGroup[] {
    if (this.pathGroups.length === 0) {
      return this.viewModel.topLevelGroups()
    }
    return this.pathGroups[this.pathGroups.length - 1].groups
  }

  /** 全库匹配组名与全路径，大小写不敏感；命中行点击即选中，无层级概念。 */
  @Computed
  private get searchResults(): VaultGroup[] {
    return this.matchGroups(this.searchDraft)
  }

  private matchGroups(query: string): VaultGroup[] {
    const keyword: string = query.trim().toLocaleLowerCase()
    if (keyword.length === 0) {
      return []
    }
    return this.viewModel.groups().filter((group: VaultGroup) =>
    group.name.toLocaleLowerCase().includes(keyword) || group.path.toLocaleLowerCase().includes(keyword))
  }

  /**
   * 某个搜索词下的可见顺序：空词即当前浏览层。
   * 换词前后各算一次，不读 @Computed，免得依赖它的重算时机。
   */
  private orderForDraft(query: string): string[] {
    const groups: VaultGroup[] = query.trim().length === 0 ? this.currentGroups : this.matchGroups(query)
    return groups.map((group: VaultGroup) => group.uuid)
  }

  @Computed
  private get visibleGroups(): VaultGroup[] {
    return this.searching ? this.searchResults : this.currentGroups
  }

  @Computed
  private get rootName(): string {
    return this.viewModel.rootGroup().name
  }

  @Computed
  private get titleBarOffset(): number {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const gapPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
    return this.getUIContext().px2vp(titlebarHeightPx + gapPx)
  }

  @Builder
  private searchBuilder() {
    Row() {
      Search({ placeholder: $r('app.string.search_groups'), value: this.searchDraft })
        .height($r('sys.float.titlebar_icon_background_width'))
        .searchButton($r('app.string.search'))
        .systemMaterial(new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
          interactive: true,
        }))
        .onChange((value: string) => this.applyQuery(value))
        .onSubmit(() => this.onActivity())
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
  }

  /**
   * 搜索词变化：先记下当前可见顺序，再换词，再判断结果集是否真的变了。
   * 结果集变了才重建行并据旧下标算入场位移，于是命中行从原位置滑到新位置，而不是瞬移。
   * 搜索词本身立即上屏，输入不因动画而迟滞。
   */
  private applyQuery(value: string): void {
    const previousOrder: string[] = this.orderForDraft(this.searchDraft)
    const nextOrder: string[] = this.orderForDraft(value)
    this.searchDraft = value
    if (sameOrder(previousOrder, nextOrder)) {
      return
    }
    this.rowShift.beginSwap(previousOrder)
    this.rowVersion++
  }

  private chainToGroup(groupUuid: string): VaultGroup[] {
    for (const group of this.viewModel.topLevelGroups()) {
      const chain: VaultGroup[] | undefined = findGroupChain(group, groupUuid)
      if (chain !== undefined) {
        return chain
      }
    }
    return []
  }

  private countText(resource: Resource, count: number): string {
    return ResUtil.getStringSync(resource).replace('%s', String(count))
  }

  /** 分割线与主文本左对齐：行内边距 + 圆形图标宽（字形加两侧内边距）+ 图标与文本间距。 */
  @Computed
  private get dividerStartMargin(): number {
    const padding8Px = ResUtil.getNumber($r('sys.float.padding_level8').id) * 2
    const iconSizePx = ResUtil.getNumber($r('sys.float.Title_L').id)
    const padding4Px = ResUtil.getNumber($r('sys.float.padding_level4').id) * 2
    return this.getUIContext().px2vp(padding8Px + iconSizePx + padding4Px)
  }

  @Computed
  private get levelSlideOffset(): number {
    return this.levelWidthVp * LEVEL_TRANSITION_OFFSET_RATIO
  }

  /**
   * 层级切换动画，方向对齐生成器页签切换：前进（进子组）时旧层左移淡出、新层自右侧进入；
   * 后退（面包屑回跳）时反向。数据切换发生在两段动画之间，该帧内容不可见。
   * 本 SDK 的 animateTo 只收两参，onFinish 写在 AnimateParam 里（与生成器一致）。
   */
  private switchLevel(forward: boolean, update: () => void): void {
    if (this.levelSwitching) {
      return
    }
    this.levelSwitching = true
    const uiContext: UIContext = this.getUIContext()
    const offset: number = this.levelSlideOffset
    const exitParam: AnimateParam = {
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    }
    exitParam.onFinish = () => {
      update()
      // 入场起点必须同步落到渲染树：V2 下异步刷新的话，入场动画的起点仍是退场动画的终点，
      // 新层会从反方向进来（前进时本该自右侧进入，却从左往右走）。
      UIUtils.applySync(() => this.levelOffsetX = forward ? offset : -offset)
      const enterParam: AnimateParam = {
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
      }
      enterParam.onFinish = () => this.levelSwitching = false
      uiContext.animateTo(enterParam, () => {
        this.levelOffsetX = 0
        this.levelOpacity = 1
      })
    }
    uiContext.animateTo(exitParam, () => {
      this.levelOpacity = 0
      this.levelOffsetX = forward ? -offset : offset
    })
  }

  private enterGroup(group: VaultGroup): void {
    this.selectedGroupUuid = group.uuid
    // 整体替换数组：@Local 对数组的可靠刷新方式是换引用，不是原地 push。
    this.switchLevel(true, () => this.pathGroups = this.pathGroups.concat([group]))
    this.onActivity()
  }

  /**
   * 确认选中：唯一写 editor 的入口，按瞬态选中取组落稿后发收起信号。
   * 关闭路径不经这里，editor 保持进入时的值，无需还原。
   */
  private confirmPick(): void {
    this.editor.setGroup(this.viewModel.requireGroup(this.selectedGroupUuid))
    this.onActivity()
    this.onPicked()
  }

  /** 面包屑跳转：depth 为保留的层数，0 回根层；depth 大于当前层数视为前进。 */
  private jumpTo(depth: number): void {
    const nextPath: VaultGroup[] = this.pathGroups.slice(0, depth)
    // 跳到的层即选中该层分组；回根层无可选项，还原为进入时的分组。
    this.selectedGroupUuid = depth === 0 ? this.editor.groupUuid : nextPath[depth - 1].uuid
    this.switchLevel(depth > nextPath.length, () => this.pathGroups = nextPath)
    this.onActivity()
  }

  /**
   * 返回一步：标题栏返回按钮、系统返回键/返回手势、导航栏返回共用这一条路径。
   * 先退出搜索（此时列表是全库结果，层级并不可见），再逐层回退，回到根层才算没得退。
   * 返回 true 表示这次返回已被消费，半模态保持打开。
   */
  private navigateUp(): boolean {
    if (this.searching) {
      this.searchDraft = ''
      this.onActivity()
      return true
    }
    if (this.pathGroups.length === 0) {
      return false
    }
    if (this.levelSwitching) {
      // 层级动画进行中：此时层栈正在变，先吃掉这次返回，免得动画中途误收半模态。
      return true
    }
    this.jumpTo(this.pathGroups.length - 1)
    return true
  }

  @Builder
  private newGroupDialog() {
    Column({ space: $r('sys.float.padding_level6') }) {
      Text($r('app.string.new_group'))
        .fontSize($r('sys.float.Title_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)

      TextInput({ placeholder: $r('app.string.group_name_placeholder'), text: this.newGroupName })
        .fontSize($r('sys.float.Body_L'))
        .maxLength(NEW_GROUP_NAME_MAX_LENGTH)
        .height($r('app.float.control_height'))
        .backgroundColor(Color.Transparent)
        .showUnderline(true)
        .underlineColor({ typing: $r('sys.color.brand') })
        .onChange((value: string) => this.newGroupName = value)

      Row({ space: $r('sys.float.padding_level6') }) {
        Button($r('app.string.cancel'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
          .onClick(() => this.closeNewGroupDialog())

        Divider()
          .vertical(true)
          .color($r('sys.color.comp_divider'))
          .height($r('sys.float.Title_S'))

        Button($r('app.string.confirm'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.brand'))
          .layoutWeight(1)
          .onClick(() => this.submitNewGroup())
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
  }

  private openNewGroupDialog(): void {
    this.newGroupName = ''
    this.presentGroupDialog()
  }

  private presentGroupDialog(): void {
    this.getUIContext()
      .getPromptAction()
      .presentCustomDialog(() => this.newGroupDialog(), this.dialogController, {
        width: '96%',
        cornerRadius: $r('sys.float.ohos_id_corner_radius_dialog'),
        backgroundColor: $r('sys.color.comp_background_primary'),
      })
      .catch((error: BusinessError) => {
        LogUtil.error(`打开新建分组弹窗失败，错误码=${error.code}，错误信息=${error.message}`)
      })
  }

  private closeNewGroupDialog(): void {
    this.dialogController.close()
  }

  /** 新建落在当前浏览层；成功后停留本层，由用户自行决定是否选中（不自动选中、不自动收选择器）。 */
  private submitNewGroup(): void {
    if (this.viewModel.busy) {
      return
    }
    const name: string = this.newGroupName.trim()
    if (name.length === 0) {
      AppToast.showAboveSheets(this.getUIContext(), $r('app.string.group_name_required'))
      return
    }
    // 先关弹窗再落盘：落盘是异步写文件，等它的回调再 close 弹窗不会被关掉。
    this.dialogController.close()
    this.viewModel.createGroup(this.currentGroup.uuid, name).then((created: boolean) => {
      if (!created) {
        this.toastStatus()
      }
      this.onActivity()
    })
  }

  private toastStatus(): void {
    if (this.viewModel.status.length === 0) {
      return
    }
    AppToast.showAboveSheets(this.getUIContext(), this.viewModel.status)
  }

  private menuItem(icon: SymbolGlyphModifier, label: Resource, action: () => void,
    enabled: boolean = true): HdsNavigationMenuItemOptions {
    const content: HdsNavigationIconOptions = {
      icon: icon,
      type: IconStyleMode.SMALL,
      label: label,
      isEnabled: enabled,
      action: action,
    }
    return { content: content }
  }

  private menuItems(): HdsNavigationMenuItemOptions[] {
    const enabled: boolean = !this.viewModel.busy
    return [
      this.menuItem(this.newGroupIcon, $r('app.string.new_group'), () => this.openNewGroupDialog(), enabled),
      this.menuItem(this.confirmIcon,
        this.searching ? $r('app.string.group_pick_confirm') : $r('app.string.select_current_group'),
        () => this.confirmPick(), enabled),
      this.menuItem(this.closeIcon, $r('app.string.close'), () => this.onClose(), true),
    ]
  }

  @LocalBuilder
  breadcrumb() {
    Scroll(this.breadcrumbScroller) {
      Row({ space: $r('sys.float.padding_level2') }) {
        Button(this.rootName)
          .height($r('sys.float.Title_L'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_secondary'))
          .padding({ left: $r('sys.float.padding_level4'), right: $r('sys.float.padding_level4') })
          .onClick(() => this.jumpTo(0))

        ForEach(this.pathGroups, (group: VaultGroup, index: number) => {
          Row({ space: $r('sys.float.padding_level2') }) {
            SymbolGlyph($r('sys.symbol.chevron_forward'))
              .fontSize($r('sys.float.Body_S'))
              .fontColor([$r('sys.color.font_tertiary')])
            Button(group.name)
              .height($r('sys.float.Title_L'))
              .buttonStyle(ButtonStyleMode.TEXTUAL)
              .fontSize($r('sys.float.Body_M'))
              .fontColor(index === this.pathGroups.length - 1
                ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
              .padding({ left: $r('sys.float.padding_level4'), right: $r('sys.float.padding_level4') })
              .onClick(() => this.jumpTo(index + 1))
          }
        }, (group: VaultGroup) => group.uuid)
      }
      // 内容尺寸一变就把当前层级带回视野（等价 scrollIntoView）：首帧布局、下钻/回退层级、
      // 窗口尺寸变化都走这里。当前层级恒为末项，滚到末端即可，无需测量各项位置。
      .onAreaChange((_oldArea: Area, _newArea: Area) => this.breadcrumbScroller.scrollEdge(Edge.End))
      // 内边距放在内容上而不是外层 margin 上：滚动视口因此贴住左右边缘，
      // 首尾两项各自让出内边距。该值与下方渐隐长度取同一 token，滚到两端时末项不落在渐隐区里被压暗。
      .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
    }
    .width('100%')
    .margin({ bottom: $r('sys.float.padding_level6') })
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.Start)
    .fadingEdge(true, { fadingEdgeLength: LengthMetrics.resource($r('sys.float.padding_level8')) })
    .transition(this.fadeTransition)
  }

  @LocalBuilder
  groupList() {
    List() {
      ForEach(this.visibleGroups, (group: VaultGroup, index: number) => {
        GroupRow({
          name: group.name,
          subtitle: this.searching ? group.path : this.countText($r('app.string.group_entry_count'),
            group.entries.length),
          selected: this.searching && group.uuid === this.selectedGroupUuid,
          showChevron: !this.searching,
          onRowClick: () => {
            if (this.searching) {
              // 搜索态点选：只写瞬态选中并刷新高亮，不收半模态、不碰 editor。
              this.selectedGroupUuid = group.uuid
              this.onActivity()
              return
            }
            this.enterGroup(group)
          },
        })
        // 行高实测给重排位移用：副行恒为单行，全表行高一致。
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            this.rowShift.reportRowHeight(this.getUIContext().px2vp(newArea.height as number))
          })
          // 层级切换已有整层横移淡出，逐行转场会与之叠加，故切换期间不出行转场。
          .transition(this.levelSwitching ? TransitionEffect.IDENTITY
            : groupRowTransition(this.rowShift.shiftOf(group.uuid, index)))
      }, (group: VaultGroup) => `${this.rowVersion}_${group.uuid}`)
    }
    .width('100%')
    .height('auto')
    .scrollBar(BarState.Off)
    .divider({
      strokeWidth: 1,
      color: $r('sys.color.grid_menu_divider_color'),
      startMargin: this.dividerStartMargin,
      endMargin: $r('sys.float.padding_level8'),
    })
    .translate({ x: this.levelOffsetX })
    .opacity(this.levelOpacity)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.levelWidthVp = this.getUIContext().px2vp(newValue.width as number)
    })
    .transition(this.fadeTransition)
  }

  @LocalBuilder
  emptyHint() {
    Column() {
      // 浏览态无子分组与搜索无结果各有专属占位图，两态都是无文案的纯图形空态。
      Image(this.searching ? $r('app.media.group_search_empty') : $r('app.media.group_empty'))
        .width($r('app.float.vault_empty_icon_size'))
        .height($r('app.float.vault_empty_icon_size'))
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .translate({ x: this.levelOffsetX })
    .opacity(this.levelOpacity)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.levelWidthVp = this.getUIContext().px2vp(newValue.width as number)
    })
    .transition(this.fadeTransition)
  }

  build() {
    HdsNavigation() {
      Scroll() {
        Column() {
          if (!this.searching) {
            this.breadcrumb()
          }

          if (this.visibleGroups.length === 0) {
            this.emptyHint()
          } else {
            this.groupList()
          }
        }
        .width('100%')
        .height(this.visibleGroups.length === 0 ? '100%' : 'auto')
        .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ top: this.titleBarOffset + SEARCH_BAR_HEIGHT_VP, bottom: this.bottomOffset })
      .align(Alignment.Top)
      .onTouch(() => this.onActivity())
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      content: {
        // MODAL 半模态标题栏不渲染内置返回键（hideBackButton 文档：返回键仅 titleMode 为 MINI 时生效），
        // 因此返回图标走同版本引入的 subIcon 槽位：HDS 原生图标按钮，落在标题左侧。
        // 根层级不显示，返回语义由 navigateUp 统一裁决。
        subIcon: this.pathGroups.length === 0 ? undefined : {
          content: {
            icon: this.backIcon,
            label: $r('app.string.back'),
            isEnabled: true,
            action: () => this.navigateUp(),
          },
        },
        title: {
          mainTitle: $r('app.string.select_group'),
        },
        menu: {
          value: this.menuItems(),
        },
        bottomBuilder: {
          builder: () => this.searchBuilder(),
          height: SEARCH_BAR_HEIGHT_VP,
          showType: BottomBuilderShowType.DIRECTLY_SHOW,
        },
      },
    })
  }
}
