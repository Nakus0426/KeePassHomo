import { BusinessError } from '@kit.BasicServicesKit'
import { LengthMetrics, promptAction } from '@kit.ArkUI'
import { AnimationTokens, ItemTemplate } from '@ohos/common'
import {
  hdsMaterial,
  HideMode,
  HdsNavigation,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { LogUtil, ResUtil } from '@pura/harmony-utils'
import { DsBottomActionBar } from '../../components/DsBottomActionBar'
import { DsButton, DsButtonTone, DsButtonVariant } from '../../components/DsButton'
import { DsContextMenu } from '../../components/DsContextMenu'
import { DsDialog, DsDialogTone } from '../../components/DsDialog'
import { DsMenuGroup } from '../../components/DsMenuGroup'
import { DsMenuItem, DsMenuItemTheme } from '../../components/DsMenuItem'
import { dsSheetOptions } from '../../components/DsSheetOptions'
import { DsNotice, DsNoticeTone } from '../../components/DsNotice'
import { PASSWORD_FONT_FAMILY } from '../../constants/FontConstants'
import { TAB_BAR_FLOAT_TOP_INSET_VP } from '../../constants/TabBarMetrics'
import {
  VAULT_FILTER_BAR_HEIGHT_VP,
  VAULT_TITLE_BAR_MASK_EXTRA_HEIGHT_VP,
} from '../../constants/VaultHeaderMetrics'
import { appSessionState, AppSessionState } from '../../state/AppSessionState'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { ENTRY_FIELD_PASSWORD, ENTRY_FIELD_USERNAME } from '../../viewmodel/EntryPresentation'
import { EntryGroupHeaderModel, EntryListItem, EntryListItemKind, EntryRowModel } from '../../viewmodel/EntryRowModel'
import { HomeEntryListViewModel, homeEntryListViewModel } from '../../viewmodel/HomeEntryListViewModel'
import { HomeSnapshotCause, VaultHomeViewModel, vaultHomeViewModel } from '../../viewmodel/VaultHomeViewModel'
import { entrySheetViewModel } from '../../viewmodel/EntrySheetViewModel'
import { EntrySheet } from './EntrySheet'
import { EntryTemplatePicker } from './EntryTemplatePicker'
import { VaultEntryRow } from './VaultEntryRow'
import { animateBatchTransition, vaultTabChrome } from './VaultTabChrome'
import { DsControlSize } from '../../components/DsControlSize'
import { DsToastHost } from '../../components/DsToast'

@ComponentV2
export struct VaultHomePage {
  private readonly scroller: Scroller = new Scroller()
  @Local private session: AppSessionState = appSessionState
  @Local private home: VaultHomeViewModel = vaultHomeViewModel
  @Local private list: HomeEntryListViewModel = homeEntryListViewModel
  @Local private app: AppViewModel = appViewModel
  @Local private templatePickerVisible: boolean = false
  @Local private fabHasAppeared: boolean = false
  @Local private batchBarHeight: number = 0
  @Local private deleteDialogBatch: boolean = false
  @Local private deleteBusy: boolean = false
  private removalToken: number = 0
  // 离场动画开始时在视口内的行：只有它们需要逐行收缩，其余离场行直接占零高度，避免整表逐行挂载。
  private visibleStart: number = 0
  private visibleEnd: number = 0
  private removalVisibleKeys: Set<string> = new Set()
  private removalLeavingKeys: Set<string> = new Set()
  private readonly deleteDialogController: promptAction.DialogController = new promptAction.DialogController()
  private pendingDeleteRow: EntryRowModel | undefined = undefined
  private pendingMenuAction: (() => void) | undefined = undefined
  // ArkUI 菜单容器固定 4vp 内边距，负边距盖住，避免露出默认模糊材质圈。
  private readonly contextMenuSystemInset: number = 4
  private pickedTemplate: ItemTemplate | undefined = undefined
  private pickedGroupUuid: string = ''
  private readonly stateSwitchTransition: TransitionEffect = TransitionEffect.OPACITY
    .animation(AnimationTokens.FEEDBACK_ANIMATION)

  aboutToAppear(): void {
    this.home.showChrome()
    this.list.subscribeHoldingHand()
    this.list.refresh()
  }

  aboutToDisappear(): void {
    this.list.unsubscribeHoldingHand()
  }

  @Monitor('home.entries')
  onEntriesChanged(): void {
    if (this.session.vaultLocked) {
      this.list.refresh()
      return
    }
    // 搜索逐字符刷新：只做整体淡入淡出，不播逐行离场收缩，避免连续输入时反复打断列表布局。
    if (this.home.snapshotCause === HomeSnapshotCause.Search) {
      this.getUIContext().animateTo(AnimationTokens.FEEDBACK_ANIMATION, () => {
        this.list.refresh()
      })
      return
    }
    const leaving: EntryListItem[] = this.list.leavingItems()
    if (leaving.length > 0) {
      this.animateRemoval(leaving)
      return
    }
    this.getUIContext().animateTo(AnimationTokens.FEEDBACK_ANIMATION, () => {
      this.list.refresh()
    })
  }

  // 行与分组头先收缩高度并淡出，下方内容随收缩上移，动画结束再刷新移除节点。
  private animateRemoval(leaving: EntryListItem[]): void {
    const token: number = ++this.removalToken
    this.removalLeavingKeys = new Set(leaving.map((item: EntryListItem) => item.key))
    const visible: EntryListItem[] = this.list.items.slice(this.visibleStart, this.visibleEnd + 1)
    this.removalVisibleKeys = new Set(visible.map((item: EntryListItem) => item.key))
    // 只有视口内的离场行需要真的收缩，其余行由占位分支挡住，避免整表写行状态。
    const collapsing: EntryListItem[] = visible.filter((item: EntryListItem) =>
    this.removalLeavingKeys.has(item.key))
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.EASE_EXIT,
      onFinish: () => {
        if (token !== this.removalToken) {
          return
        }
        this.list.refresh()
        this.removalLeavingKeys.clear()
        this.removalVisibleKeys.clear()
      },
    }, () => {
      for (const item of collapsing) {
        const model: EntryRowModel | EntryGroupHeaderModel = item.row ?? item.header!
        model.leaving = true
      }
    })
  }

  @Monitor('app.status')
  onStatusChanged(): void {
    if (this.app.status.length > 0) {
      DsToastHost.show(this.getUIContext(), this.app.status)
    }
  }

  @Computed
  get bottomAvoidHeight(): number {
    const gapPx: number = ResUtil.getNumber($r('app.float.ds_space_sm').id)
    return TAB_BAR_FLOAT_TOP_INSET_VP + this.getUIContext().px2vp(gapPx)
  }

  @Computed
  get contentBottomAvoid(): number {
    if (!this.home.batchMode) {
      return this.bottomAvoidHeight
    }
    const gapPx: number = ResUtil.getNumber($r('app.float.ds_space_sm').id)
    return this.batchBarHeight + this.getUIContext().px2vp(gapPx)
  }

  @Computed
  get readOnly(): boolean {
    return this.app.isReadOnly()
  }

  @Computed
  get showNewEntryFab(): boolean {
    return this.home.hasAnyEntry && !this.readOnly && !this.home.batchMode
  }

  @Computed
  get readonlyBody(): ResourceStr {
    return this.app.isKdbx31()
      ? $r('app.string.vault_readonly_kdbx31')
      : $r('app.string.vault_readonly_permission')
  }

  @Computed
  get batchArchiveLabel(): ResourceStr {
    return this.home.isArchivedMode
      ? $r('app.string.entry_batch_restore')
      : $r('app.string.entry_batch_archive')
  }

  private openTemplatePicker(groupUuid: string): void {
    this.pickedGroupUuid = groupUuid
    this.pickedTemplate = undefined
    this.templatePickerVisible = true
  }

  // 选择器完全收起后才打开编辑半模态，顺序固定，不并发两个半模态。
  private onTemplatePickerDisappeared(): void {
    const template: ItemTemplate | undefined = this.pickedTemplate
    if (template === undefined) {
      return
    }
    const groupUuid: string = this.pickedGroupUuid
    this.pickedTemplate = undefined
    this.pickedGroupUuid = ''
    entrySheetViewModel.openNew(template, groupUuid)
  }

  private onRowTap(row: EntryRowModel): void {
    if (this.home.batchMode) {
      this.home.toggleSelection(row.uuid)
      return
    }
    entrySheetViewModel.openPreview(row.uuid)
  }

  // 菜单含预览图时在子窗显示，层级高于主窗弹窗与半模态；菜单项动作须等菜单彻底消失再执行，否则会被预览图盖住。
  private onRowMenuClosed(): void {
    const action: (() => void) | undefined = this.pendingMenuAction
    if (action === undefined) {
      return
    }
    this.pendingMenuAction = undefined
    action()
  }

  private openDeleteDialog(row: EntryRowModel | undefined): void {
    this.pendingDeleteRow = row
    this.deleteDialogBatch = row === undefined
    this.deleteBusy = false
    this.getUIContext()
      .getPromptAction()
      .presentCustomDialog(() => this.deleteDialog(), this.deleteDialogController, {
        backgroundColor: Color.Transparent,
        backgroundBlurStyle: BlurStyle.NONE,
        cornerRadius: 0,
        width: $r('app.float.dialog_width'),
        alignment: DialogAlignment.Center,
        maskColor: $r('app.color.ds_scrim'),
      })
      .catch((error: BusinessError) => {
        LogUtil.error(`打开删除确认弹窗失败，错误码=${error.code}，错误信息=${error.message}`)
      })
  }

  private runDelete(): void {
    const row: EntryRowModel | undefined = this.pendingDeleteRow
    if (row === undefined) {
      return
    }
    this.deleteBusy = true
    this.app.deleteEntry(row.uuid).then((deleted: boolean) => {
      this.deleteBusy = false
      this.deleteDialogController.close()
      if (deleted) {
        this.app.refreshHomeSnapshot()
        DsToastHost.show(this.getUIContext(), $r('app.string.entry_moved_to_recycle_bin'))
      }
    })
  }

  private runBatchDelete(): void {
    const uuids: string[] = this.home.selectedUuids
    this.deleteBusy = true
    this.app.deleteEntries(uuids).then((deleted: boolean) => {
      this.deleteBusy = false
      this.deleteDialogController.close()
      if (deleted) {
        this.app.refreshHomeSnapshot()
        DsToastHost.show(this.getUIContext(), $r('app.string.entry_moved_to_recycle_bin'))
      }
      this.animateExitBatch()
    })
  }

  // 标题栏高度由 HDS 安全区驱动，必须在显式动画闭包里退出，否则筛选区与列表整段跳变。
  private animateExitBatch(): void {
    animateBatchTransition(this.getUIContext(), () => this.home.exitBatch())
  }

  @Builder
  private deleteDialog() {
    DsDialog({
      title: this.deleteDialogBatch
        ? $r('app.string.entry_batch_delete_title')
        : $r('app.string.delete_entry_title'),
      message: this.deleteDialogBatch
        ? $r('app.string.entry_batch_delete_message')
        : $r('app.string.delete_entry_message'),
      icon: $r('app.string.symbol_delete'),
      tone: DsDialogTone.Error,
      cancelLabel: $r('app.string.cancel'),
      confirmLabel: this.deleteDialogBatch
        ? $r('app.string.entry_batch_delete')
        : $r('app.string.delete_entry'),
      busy: this.deleteBusy,
      onCancel: () => this.deleteDialogController.close(),
      onConfirm: () => {
        if (this.deleteDialogBatch) {
          this.runBatchDelete()
        } else {
          this.runDelete()
        }
      },
    })
  }

  private archiveSelection(): void {
    const archived: boolean = !this.home.isArchivedMode
    const uuids: string[] = this.home.selectedUuids
    this.app.setArchivedMany(uuids, archived).then((applied: boolean) => {
      if (applied) {
        this.app.refreshHomeSnapshot()
        DsToastHost.show(this.getUIContext(),
          archived ? $r('app.string.entry_archived') : $r('app.string.entry_restored'))
      }
      this.animateExitBatch()
    })
  }

  // 归档状态由 ViewModel 翻转，成功提示需按调用前的状态判断方向。
  private toggleArchive(row: EntryRowModel): void {
    const archiving: boolean = !row.archived
    this.app.toggleArchived(row.uuid).then((applied: boolean) => {
      if (applied) {
        DsToastHost.show(this.getUIContext(),
          archiving ? $r('app.string.entry_archived') : $r('app.string.entry_restored'))
      }
    })
  }

  private copyField(row: EntryRowModel, fieldName: string): void {
    const value: string = row.fieldValue(fieldName)
    if (value.length === 0) {
      return
    }
    this.app.copyValue(value).then((copied: boolean) => {
      if (copied) {
        DsToastHost.show(this.getUIContext(), $r('app.string.copy_completed'))
      }
    })
  }

  @Builder
  private readonlyNotice() {
    Row() {
      DsNotice({
        tone: DsNoticeTone.Default,
        title: $r('app.string.vault_readonly_title'),
        body: this.readonlyBody,
      })
    }
    .width('100%')
    .padding({
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
      bottom: $r('app.float.ds_space_sm'),
    })
  }

  // Repeat 与 @Builder 混用时必须整体传 RepeatItem：只传 item.item 时复用节点不会刷新。
  @Builder
  private groupHeader(item: RepeatItem<EntryListItem>) {
    Row({ space: $r('app.float.ds_space_sm') }) {
      Text(item.item.header!.groupName)
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontWeight(600)
        .letterSpacing($r('app.float.ds_tracking_wide_2xl'))
        .fontColor($r('app.color.ds_text_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(String(item.item.header!.count))
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontFamily(PASSWORD_FONT_FAMILY)
        .fontColor($r('app.color.ds_text_tertiary'))

      Blank()

      if (!this.readOnly && !this.home.batchMode) {
        DsButton({
          variant: DsButtonVariant.Text,
          buttonSize: DsControlSize.Small,
          iconOnly: true,
          leadingIcon: $r('app.string.symbol_add'),
          iconSizeOverride: $r('app.float.ds_icon_sm'),
          iconColorOverride: $r('app.color.ds_text_secondary'),
          accessibilityLabelResource: $r('app.string.new_entry'),
          onTap: () => this.openTemplatePicker(item.item.header!.groupUuid),
        })
      }
    }
    .width('100%')
    .height(item.item.header!.leaving ? 0 : $r('app.float.ds_tab_height_sm'))
    .opacity(item.item.header!.leaving ? 0 : 1)
    .clip(true)
    .padding({ left: $r('app.float.ds_gutter'), right: $r('app.float.ds_gutter') })
    .alignItems(VerticalAlign.Center)
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.EASE_EXIT,
    })
  }

  // swipeAction 内容随列表项缓存、延迟执行，行模型必须在此刻取值，复用后回读 RepeatItem 会拿到分组头。
  private swipeEnd(item: RepeatItem<EntryListItem>): (() => void) | undefined {
    const row: EntryRowModel | undefined = item.item.row
    if (row === undefined || this.removalLeavingKeys.has(item.item.key) || this.readOnly || this.home.batchMode) {
      return undefined
    }
    return (): void => this.swipeActions(row)
  }

  @Builder
  private swipeActions(row: EntryRowModel) {
    Row() {
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        SymbolGlyph($r('app.string.symbol_edit'))
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([$r('app.color.ds_on_primary')])
          .foregroundColor($r('app.color.ds_on_primary'))
      }
      .width($r('app.float.ds_swipe_action_width'))
      .height('100%')
      .borderRadius($r('app.float.ds_radius_none'))
      .backgroundColor($r('app.color.ds_primary'))
      .onClick(() => entrySheetViewModel.openEdit(row.uuid))

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        SymbolGlyph(row.archived ? $r('app.string.symbol_unarchive') : $r('app.string.symbol_archive'))
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([$r('app.color.ds_text_primary')])
          .foregroundColor($r('app.color.ds_text_primary'))
      }
      .width($r('app.float.ds_swipe_action_width'))
      .height('100%')
      .borderRadius($r('app.float.ds_radius_none'))
      .backgroundColor($r('app.color.ds_surface_high'))
      .onClick(() => {
        this.toggleArchive(row)
      })

      Button({ type: ButtonType.Normal, stateEffect: true }) {
        SymbolGlyph($r('app.string.symbol_delete'))
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([$r('app.color.ds_on_primary')])
          .foregroundColor($r('app.color.ds_on_primary'))
      }
      .width($r('app.float.ds_swipe_action_width'))
      .height('100%')
      .borderRadius($r('app.float.ds_radius_none'))
      .backgroundColor($r('app.color.ds_error'))
      .onClick(() => this.openDeleteDialog(row))
    }
    .height('100%')
  }

  @Builder
  private menuTemplateTag(row: EntryRowModel) {
    Row({ space: $r('app.float.ds_space_xs') }) {
      SymbolGlyph($r('app.string.symbol_description'))
        .fontSize($r('app.float.ds_icon_tiny'))
        .fontColor([$r('app.color.ds_text_secondary')])
        .foregroundColor($r('app.color.ds_text_secondary'))

      Text(row.menuTemplateLabel())
        .fontSize($r('app.float.ds_font_label_md'))
        .fontWeight(600)
        .letterSpacing($r('app.float.ds_tracking_wide_md'))
        .fontColor($r('app.color.ds_text_primary'))
        .maxLines(1)
    }
    .height($r('app.float.ds_context_menu_tag_height'))
    .padding({ left: $r('app.float.ds_space_xs'), right: $r('app.float.ds_space_sm') })
    .backgroundColor($r('app.color.ds_surface_high'))
    .alignItems(VerticalAlign.Center)
  }

  @LocalBuilder
  private menuHeader(row: EntryRowModel) {
    Column({ space: $r('app.float.ds_space_6') }) {
      Row() {
        Row({ space: $r('app.float.ds_space_xs') }) {
          SymbolGlyph($r('app.string.symbol_folder'))
            .fontSize($r('app.float.ds_icon_xs'))
            .fontColor([$r('app.color.ds_text_secondary')])
            .foregroundColor($r('app.color.ds_text_secondary'))

          Text(row.menuGroupName)
            .fontSize($r('app.float.ds_font_label_md'))
            .fontWeight(600)
            .fontColor($r('app.color.ds_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .height($r('app.float.ds_context_menu_tag_height'))
        .alignItems(VerticalAlign.Center)

        this.menuTemplateTag(row)
      }
      .width('100%')
      .height($r('app.float.ds_context_menu_tag_height'))
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      if (row.menuSubtitle().length > 0) {
        Text(row.menuSubtitle())
          .width('100%')
          .fontSize($r('app.float.ds_font_label_sm'))
          .fontColor($r('app.color.ds_text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
    }
    .width('100%')
    .height($r('app.float.ds_context_menu_header_height'))
    .padding({
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
      top: $r('app.float.ds_space_md'),
      bottom: $r('app.float.ds_space_md'),
    })
    .backgroundColor($r('app.color.ds_surface_low'))
    .alignItems(HorizontalAlign.Start)
  }

  @LocalBuilder
  private copyGroup(row: EntryRowModel) {
    DsMenuItem({
      icon: $r('app.string.symbol_person'),
      label: $r('app.string.entry_menu_copy_username'),
      onAction: () => this.copyField(row, ENTRY_FIELD_USERNAME),
    })
    DsMenuItem({
      icon: $r('app.string.symbol_key'),
      label: $r('app.string.entry_menu_copy_password'),
      onAction: () => this.copyField(row, ENTRY_FIELD_PASSWORD),
    })
  }

  @LocalBuilder
  private manageGroup(row: EntryRowModel) {
    DsMenuItem({
      icon: $r('app.string.symbol_edit'),
      label: $r('app.string.entry_menu_edit'),
      onAction: () => {
        this.pendingMenuAction = () => entrySheetViewModel.openEdit(row.uuid)
      },
    })
    DsMenuItem({
      icon: row.archived ? $r('app.string.symbol_unarchive') : $r('app.string.symbol_archive'),
      label: row.archived ? $r('app.string.entry_menu_restore') : $r('app.string.entry_menu_archive'),
      onAction: () => this.toggleArchive(row),
    })
    DsMenuItem({
      icon: $r('app.string.symbol_check_box'),
      label: $r('app.string.entry_menu_select'),
      onAction: () => {
        this.pendingMenuAction = () => animateBatchTransition(this.getUIContext(), () => {
          this.home.enterBatch(row.uuid)
        })
      },
    })
  }

  @LocalBuilder
  private deleteGroup(row: EntryRowModel) {
    DsMenuItem({
      icon: $r('app.string.symbol_delete'),
      label: $r('app.string.entry_menu_delete'),
      theme: DsMenuItemTheme.Error,
      onAction: () => {
        this.pendingMenuAction = () => this.openDeleteDialog(row)
      },
    })
  }

  @LocalBuilder
  private menuContent(row: EntryRowModel) {
    DsMenuGroup({
      dividerTop: false,
      content: () => {
        this.copyGroup(row)
      },
    })
    if (!this.readOnly) {
      DsMenuGroup({
        dividerTop: true,
        content: () => {
          this.manageGroup(row)
        },
      })
      DsMenuGroup({
        dividerTop: true,
        content: () => {
          this.deleteGroup(row)
        },
      })
    }
  }

  @Builder
  private rowMenu(row: EntryRowModel) {
    Column() {
      DsContextMenu({
        header: () => {
          this.menuHeader(row)
        },
        content: () => {
          this.menuContent(row)
        },
      })
    }
    .margin({
      left: -this.contextMenuSystemInset,
      right: -this.contextMenuSystemInset,
      top: -this.contextMenuSystemInset,
      bottom: -this.contextMenuSystemInset,
    })
  }

  // 同 groupHeader：整体传 RepeatItem，节点复用时行内容才会跟着换。
  @Builder
  private entryRow(item: RepeatItem<EntryListItem>) {
    VaultEntryRow({
      row: item.item.row!,
      favoriteEnabled: !this.readOnly,
      onRowClick: () => this.onRowTap(item.item.row!),
      onFavoriteToggle: (_next: boolean) => this.list.toggleFavorite(item.item.row!.uuid),
    })
      .bindContextMenu(this.rowMenu(item.item.row!), ResponseType.LongPress, {
        preview: MenuPreviewMode.IMAGE,
        previewBorderRadius: $r('app.float.ds_radius_none'),
        borderRadius: $r('app.float.ds_radius_none'),
        backgroundColor: $r('app.color.ds_surface_lowest'),
        backgroundBlurStyle: BlurStyle.NONE,
        placement: Placement.BottomRight,
        targetSpace: LengthMetrics.vp(4),
        hapticFeedbackMode: HapticFeedbackMode.ENABLED,
        onDisappear: () => this.onRowMenuClosed(),
        mask: {
          color: $r('app.color.ds_scrim'),
          backgroundBlurStyle: BlurStyle.NONE,
        },
      })
  }

  // 视口外的离场行只占零高度：收缩会让列表不断把后续行拉进视口，整表逐行构建代价过高。
  @Builder
  private listItemBody(item: RepeatItem<EntryListItem>) {
    if (this.removalLeavingKeys.has(item.item.key) && !this.removalVisibleKeys.has(item.item.key)) {
      Row()
        .width('100%')
        .height(0)
    } else if (item.item.kind === EntryListItemKind.Header) {
      this.groupHeader(item)
    } else {
      this.entryRow(item)
    }
  }

  @Builder
  private listFooter() {
    ListItem() {
      Column()
        .width('100%')
        .height(this.contentBottomAvoid)
    }
  }

  @Builder
  private entryList() {
    List({ scroller: this.scroller }) {
      Repeat<EntryListItem>(this.list.items)
        .each((item: RepeatItem<EntryListItem>) => {
          ListItem() {
            this.listItemBody(item)
          }
          .swipeAction({
            end: this.swipeEnd(item),
            edgeEffect: SwipeEdgeEffect.None,
          })
          .transition(this.stateSwitchTransition)
        })
        .key((item: EntryListItem) => item.key)
        .virtualScroll({
          memoryOptimizationStrategy: RepeatMemOptStrategy.ENABLE_AUTO_CACHE_OPTIMIZATION,
        })

      this.listFooter()
    }
    .width('100%')
    .layoutWeight(1)
    .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true, effectEdge: EffectEdge.START | EffectEdge.END })
    .cachedCount(6)
    .clip(false)
    .onTouch(() => this.app.recordActivity())
    .onScrollFrameBegin((offset: number, _state: ScrollState) => {
      this.home.updateChromeVisibility(offset)
      return { offsetRemain: offset }
    })
    .onScrollIndex((start: number, end: number) => {
      this.visibleStart = start
      this.visibleEnd = end
    })
    .onReachStart(() => this.home.showChrome())
    .transition(this.stateSwitchTransition)
  }

  @Builder
  private templateShortcut(template: ItemTemplate, title: Resource, description: Resource, icon: Resource) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: $r('app.float.ds_space_6') }) {
        SymbolGlyph(icon)
          .fontSize($r('app.float.ds_icon_md'))
          .fontColor([$r('app.color.ds_text_primary')])
          .foregroundColor($r('app.color.ds_text_primary'))
        Text(title)
          .width('100%')
          .fontSize($r('app.float.ds_font_label_md'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(description)
          .width('100%')
          .fontSize($r('app.float.ds_font_micro'))
          .lineHeight($r('app.float.ds_line_height_micro'))
          .fontColor($r('app.color.ds_text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .height($r('app.float.ds_template_shortcut_height'))
    .padding($r('app.float.ds_space_md'))
    .borderRadius($r('app.float.ds_radius_none'))
    .backgroundColor($r('app.color.ds_surface_low'))
    .onClick(() => entrySheetViewModel.openNew(template))
  }

  @Builder
  private emptyVault() {
    Column({ space: $r('app.float.ds_space_24') }) {
      Image($r('app.media.ds_empty_entry'))
        .width($r('app.float.ds_empty_illustration_width'))
        .aspectRatio(428 / 434)
        .objectFit(ImageFit.Contain)

      Text($r('app.string.entry_empty_title'))
        .fontSize($r('app.float.ds_font_headline_md'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))

      Text($r('app.string.entry_empty_body'))
        .width($r('app.float.ds_empty_body_width'))
        .textAlign(TextAlign.Center)
        .fontSize($r('app.float.ds_font_body_sm'))
        .lineHeight($r('app.float.ds_line_height_body_sm'))
        .fontColor($r('app.color.ds_text_secondary'))

      if (!this.readOnly) {
        Row({ space: $r('app.float.ds_space_sm') }) {
          this.templateShortcut(ItemTemplate.Login, $r('app.string.login_template'),
            $r('app.string.login_template_description'), $r('app.string.symbol_key'))
          this.templateShortcut(ItemTemplate.Password, $r('app.string.password_template'),
            $r('app.string.password_template_description'), $r('app.string.symbol_key'))
          this.templateShortcut(ItemTemplate.SecureNote, $r('app.string.secure_note_template'),
            $r('app.string.secure_note_template_description'), $r('app.string.symbol_notes'))
        }
        .width('100%')

        DsButton({
          label: $r('app.string.new_entry'),
          variant: DsButtonVariant.Filled,
          buttonSize: DsControlSize.Medium,
          onTap: () => this.openTemplatePicker(''),
        })
      }
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({
      top: $r('app.float.ds_space_16'),
      bottom: $r('app.float.ds_space_16'),
      left: $r('app.float.ds_space_24'),
      right: $r('app.float.ds_space_24'),
    })
    .transition(this.stateSwitchTransition)
  }

  @Computed
  get emptyTitle(): ResourceStr {
    if (this.home.searchQuery.length > 0) {
      return $r('app.string.entry_search_no_result_title')
    }
    if (this.home.isFavoritesMode) {
      return $r('app.string.entry_favorites_empty_title')
    }
    if (this.home.isArchivedMode) {
      return $r('app.string.entry_archived_empty_title')
    }
    return $r('app.string.entry_search_no_result_title')
  }

  @Builder
  private emptyFiltered() {
    Column({ space: $r('app.float.ds_space_16') }) {
      Image(this.home.searchQuery.length > 0
        ? $r('app.media.ds_empty_entry_search') : $r('app.media.ds_empty_entry'))
        .width($r('app.float.ds_empty_illustration_width'))
        .aspectRatio(this.home.searchQuery.length > 0 ? 474 / 454 : 428 / 434)
        .objectFit(ImageFit.Contain)

      Text(this.emptyTitle)
        .fontSize($r('app.float.ds_font_headline_md'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))

      if (this.home.searchQuery.length > 0 || this.home.isAllMode) {
        Text($r('app.string.entry_search_no_result_body'))
          .fontSize($r('app.float.ds_font_body_sm'))
          .fontColor($r('app.color.ds_text_secondary'))
      }

      DsButton({
        label: this.home.searchQuery.length > 0 || !this.home.isAllMode
          ? $r('app.string.entry_clear_filter') : $r('app.string.entry_view_all'),
        variant: DsButtonVariant.Filled,
        tone: DsButtonTone.Default,
        buttonSize: DsControlSize.Medium,
        onTap: () => this.home.clearFilters(),
      })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({
      top: $r('app.float.ds_space_16'),
      bottom: $r('app.float.ds_space_16'),
      left: $r('app.float.ds_space_24'),
      right: $r('app.float.ds_space_24'),
    })
    .transition(this.stateSwitchTransition)
  }

  @LocalBuilder
  private batchActions() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      Row() {
        DsButton({
          label: this.batchArchiveLabel,
          variant: DsButtonVariant.Filled,
          tone: DsButtonTone.Default,
          buttonSize: DsControlSize.Medium,
          fullWidth: true,
          onTap: () => this.archiveSelection(),
        })
      }
      .layoutWeight(1)

      Row() {
        DsButton({
          label: $r('app.string.entry_batch_delete'),
          variant: DsButtonVariant.Filled,
          tone: DsButtonTone.Default,
          buttonSize: DsControlSize.Medium,
          fullWidth: true,
          backgroundColorOverride: $r('app.color.ds_error_container'),
          contentColorOverride: $r('app.color.ds_on_error_container'),
          onTap: () => this.openDeleteDialog(undefined),
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }

  // 智感握姿换侧：左右两个按钮条件渲染，各自沿所在侧滑出/滑入，由框架同步两段过渡。
  @Builder
  private newEntryFab(edge: TransitionEdge) {
    Stack() {
      DsButton({
        variant: DsButtonVariant.Filled,
        tone: DsButtonTone.Primary,
        buttonSize: DsControlSize.Large,
        iconOnly: true,
        leadingIcon: $r('app.string.symbol_add'),
        controlHeightOverride: $r('app.float.ds_cta_height'),
        iconSizeOverride: $r('app.float.ds_icon_md'),
        accessibilityLabelResource: $r('app.string.new_entry'),
        onTap: () => this.openTemplatePicker(''),
      })
    }
    .width($r('app.float.ds_cta_height'))
    .height($r('app.float.ds_cta_height'))
    .margin({
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
      bottom: this.bottomAvoidHeight,
    })
    .onAppear(() => {
      this.fabHasAppeared = true
    })
    .transition(TransitionEffect.move(edge)
      .combine(TransitionEffect.OPACITY)
      .animation({
        curve: this.fabHasAppeared
          ? AnimationTokens.FAB_SIDE_MOVE_CURVE
          : AnimationTokens.FAB_FIRST_APPEAR_CURVE,
      }))
  }

  @Builder
  private templatePickerSheet() {
    EntryTemplatePicker({
      bottomOffset: this.bottomAvoidHeight,
      onPicked: (template: ItemTemplate) => {
        this.pickedTemplate = template
        this.templatePickerVisible = false
      },
      onClose: () => this.templatePickerVisible = false,
    })
  }

  // 须在组件上下文内调用契约供给的 WrappedBuilder：直接传全局 @Builder 引用会丢失渲染上下文。
  @Builder
  private vaultTitleRow() {
    vaultTabChrome.titleRowBuilder!.builder()
  }

  @Builder
  private vaultBottomRow() {
    vaultTabChrome.bottomRowBuilder!.builder()
  }

  @Computed
  get titleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        originalStyle: {
          backgroundStyle: {
            maskExtraHeight: VAULT_TITLE_BAR_MASK_EXTRA_HEIGHT_VP,
          },
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      content: {
        title: { mainTitle: '' },
        stackBuilder: (): void => this.vaultTitleRow(),
        bottomBuilder: this.session.vaultLocked
          ? undefined
          : {
            builder: (): void => this.vaultBottomRow(),
            height: this.home.batchMode ? 0 : VAULT_FILTER_BAR_HEIGHT_VP,
          },
      },
    }
  }

  // HdsNavigation 须与滚动 List 同组件，dynamicHideTitleBar 才能接管连续滑动。
  build() {
    HdsNavigation() {
      Stack({ alignContent: this.list.fabRight ? Alignment.BottomEnd : Alignment.BottomStart }) {
        Column() {
          if (this.app.hasRecentVault()) {
            if (!this.home.batchMode && this.readOnly) {
              this.readonlyNotice()
            }

            Column() {
              if (this.list.items.length > 0) {
                this.entryList()
              } else if (this.home.hasAnyEntry) {
                this.emptyFiltered()
              } else {
                this.emptyVault()
              }
            }
            .width('100%')
            .layoutWeight(1)
          }
        }
        .width('100%')
        .height('100%')

        if (this.home.batchMode) {
          DsBottomActionBar({
            includeSafeArea: true,
            onHeightChange: (height: number) => {
              this.batchBarHeight = height
            },
            contentBuilder: this.batchActions,
          })
        } else if (this.showNewEntryFab && !this.home.chromeHidden) {
          if (this.list.fabRight) {
            this.newEntryFab(TransitionEdge.END)
          } else {
            this.newEntryFab(TransitionEdge.START)
          }
        }

        if (this.app.hasRecentVault()) {
          Stack()
            .width(0)
            .height(0)
            .bindSheet($$this.templatePickerVisible, this.templatePickerSheet(), dsSheetOptions({
              onDisappear: () => this.onTemplatePickerDisappeared(),
            }))

          EntrySheet({ sheet: entrySheetViewModel })
        }
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .hideBackButton(true)
    .titleBar(this.titleBarOptions)
    .bindToScrollable([this.scroller])
    .titleMode(HdsNavigationTitleMode.MINI)
    .dynamicHideTitleBar({
      hideTitleArea: false,
      hideBottomBuilder: true,
      hideStatusBar: false,
      mode: HideMode.SCROLL_UP,
    })
    .mode(NavigationMode.Stack)
    .backgroundColor($r('app.color.ds_surface_canvas'))
  }
}
