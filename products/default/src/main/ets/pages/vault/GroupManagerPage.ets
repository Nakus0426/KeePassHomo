import { BusinessError } from '@kit.BasicServicesKit'
import { LengthMetrics, promptAction, SymbolGlyphModifier, UIContext, uiMaterial, UIUtils } from '@kit.ArkUI'
import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavigationIconOptions,
  HdsNavigationMenuItemOptions,
  IconStyleMode,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { AnimationTokens, AppToast, VaultGroup } from '@ohos/common'
import { LogUtil, ResUtil } from '@pura/harmony-utils'
import { GroupRow, GroupRowShift, groupRowTransition } from '../../components/GroupRow'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'

// 分组名的长度上限：与分组选择器同规则，防异常输入，KDBX 组名本身无硬性限制。
const GROUP_NAME_MAX_LENGTH: number = 64

// 横移自身宽度的 20%，与分组选择器同参。
const LEVEL_TRANSITION_OFFSET_RATIO: number = 0.2

// 从 group 向上回溯到目标组的链路（含首尾）；目标不在子树内返回 undefined。
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

// 子树规模：子分组数与条目数，不含自身分组。
interface GroupSubtreeStat {
  groups: number
  entries: number
}

function subtreeStat(group: VaultGroup): GroupSubtreeStat {
  let groups: number = 0
  let entries: number = group.entries.length
  for (const child of group.groups) {
    const childStat: GroupSubtreeStat = subtreeStat(child)
    groups += childStat.groups + 1
    entries += childStat.entries
  }
  return { groups, entries }
}

function sameOrder(previous: string[], next: string[]): boolean {
  return previous.length === next.length
    && previous.every((uuid: string, index: number) => uuid === next[index])
}

// 分组管理页：面包屑 + 分组列表 + 全库搜索，行内左滑重命名与删除；入口暂未接线，路由已注册（groupManager）。
@ComponentV2
export struct GroupManagerPage {
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  // 浏览栈：根下顶层到当前层的分组链；空链表示停在根层。
  @Local private pathGroups: VaultGroup[] = []
  @Local private searchDraft: string = ''
  // 名称弹窗的输入草稿：弹窗内容是组件内 @Builder，直接读写本状态，无需参数中介。
  @Local private groupNameDraft: string = ''
  // 非空表示弹窗处于编辑模式，值即被改名的分组 uuid，用于区分新建与改名两条提交路径。
  @Local private renameGroupUuid: string = ''
  // 出场动画中的分组 uuid：行高先收 0，动画结束才落盘，避免列表跳动。
  @Local private removingGroupUuid: string = ''
  // 层级切换动画状态：横移量与透明度由 switchLevel 两段式驱动，宽度经 onAreaChange 实测。
  @Local private levelOffsetX: number = 0
  @Local private levelOpacity: number = 1
  @Local private levelWidthVp: number = 0
  @Local private levelSwitching: boolean = false
  // 行版本号：换词后自增让 ForEach 重建行，重排才有转场可播。
  @Local private rowVersion: number = 0
  private readonly rowShift: GroupRowShift = new GroupRowShift()
  // 面包屑滚动控制器：层级变化后把当前层级滚回视野。
  private readonly breadcrumbScroller: Scroller = new Scroller()
  private readonly viewModel: AppViewModel = appViewModel
  private readonly dialogController: promptAction.DialogController = new promptAction.DialogController()
  private readonly createIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.folder_badge_plus'))
      .fontColor([$r('sys.color.titlebar_icon_color')])
  // 纯淡入淡出：面包屑搜索态淡出、列表与空态互换共用；缩放交给行自身。
  private readonly fadeTransition: TransitionEffect = TransitionEffect.OPACITY
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })

  aboutToDisappear(): void {
    this.dialogController.close()
  }

  @Computed
  private get searching(): boolean {
    return this.searchDraft.trim().length > 0
  }

  @Computed
  private get readOnly(): boolean {
    return this.viewModel.currentSource().readOnly
  }

  // 当前层分组：根层取根分组，否则取浏览栈末项，恒有值。
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

  // 全库匹配组名与全路径，大小写不敏感。
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

  // 某个搜索词下的可见顺序：空词即当前浏览层；不读 @Computed，避免依赖其重算时机。
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

  // 根分组 uuid：根组是文档容器，不开放重命名与删除。
  @Computed
  private get rootUuid(): string {
    return this.viewModel.rootGroup().uuid
  }

  // 内容顶部避让：沉浸式标题栏之下，状态栏与标题栏高度都要让开。
  @Computed
  private get contentTopOffset(): number {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const paddingPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
    return this.getUIContext()
      .px2vp(this.immersiveLayout.topAvoidAreaHeightPx + titlebarHeightPx + paddingPx)
  }

  @Computed
  private get contentBottomOffset(): number {
    return this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx)
  }

  // 分割线与主文本左对齐：行内边距 + 圆形图标宽（字形加两侧内边距）+ 图标与文本间距。
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

  // 分组是否仍在可见分组树内：删除落盘后用它收敛浏览栈。
  private groupAlive(groupUuid: string): boolean {
    return this.viewModel.groups().some((group: VaultGroup) => group.uuid === groupUuid)
  }

  // 删除确认文案：把子分组数与条目数一并作为风险提示，数量为 0 的项不出现。
  private deleteGroupMessage(group: VaultGroup): string {
    const stat: GroupSubtreeStat = subtreeStat(group)
    const parts: string[] = []
    if (stat.groups > 0) {
      parts.push(this.countText($r('app.string.subgroup_count'), stat.groups))
    }
    if (stat.entries > 0) {
      parts.push(this.countText($r('app.string.group_entry_count'), stat.entries))
    }
    const base: string = ResUtil.getStringSync($r('app.string.delete_group_message'))
      .replace('%s', group.name)
    if (parts.length === 0) {
      return base
    }
    const risk: string = ResUtil.getStringSync($r('app.string.delete_group_risk'))
      .replace('%s', parts.join('、'))
    return `${risk}\n${base}`
  }

  // 层级切换：前进时旧层左移淡出、新层自右侧进入，后退反向；与生成器页签切换同参。
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
      // 入场起点必须同步落到渲染树，否则入场动画起点仍是退场终点，新层会反向进入。
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

  // 点行进层：浏览态进入该行子层；搜索态跳到命中分组的所在层并清空搜索词，便于接着看它的内容。
  private openGroup(group: VaultGroup): void {
    if (this.searching) {
      const chain: VaultGroup[] = this.chainToGroup(group.uuid)
      this.switchLevel(chain.length > this.pathGroups.length, () => {
        this.searchDraft = ''
        this.pathGroups = chain
      })
      this.viewModel.recordActivity()
      return
    }
    this.switchLevel(true, () => this.pathGroups = this.pathGroups.concat([group]))
    this.viewModel.recordActivity()
  }

  // 面包屑跳转：depth 为保留的层数，0 回根层。
  private jumpTo(depth: number): void {
    const nextPath: VaultGroup[] = this.pathGroups.slice(0, depth)
    this.switchLevel(depth > nextPath.length, () => this.pathGroups = nextPath)
    this.viewModel.recordActivity()
  }

  @Builder
  private groupNameDialog() {
    Column({ space: $r('sys.float.padding_level6') }) {
      Text(this.renameGroupUuid.length === 0 ? $r('app.string.new_group') : $r('app.string.rename_group'))
        .fontSize($r('sys.float.Title_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)

      TextInput({ placeholder: $r('app.string.group_name_placeholder'), text: this.groupNameDraft })
        .fontSize($r('sys.float.Body_L'))
        .maxLength(GROUP_NAME_MAX_LENGTH)
        .height($r('app.float.control_height'))
        .backgroundColor(Color.Transparent)
        .showUnderline(true)
        .underlineColor({ typing: $r('sys.color.brand') })
        .onChange((value: string) => this.groupNameDraft = value)

      Row({ space: $r('sys.float.padding_level6') }) {
        Button($r('app.string.cancel'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
          .onClick(() => this.closeGroupDialog())

        Divider()
          .vertical(true)
          .color($r('sys.color.comp_divider'))
          .height($r('sys.float.Title_S'))

        Button($r('app.string.confirm'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.brand'))
          .layoutWeight(1)
          .onClick(() => this.submitGroupName())
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
  }

  // 新建落在当前浏览层；重命名沿用同一弹窗，只换标题并回填当前名称。
  private openCreateDialog(): void {
    this.renameGroupUuid = ''
    this.groupNameDraft = ''
    this.presentGroupDialog()
  }

  private openRenameDialog(group: VaultGroup): void {
    this.renameGroupUuid = group.uuid
    this.groupNameDraft = group.name
    this.presentGroupDialog()
  }

  private presentGroupDialog(): void {
    this.getUIContext()
      .getPromptAction()
      .presentCustomDialog(() => this.groupNameDialog(), this.dialogController, {
        width: '96%',
        cornerRadius: $r('sys.float.ohos_id_corner_radius_dialog'),
        backgroundColor: $r('sys.color.comp_background_primary'),
      })
      .catch((error: BusinessError) => {
        LogUtil.error(`打开分组弹窗失败，错误码=${error.code}，错误信息=${error.message}`)
      })
  }

  private closeGroupDialog(): void {
    this.dialogController.close()
  }

  private submitGroupName(): void {
    if (this.viewModel.busy) {
      return
    }
    const name: string = this.groupNameDraft.trim()
    if (name.length === 0) {
      AppToast.show(this.getUIContext(), $r('app.string.group_name_required'))
      return
    }
    const renameUuid: string = this.renameGroupUuid
    // 先关弹窗再落盘：落盘是异步写文件，等它的回调再 close 弹窗不会被关掉。
    this.dialogController.close()
    if (renameUuid.length > 0) {
      this.submitRename(name, renameUuid)
      return
    }
    this.viewModel.createGroup(this.currentGroup.uuid, name).then((created: boolean) => {
      if (!created) {
        this.toastStatus()
      }
      this.viewModel.recordActivity()
    })
  }

  private submitRename(name: string, groupUuid: string): void {
    this.viewModel.renameGroup(groupUuid, name).then((renamed: boolean) => {
      if (!renamed) {
        this.toastStatus()
      }
      this.renameGroupUuid = ''
      this.viewModel.recordActivity()
    })
  }

  private confirmDeleteGroup(group: VaultGroup): void {
    const options: AlertDialogParamWithButtons = {
      title: $r('app.string.delete_group_title'),
      message: this.deleteGroupMessage(group),
      primaryButton: {
        value: $r('app.string.cancel'),
        action: () => {
        },
      },
      secondaryButton: {
        value: $r('app.string.delete_group'),
        fontColor: $r('sys.color.warning'),
        action: () => this.deleteGroup(group),
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  // 删除分组：先把行高收 0 再落盘；落盘后过滤浏览栈，等价于截断到最近存活层。
  private deleteGroup(group: VaultGroup): void {
    const uiContext: UIContext = this.getUIContext()
    const exitParam: AnimateParam = {
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    }
    exitParam.onFinish = () => {
      this.viewModel.deleteGroup(group.uuid).then((deleted: boolean) => {
        if (!deleted) {
          const restoreParam: AnimateParam = {
            duration: AnimationTokens.STATE_TRANSITION_DURATION,
            curve: AnimationTokens.STATE_TRANSITION_CURVE,
          }
          uiContext.animateTo(restoreParam, () => this.removingGroupUuid = '')
          this.toastStatus()
          return
        }
        this.pathGroups = this.pathGroups.filter((item: VaultGroup) => this.groupAlive(item.uuid))
      })
    }
    uiContext.animateTo(exitParam, () => this.removingGroupUuid = group.uuid)
  }

  private toastStatus(): void {
    if (this.viewModel.status.length === 0) {
      return
    }
    AppToast.show(this.getUIContext(), this.viewModel.status)
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
    const enabled: boolean = !this.viewModel.busy && !this.readOnly
    return [this.menuItem(this.createIcon, $r('app.string.new_group'), () => this.openCreateDialog(), enabled)]
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
        .onSubmit(() => this.viewModel.recordActivity())
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
  }

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
      // 内容尺寸一变就把当前层级带回视野：当前层级恒为末项，滚到末端即可。
      .onAreaChange((_oldArea: Area, _newArea: Area) => this.breadcrumbScroller.scrollEdge(Edge.End))
      // 内边距放在内容上让滚动视口贴边；与渐隐长度取同一 token，两端末项不被压暗。
      .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
    }
    .width('100%')
    .margin({ bottom: $r('sys.float.padding_level6') })
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .align(Alignment.Start)
    // 溢出侧渐隐：内容在哪一侧被裁掉，哪一侧淡出。
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
          showChevron: true,
          actionsEnabled: !this.readOnly && group.uuid !== this.rootUuid,
          removing: this.removingGroupUuid === group.uuid,
          onRowClick: () => this.openGroup(group),
          onEdit: () => this.openRenameDialog(group),
          onDelete: () => this.confirmDeleteGroup(group),
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
    HdsNavDestination() {
      Scroll() {
        Column() {
          this.searchBuilder()

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
      .padding({ top: this.contentTopOffset, bottom: this.contentBottomOffset })
      .align(Alignment.Top)
    }
    .titleBar({
      avoidLayoutSafeArea: true,
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
        backIcon: {},
        title: {
          mainTitle: $r('app.string.group_manager'),
        },
        menu: {
          value: this.menuItems(),
        },
      },
    })
    .backgroundColor($r('sys.color.background_secondary'))
  }
}

@Builder
export function groupManagerPageBuilder() {
  GroupManagerPage()
}
