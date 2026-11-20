import { BusinessError } from '@kit.BasicServicesKit'
import { promptAction, UIContext, UIUtils } from '@kit.ArkUI'
import { AnimationTokens, VaultGroup } from '@ohos/common'
import { LogUtil, ResUtil } from '@pura/harmony-utils'
import { DsBottomActionBar } from './DsBottomActionBar'
import { DsBreadcrumb, DsBreadcrumbItemData, DsBreadcrumbSize } from './DsBreadcrumb'
import { DsButton, DsButtonVariant } from './DsButton'
import { DsControlSize } from './DsControlSize'
import { DsDialog } from './DsDialog'
import { DsField } from './DsField'
import { DsHalfModalSheet } from './DsHalfModalSheet'
import { DsInput, DsInputTone } from './DsInput'
import { DsPageHeader, DsPageHeaderAction, DsPageHeaderSize } from './DsPageHeader'
import { findGroupChain, LEVEL_TRANSITION_OFFSET_RATIO } from './GroupPickerShared'

// 新建分组名的长度上限：防异常输入，KDBX 组名本身无硬性限制。
const NEW_GROUP_NAME_MAX_LENGTH: number = 64
// 设计稿分组行 56 高；pen 无同名变量，属组件自身几何。
const GROUP_ROW_HEIGHT_VP: number = 56

@ComponentV2
struct GroupPickerRow {
  @Require @Param name: string
  @Require @Param subtitle: string
  @Param selected: boolean = false
  @Param showChevron: boolean = false
  @Event onTap: () => void = () => {
  }
  @Local private hovered: boolean = false
  @Local private pressed: boolean = false

  private rowFill(): ResourceColor {
    if (this.pressed) {
      return $r('app.color.ds_surface_highest')
    }
    if (this.hovered || this.selected) {
      return $r('app.color.ds_surface_hover')
    }
    return $r('app.color.ds_surface_lowest')
  }

  build() {
    Row({ space: $r('app.float.ds_space_md') }) {
      SymbolGlyph($r('app.string.symbol_folder'))
        .fontSize($r('app.float.ds_icon_md'))
        .fontColor([$r('app.color.ds_text_secondary')])
        .foregroundColor($r('app.color.ds_text_secondary'))

      Column({ space: $r('app.float.ds_space_2') }) {
        Text(this.name)
          .width('100%')
          .fontSize($r('app.float.ds_font_title'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(this.subtitle)
          .width('100%')
          .fontSize($r('app.float.ds_font_body_sm'))
          .fontColor($r('app.color.ds_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.selected) {
        SymbolGlyph($r('app.string.symbol_check'))
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([$r('app.color.ds_primary')])
          .foregroundColor($r('app.color.ds_primary'))
      } else if (this.showChevron) {
        SymbolGlyph($r('app.string.symbol_chevron_right'))
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([$r('app.color.ds_text_tertiary')])
          .foregroundColor($r('app.color.ds_text_tertiary'))
      }
    }
    .width('100%')
    .height(GROUP_ROW_HEIGHT_VP)
    .padding({ left: $r('app.float.ds_gutter'), right: $r('app.float.ds_gutter') })
    .backgroundColor(this.rowFill())
    .animation(AnimationTokens.FEEDBACK_ANIMATION)
    .onHover((isHover: boolean) => {
      this.hovered = isHover
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressed = true
        return
      }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false
      }
    })
    .onClick(() => this.onTap())
  }
}

// 选择器数据源：用函数下发，宿主每次重算都读取最新分组（含条目数），避免半模态内容复用后数据滞留。
export interface GroupPickerSource {
  rootGroup: VaultGroup
  // 根下顶层分组，已排除回收站。
  topLevelGroups: VaultGroup[]
  // 全量分组（含根组，已排除回收站），供全库搜索。
  allGroups: VaultGroup[]
}

interface GroupPickerEmptyCopy {
  title: Resource
  body: Resource
}

// 通用分组选择半模态：宿主只提供分组数据与落稿回调，开合与归属仍由宿主负责。
@ComponentV2
export struct DsGroupPicker {
  @Require @Param groupSource: () => GroupPickerSource
  // 打开时定位到的分组；空串或根组都停在根层。
  @Param initialGroupUuid: string = ''
  @Param busy: boolean = false
  // 确认选中后由宿主收起半模态并落稿分组。
  @Event onPicked: (groupUuid: string) => void = () => {
  }
  @Event onClose: () => void = () => {
  }
  // 新建分组由宿主落盘与提示；本组件只发信号。
  @Event onCreateGroup: (parentUuid: string, name: string) => void = () => {
  }
  @Event onActivity: () => void = () => {
  }
  // 宿主拦截到返回类事件时调用；返回 true 表示这次返回已被消费。
  @Event onBackHandler: (handler: () => boolean) => void = () => {
  }
  // 浏览栈只存 uuid：层级名称与子分组每次从数据源重取，条目数变化或重命名都能及时反映。
  @Local private pathUuids: string[] = []
  @Local private searchDraft: string = ''
  // 搜索态选中项独立存放：浏览层不参与搜索确认，避免确认到看不见的分组。
  @Local private searchSelectionUuid: string = ''
  @Local private newGroupName: string = ''
  // 新建分组名的校验反馈：提交时置入，输入变化后按同一规则即时重算。
  @Local private newGroupNameError: ResourceStr | undefined = undefined
  @Local private newGroupNameShake: number = 0
  // 层级切换动画状态：横移量与透明度由 switchLevel 两段式驱动，宽度经 onAreaChange 实测。
  @Local private levelOffsetX: number = 0
  @Local private levelOpacity: number = 1
  @Local private levelWidthVp: number = 0
  @Local private levelSwitching: boolean = false
  // 底部确认栏高度：列表按实测高度避让，最后一行不被遮挡。
  @Local private footerHeight: number = 0
  private readonly scroller: Scroller = new Scroller()
  private readonly dialogController: promptAction.DialogController = new promptAction.DialogController()
  private readonly fadeTransition: TransitionEffect = TransitionEffect.OPACITY
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })

  aboutToAppear(): void {
    this.pathUuids = this.chainToGroup(this.initialGroupUuid)
    this.onBackHandler(() => this.navigateUp())
  }

  @Computed
  private get source(): GroupPickerSource {
    return this.groupSource()
  }

  @Computed
  private get pathGroups(): VaultGroup[] {
    return this.pathUuids.map((uuid: string) => this.findGroup(uuid))
  }

  private findGroup(uuid: string): VaultGroup {
    const group: VaultGroup | undefined = this.source.allGroups.find((item: VaultGroup) => item.uuid === uuid)
    return group === undefined ? this.source.rootGroup : group
  }

  // 半模态销毁时连带关闭新建弹窗：拖拽收起不应把输入弹窗留在窗口上。
  aboutToDisappear(): void {
    this.dialogController.close()
  }

  @Computed
  private get searching(): boolean {
    return this.searchDraft.trim().length > 0
  }

  @Computed
  private get currentGroup(): VaultGroup {
    if (this.pathUuids.length === 0) {
      return this.source.rootGroup
    }
    return this.pathGroups[this.pathGroups.length - 1]
  }

  // 根层用数据源给的顶层分组：回收站已在数据层排除，避免用户选到回收站。
  @Computed
  private get currentGroups(): VaultGroup[] {
    return this.pathUuids.length === 0 ? this.source.topLevelGroups : this.currentGroup.groups
  }

  // 全库匹配组名与全路径，大小写不敏感。
  @Computed
  private get searchResults(): VaultGroup[] {
    const keyword: string = this.searchDraft.trim().toLocaleLowerCase()
    if (keyword.length === 0) {
      return []
    }
    return this.source.allGroups.filter((group: VaultGroup) =>
    group.name.toLocaleLowerCase().includes(keyword) || group.path.toLocaleLowerCase().includes(keyword))
  }

  @Computed
  private get visibleGroups(): VaultGroup[] {
    return this.searching ? this.searchResults : this.currentGroups
  }

  @Computed
  private get breadcrumbItems(): DsBreadcrumbItemData[] {
    const items: DsBreadcrumbItemData[] = [{
      key: this.source.rootGroup.uuid,
      label: this.source.rootGroup.name,
      icon: $r('app.string.symbol_folder'),
    }]
    this.pathGroups.forEach((group: VaultGroup, index: number) => {
      items.push({ key: `${group.uuid}_${index}`, label: group.name })
    })
    return items
  }

  // 搜索态不展示面包屑，标题栏底部区随之收高一层；高度由输入框 / 面包屑 token 推导。
  @Computed
  private get titleBarBottomHeight(): number {
    const searchHeightPx: number = ResUtil.getNumber($r('app.float.ds_input_height_md').id)
      + ResUtil.getNumber($r('app.float.ds_space_sm').id) * 2
    const searchHeightVp: number = this.getUIContext().px2vp(searchHeightPx)
    if (this.searching) {
      return searchHeightVp
    }
    return searchHeightVp + this.getUIContext().px2vp(ResUtil.getNumber($r('app.float.ds_breadcrumb_height_md').id))
  }

  @Computed
  private get confirmUuid(): string {
    return this.searching ? this.searchSelectionUuid : this.currentGroup.uuid
  }

  @Computed
  private get confirmDisabled(): boolean {
    return this.busy || (this.searching && this.searchSelectionUuid.length === 0)
  }

  @Computed
  private get emptyCopy(): GroupPickerEmptyCopy {
    if (this.searching) {
      return {
        title: $r('app.string.group_picker_no_result_title'),
        body: $r('app.string.group_picker_no_result_body'),
      }
    }
    if (this.pathUuids.length === 0) {
      return {
        title: $r('app.string.group_picker_empty_root_title'),
        body: $r('app.string.group_picker_empty_root_body'),
      }
    }
    return {
      title: $r('app.string.group_picker_empty_title'),
      body: $r('app.string.group_picker_empty_body'),
    }
  }

  @Computed
  private get levelSlideOffset(): number {
    return this.levelWidthVp * LEVEL_TRANSITION_OFFSET_RATIO
  }

  private chainToGroup(groupUuid: string): string[] {
    if (groupUuid.length === 0 || groupUuid === this.source.rootGroup.uuid) {
      return []
    }
    const chain: VaultGroup[] | undefined = findGroupChain(this.source.rootGroup, groupUuid)
    return chain === undefined ? [] : chain.slice(1).map((group: VaultGroup) => group.uuid)
  }

  // 层级切换：前进时旧层左移淡出、新层自右侧进入，后退反向。
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

  private enterGroup(group: VaultGroup): void {
    this.onActivity()
    this.switchLevel(true, () => this.pathUuids = this.pathUuids.concat([group.uuid]))
  }

  // 面包屑跳转：depth 为保留的层数，0 回根层。
  private jumpTo(depth: number): void {
    const nextPath: string[] = this.pathUuids.slice(0, depth)
    this.switchLevel(false, () => this.pathUuids = nextPath)
    this.onActivity()
  }

  private confirmPick(): void {
    if (this.confirmDisabled) {
      return
    }
    this.onActivity()
    this.onPicked(this.confirmUuid)
  }

  // 返回一步：搜索态先退出搜索，否则回到上一层；返回 true 表示本次返回已被消费。
  private navigateUp(): boolean {
    if (this.searching) {
      this.clearSearch()
      return true
    }
    if (this.pathUuids.length === 0) {
      return false
    }
    if (this.levelSwitching) {
      // 层级动画进行中：此时层栈正在变，先吃掉这次返回，免得动画中途误收半模态。
      return true
    }
    this.jumpTo(this.pathUuids.length - 1)
    return true
  }

  private clearSearch(): void {
    this.searchDraft = ''
    this.searchSelectionUuid = ''
    this.onActivity()
  }

  private applyQuery(value: string): void {
    this.searchDraft = value
    this.searchSelectionUuid = ''
    this.onActivity()
  }

  @LocalBuilder
  private searchLeading() {
    SymbolGlyph($r('app.string.symbol_search'))
      .fontSize($r('app.float.ds_icon_sm'))
      .fontColor([$r('app.color.ds_text_secondary')])
      .foregroundColor($r('app.color.ds_text_secondary'))
  }

  @LocalBuilder
  private searchTrailing() {
    if (this.searchDraft.length > 0) {
      DsButton({
        variant: DsButtonVariant.Text,
        buttonSize: DsControlSize.Small,
        iconOnly: true,
        leadingIcon: $r('app.string.symbol_close'),
        iconSizeOverride: $r('app.float.ds_icon_xs'),
        iconColorOverride: $r('app.color.ds_text_secondary'),
        accessibilityLabelResource: $r('app.string.close'),
        onTap: () => this.clearSearch(),
      })
    }
  }

  private headerActions(): DsPageHeaderAction[] {
    return [
      {
        icon: $r('app.string.symbol_create_folder'),
        label: $r('app.string.new_group'),
        enabled: !this.busy,
        onTap: () => this.openNewGroupDialog(),
      },
      {
        icon: $r('app.string.symbol_close'),
        label: $r('app.string.close'),
        onTap: () => this.onClose(),
      },
    ]
  }

  @LocalBuilder
  private headerBar() {
    DsPageHeader({
      title: $r('app.string.select_group'),
      headerSize: DsPageHeaderSize.Small,
      showBack: false,
      actions: this.headerActions(),
    })
  }

  // 标题栏底部区：搜索行 + 面包屑，两者随标题栏材质一起悬浮并被内容穿透。
  @LocalBuilder
  private searchAndBreadcrumb() {
    Column() {
      Row() {
        DsInput({
          text: this.searchDraft,
          placeholder: $r('app.string.search_groups'),
          leadingBuilder: this.searchLeading,
          trailingBuilder: this.searchTrailing,
          onChange: (value: string) => this.applyQuery(value),
          onSubmit: () => this.onActivity(),
        })
      }
      .width('100%')
      .padding({
        left: $r('app.float.ds_gutter'),
        right: $r('app.float.ds_gutter'),
        top: $r('app.float.ds_space_sm'),
        bottom: $r('app.float.ds_space_sm'),
      })

      if (!this.searching) {
        DsBreadcrumb({
          items: this.breadcrumbItems,
          breadcrumbSize: DsBreadcrumbSize.Medium,
          disabled: this.levelSwitching,
          onSelect: (index: number) => this.jumpTo(index),
        })
          .height($r('app.float.ds_breadcrumb_height_md'))
          .padding({ left: $r('app.float.ds_gutter'), right: $r('app.float.ds_gutter') })
      }
    }
    .width('100%')
  }

  @LocalBuilder
  private groupList() {
    List({ scroller: this.scroller }) {
      ForEach(this.visibleGroups, (group: VaultGroup) => {
        ListItem() {
          GroupPickerRow({
            name: group.name,
            subtitle: this.searching ? group.path : ResUtil.getStringSync($r('app.string.group_entry_count'),
              [String(group.entries.length)]),
            selected: this.searching && group.uuid === this.searchSelectionUuid,
            showChevron: !this.searching,
            onTap: () => {
              if (this.searching) {
                this.searchSelectionUuid = group.uuid
                this.onActivity()
                return
              }
              this.enterGroup(group)
            },
          })
        }
        .width('100%')
      }, (group: VaultGroup) => group.uuid)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    // alwaysEnabled：内容不足一屏时也由列表接管竖向手势并回弹，避免拖动整个半模态。
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true, effectEdge: EffectEdge.START | EffectEdge.END })
    .padding({ top: $r('app.float.ds_space_sm'), bottom: this.footerHeight })
    // 滚动穿透：列表内容进入悬浮标题栏下方，由标题栏渐变模糊覆盖。
    .clip(false)
    .translate({ x: this.levelOffsetX })
    .opacity(this.levelOpacity)
    .onTouch(() => this.onActivity())
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.levelWidthVp = this.getUIContext().px2vp(newValue.width as number)
    })
    .transition(this.fadeTransition)
  }

  @LocalBuilder
  private emptyState() {
    Scroll() {
      this.emptyContent()
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    // 空态同样由滚动容器接管竖向手势，避免上下滑动带动半模态。
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true, effectEdge: EffectEdge.START | EffectEdge.END })
    .clip(false)
    .align(Alignment.Top)
    .translate({ x: this.levelOffsetX })
    .opacity(this.levelOpacity)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.levelWidthVp = this.getUIContext().px2vp(newValue.width as number)
    })
    .transition(this.fadeTransition)
  }

  @LocalBuilder
  private emptyContent() {
    Column({ space: $r('app.float.ds_space_16') }) {
      Image(this.searching ? $r('app.media.ds_empty_group_search') : $r('app.media.ds_empty_group'))
        .width($r('app.float.ds_empty_illustration_width'))
        .aspectRatio(this.searching ? 485 / 379 : 585 / 448)
        .objectFit(ImageFit.Contain)

      Text(this.emptyCopy.title)
        .fontSize($r('app.float.ds_font_headline_md'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))

      Text(this.emptyCopy.body)
        .width($r('app.float.ds_empty_body_width'))
        .textAlign(TextAlign.Center)
        .fontSize($r('app.float.ds_font_body_sm'))
        .lineHeight($r('app.float.ds_line_height_body_sm'))
        .fontColor($r('app.color.ds_text_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({
      top: $r('app.float.ds_space_24'),
      bottom: this.footerHeight,
      left: $r('app.float.ds_space_24'),
      right: $r('app.float.ds_space_24'),
    })
  }

  @LocalBuilder
  private bodyContent() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.visibleGroups.length === 0) {
        this.emptyState()
      } else {
        this.groupList()
      }
    }
    .width('100%')
    .height('100%')
  }

  @LocalBuilder
  private confirmAction() {
    DsButton({
      label: $r('app.string.group_pick_confirm'),
      variant: DsButtonVariant.Filled,
      buttonSize: DsControlSize.Medium,
      fullWidth: true,
      disabled: this.confirmDisabled,
      onTap: () => this.confirmPick(),
    })
  }

  // 与密码生成器一致：底栏用渐隐遮罩，列表可滚动到渐变下方，底部安全区由组件自身留出。
  @LocalBuilder
  private footerBar() {
    DsBottomActionBar({
      surfaceColor: $r('app.color.ds_surface_lowest'),
      fadeColor: $r('app.color.ds_surface_lowest_transparent'),
      contentBuilder: this.confirmAction,
      onHeightChange: (height: number) => {
        this.footerHeight = height
      },
    })
  }

  private openNewGroupDialog(): void {
    this.newGroupName = ''
    this.newGroupNameError = undefined
    this.presentNewGroupDialog()
  }

  private presentNewGroupDialog(): void {
    this.getUIContext()
      .getPromptAction()
      .presentCustomDialog(() => this.newGroupDialog(), this.dialogController, {
        backgroundColor: Color.Transparent,
        backgroundBlurStyle: BlurStyle.NONE,
        cornerRadius: 0,
        width: $r('app.float.dialog_width'),
        alignment: DialogAlignment.Center,
        maskColor: $r('app.color.ds_scrim'),
      })
      .catch((error: BusinessError) => {
        LogUtil.error(`打开新建分组弹窗失败，错误码=${error.code}，错误信息=${error.message}`)
      })
  }

  // 同一套规则既用于提交，也用于错误已出现后的即时重算。
  private validateNewGroupName(value: string): ResourceStr | undefined {
    const name: string = value.trim()
    if (name.length === 0) {
      return $r('app.string.group_name_required')
    }
    if (name.length > NEW_GROUP_NAME_MAX_LENGTH) {
      return $r('app.string.group_name_too_long')
    }
    return undefined
  }

  private applyNewGroupName(value: string): void {
    this.newGroupName = value
    if (this.newGroupNameError !== undefined) {
      this.newGroupNameError = this.validateNewGroupName(value)
    }
  }

  @LocalBuilder
  private newGroupInputField() {
    DsInput({
      text: this.newGroupName,
      placeholder: $r('app.string.group_name_placeholder'),
      tone: this.newGroupNameError === undefined ? DsInputTone.Default : DsInputTone.Error,
      onChange: (value: string) => this.applyNewGroupName(value),
      onSubmit: () => this.submitNewGroup(),
    })
  }

  @LocalBuilder
  private newGroupInput() {
    DsField({
      feedback: this.newGroupNameError,
      reserveFeedbackSpace: true,
      shakeTrigger: this.newGroupNameShake,
      contentBuilder: this.newGroupInputField,
    })
  }

  @Builder
  private newGroupDialog() {
    DsDialog({
      title: $r('app.string.new_group'),
      cancelLabel: $r('app.string.cancel'),
      confirmLabel: $r('app.string.confirm'),
      busy: this.busy,
      contentBuilder: this.newGroupInput,
      onCancel: () => this.dialogController.close(),
      onConfirm: () => this.submitNewGroup(),
    })
  }

  // 新建落在当前浏览层；成功后停留本层，由用户自行决定是否选中。
  private submitNewGroup(): void {
    if (this.busy) {
      return
    }
    const name: string = this.newGroupName.trim()
    const error: ResourceStr | undefined = this.validateNewGroupName(name)
    this.newGroupNameError = error
    if (error !== undefined) {
      this.newGroupNameShake++
      return
    }
    // 先关弹窗再落盘：落盘是异步写文件，等它的回调再 close 弹窗不会被关掉。
    this.dialogController.close()
    this.onCreateGroup(this.currentGroup.uuid, name)
    this.onActivity()
  }

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
}
