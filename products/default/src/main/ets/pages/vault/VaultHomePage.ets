import { AnimationTokens, AppToast, ItemTemplate } from '@ohos/common'
import {
  hdsMaterial,
  HideMode,
  HdsNavigation,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { ResUtil } from '@pura/harmony-utils'
import { DsBottomActionBar } from '../../components/DsBottomActionBar'
import { DsButton, DsButtonSize, DsButtonTone, DsButtonVariant } from '../../components/DsButton'
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
import { VaultHomeViewModel, vaultHomeViewModel } from '../../viewmodel/VaultHomeViewModel'
import { entrySheetViewModel } from '../../viewmodel/EntrySheetViewModel'
import { EntrySheet } from './EntrySheet'
import { EntryTemplatePicker } from './EntryTemplatePicker'
import { VaultEntryRow } from './VaultEntryRow'
import { vaultTabChrome } from './VaultTabChrome'

@ComponentV2
export struct VaultHomePage {
  private readonly scroller: Scroller = new Scroller()
  @Local private session: AppSessionState = appSessionState
  @Local private home: VaultHomeViewModel = vaultHomeViewModel
  @Local private list: HomeEntryListViewModel = homeEntryListViewModel
  @Local private app: AppViewModel = appViewModel
  @Local private templatePickerVisible: boolean = false
  @Local private batchBarHeight: number = 0
  private pickedTemplate: ItemTemplate | undefined = undefined
  private pickedGroupUuid: string = ''
  private readonly stateSwitchTransition: TransitionEffect = TransitionEffect.OPACITY
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })
  private readonly itemTransition: TransitionEffect = TransitionEffect.asymmetric(
    TransitionEffect.OPACITY
      .animation({
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
      }),
    TransitionEffect.OPACITY
      .animation({
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
      }),
  )

  aboutToAppear(): void {
    this.list.subscribeHoldingHand()
    this.list.refresh()
  }

  aboutToDisappear(): void {
    this.list.unsubscribeHoldingHand()
  }

  @Monitor('home.entries')
  onEntriesChanged(): void {
    this.list.refresh()
  }

  @Monitor('app.status')
  onStatusChanged(): void {
    if (this.app.status.length > 0) {
      AppToast.show(this.getUIContext(), this.app.status)
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
      this.toggleSelection(row.uuid)
      return
    }
    entrySheetViewModel.openPreview(row.uuid)
  }

  private toggleSelection(uuid: string): void {
    this.home.toggleSelection(uuid)
  }

  private enterBatch(uuid: string): void {
    this.home.enterBatch(uuid)
  }

  private exitBatch(): void {
    this.home.exitBatch()
  }

  private clearFilters(): void {
    this.home.clearFilters()
  }

  private confirmDelete(row: EntryRowModel): void {
    const options: AlertDialogParamWithButtons = {
      title: $r('app.string.delete_entry_title'),
      message: $r('app.string.delete_entry_message'),
      primaryButton: {
        value: $r('app.string.cancel'),
        action: () => {
        },
      },
      secondaryButton: {
        value: $r('app.string.delete_entry'),
        fontColor: $r('app.color.ds_warning'),
        action: () => {
          this.app.deleteEntry(row.uuid).then((deleted: boolean) => {
            if (deleted) {
              this.app.refreshHomeSnapshot()
              AppToast.show(this.getUIContext(), $r('app.string.entry_moved_to_recycle_bin'))
            }
          })
        },
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  private confirmBatchDelete(): void {
    const options: AlertDialogParamWithButtons = {
      title: $r('app.string.entry_batch_delete_title'),
      message: $r('app.string.entry_batch_delete_message'),
      primaryButton: {
        value: $r('app.string.cancel'),
        action: () => {
        },
      },
      secondaryButton: {
        value: $r('app.string.entry_batch_delete'),
        fontColor: $r('app.color.ds_warning'),
        action: () => {
          const uuids: string[] = this.home.selectedUuids
          this.app.deleteEntries(uuids).then((deleted: boolean) => {
            if (deleted) {
              this.app.refreshHomeSnapshot()
            }
            this.exitBatch()
          })
        },
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  private archiveSelection(): void {
    const archived: boolean = !this.home.isArchivedMode
    const uuids: string[] = this.home.selectedUuids
    this.app.setArchivedMany(uuids, archived).then((applied: boolean) => {
      if (applied) {
        this.app.refreshHomeSnapshot()
      }
      this.exitBatch()
    })
  }

  private copyField(row: EntryRowModel, fieldName: string): void {
    const value: string = row.fieldValue(fieldName)
    if (value.length === 0) {
      return
    }
    this.app.copyValue(value).then((copied: boolean) => {
      if (copied) {
        AppToast.show(this.getUIContext(), $r('app.string.copy_completed'))
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

  @Builder
  private groupHeader(header: EntryGroupHeaderModel) {
    Row({ space: $r('app.float.ds_space_sm') }) {
      Text(header.groupName)
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontWeight(600)
        .letterSpacing($r('app.float.ds_tracking_wide_2xl'))
        .fontColor($r('app.color.ds_text_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(String(header.count))
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontFamily(PASSWORD_FONT_FAMILY)
        .fontColor($r('app.color.ds_text_tertiary'))

      Blank()

      if (!this.readOnly && !this.home.batchMode) {
        DsButton({
          variant: DsButtonVariant.Text,
          buttonSize: DsButtonSize.Small,
          iconOnly: true,
          leadingIcon: $r('app.string.symbol_add'),
          iconSizeOverride: $r('app.float.ds_icon_sm'),
          iconColorOverride: $r('app.color.ds_text_secondary'),
          accessibilityLabelResource: $r('app.string.new_entry'),
          onTap: () => this.openTemplatePicker(header.groupUuid),
        })
      }
    }
    .width('100%')
    .height($r('app.float.ds_tab_height_sm'))
    .padding({ left: $r('app.float.ds_gutter'), right: $r('app.float.ds_gutter') })
    .alignItems(VerticalAlign.Center)
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
        SymbolGlyph($r('app.string.symbol_delete'))
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([$r('app.color.ds_on_primary')])
          .foregroundColor($r('app.color.ds_on_primary'))
      }
      .width($r('app.float.ds_swipe_action_width'))
      .height('100%')
      .borderRadius($r('app.float.ds_radius_none'))
      .backgroundColor($r('app.color.ds_error'))
      .onClick(() => this.confirmDelete(row))
    }
    .height('100%')
  }

  @Builder
  private rowMenu(row: EntryRowModel) {
    Menu() {
      MenuItem({ content: $r('app.string.entry_menu_copy_username') })
        .onClick(() => this.copyField(row, ENTRY_FIELD_USERNAME))
      MenuItem({ content: $r('app.string.entry_menu_copy_password') })
        .onClick(() => this.copyField(row, ENTRY_FIELD_PASSWORD))
      if (!this.readOnly) {
        MenuItem({ content: $r('app.string.entry_menu_edit') })
          .onClick(() => entrySheetViewModel.openEdit(row.uuid))
        MenuItem({
          content: row.archived
            ? $r('app.string.entry_menu_restore') : $r('app.string.entry_menu_archive'),
        })
          .onClick(() => {
            this.app.toggleArchived(row.uuid).then(() => this.app.refreshHomeSnapshot())
          })
        MenuItem({ content: $r('app.string.entry_menu_select') })
          .onClick(() => this.enterBatch(row.uuid))
        MenuItem({ content: $r('app.string.entry_menu_delete') })
          .onClick(() => this.confirmDelete(row))
      }
    }
  }

  @Builder
  private entryRow(row: EntryRowModel) {
    VaultEntryRow({
      row: row,
      favoriteEnabled: !this.readOnly && !this.home.batchMode,
      onRowClick: () => this.onRowTap(row),
      onFavoriteToggle: (_next: boolean) => this.list.toggleFavorite(row.uuid),
    })
      .bindContextMenu(this.rowMenu(row), ResponseType.LongPress, { preview: MenuPreviewMode.NONE })
  }

  @Builder
  private entryList() {
    List({ scroller: this.scroller }) {
      Repeat<EntryListItem>(this.list.items)
        .each((item: RepeatItem<EntryListItem>) => {
          ListItem() {
            if (item.item.kind === EntryListItemKind.Header) {
              this.groupHeader(item.item.header!)
            } else {
              this.entryRow(item.item.row!)
            }
          }
          .swipeAction({
            end: item.item.kind === EntryListItemKind.Row && !this.readOnly && !this.home.batchMode
              ? () => this.swipeActions(item.item.row!)
              : undefined,
            edgeEffect: SwipeEdgeEffect.None,
          })
          .transition(this.itemTransition)
        })
        .key((item: EntryListItem) => item.key)
        .virtualScroll({
          memoryOptimizationStrategy: RepeatMemOptStrategy.ENABLE_AUTO_CACHE_OPTIMIZATION,
        })

      ListItem() {
        Column()
          .width('100%')
          .height(this.contentBottomAvoid)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true, effectEdge: EffectEdge.START | EffectEdge.END })
    .cachedCount(6)
    .clip(false)
    .onTouch(() => this.app.recordActivity())
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
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph($r('app.string.symbol_key'))
          .fontSize($r('app.float.ds_icon_lg'))
          .fontColor([$r('app.color.ds_text_secondary')])
          .foregroundColor($r('app.color.ds_text_secondary'))
      }
      .width($r('app.float.ds_empty_icon_size'))
      .height($r('app.float.ds_empty_icon_size'))
      .backgroundColor($r('app.color.ds_surface_high'))

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
          buttonSize: DsButtonSize.Medium,
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
      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph($r('app.string.symbol_search'))
          .fontSize($r('app.float.ds_icon_lg'))
          .fontColor([$r('app.color.ds_text_secondary')])
          .foregroundColor($r('app.color.ds_text_secondary'))
      }
      .width($r('app.float.ds_empty_icon_size'))
      .height($r('app.float.ds_empty_icon_size'))
      .backgroundColor($r('app.color.ds_surface_high'))

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
        buttonSize: DsButtonSize.Medium,
        onTap: () => this.clearFilters(),
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
          buttonSize: DsButtonSize.Medium,
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
          buttonSize: DsButtonSize.Medium,
          fullWidth: true,
          backgroundColorOverride: $r('app.color.ds_error_container'),
          contentColorOverride: $r('app.color.ds_on_error_container'),
          onTap: () => this.confirmBatchDelete(),
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  private newEntryFab() {
    Row() {
      DsButton({
        variant: DsButtonVariant.Filled,
        tone: DsButtonTone.Primary,
        buttonSize: DsButtonSize.Large,
        iconOnly: true,
        leadingIcon: $r('app.string.symbol_add'),
        controlHeightOverride: $r('app.float.ds_cta_height'),
        iconSizeOverride: $r('app.float.ds_icon_md'),
        accessibilityLabelResource: $r('app.string.new_entry'),
        onTap: () => this.openTemplatePicker(''),
      })
    }
    .width('100%')
    .justifyContent(this.list.fabRight ? FlexAlign.End : FlexAlign.Start)
    .padding({ left: $r('app.float.ds_gutter'), right: $r('app.float.ds_gutter') })
    .margin({ bottom: this.bottomAvoidHeight })
    .transition(TransitionEffect.OPACITY.animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
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
  private vaultSelectionRow() {
    vaultTabChrome.selectionRowBuilder!.builder()
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
        stackBuilder: this.home.batchMode
          ? (): void => this.vaultSelectionRow()
          : (): void => this.vaultTitleRow(),
        bottomBuilder: this.session.vaultLocked || this.home.batchMode
          ? undefined
          : {
            builder: (): void => this.vaultBottomRow(),
            height: VAULT_FILTER_BAR_HEIGHT_VP,
          },
      },
    }
  }

  // HdsNavigation 须与滚动 List 同组件，dynamicHideTitleBar 才能接管连续滑动。
  build() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column() {
          if (this.app.hasRecentVault()) {
            if (!this.home.batchMode && this.readOnly) {
              this.readonlyNotice()
            }

            if (this.list.items.length > 0) {
              this.entryList()
            } else if (this.home.hasAnyEntry) {
              this.emptyFiltered()
            } else {
              this.emptyVault()
            }
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
        } else if (this.showNewEntryFab) {
          this.newEntryFab()
        }

        if (this.app.hasRecentVault()) {
          Stack()
            .width(0)
            .height(0)
            .bindSheet($$this.templatePickerVisible, this.templatePickerSheet(), {
              dragBar: true,
              showClose: false,
              backgroundColor: $r('app.color.ds_surface_lowest'),
              onDisappear: () => this.onTemplatePickerDisappeared(),
            })

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
