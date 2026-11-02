import { HdsNavDestination } from '@kit.UIDesignKit'
import { VaultFormat } from '@ohos/common'
import { DsPageHeader } from '../../components/DsPageHeader'
import { dsNavPageTitleBarOptions } from '../../components/DsPageTitleBar'
import { appRouter } from '../../navigation/AppRouter'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { VaultAccess, VaultUnreadableReason } from '../../model/StageOneVaultStore'
import { DsBottomActionBar } from '../../components/DsBottomActionBar'
import { DsButton, DsButtonSize, DsButtonTone, DsButtonVariant } from '../../components/DsButton'
import { DsLoadingIndicator, DsLoadingIndicatorSize, DsLoadingIndicatorTone } from '../../components/DsLoadingIndicator'
import { DsNotice, DsNoticeTone } from '../../components/DsNotice'
import { Tag, TagShape, TagType } from '../../components/Tag'

const TILE_HEIGHT: number = 68
const FILE_NAME_LINE_HEIGHT: number = 19
const TRACKING_TIGHT: number = -0.3
const TRACKING_WIDE_XS: number = 0.2
const TRACKING_WIDE_MD: number = 0.6

enum SummaryAction {
  None = 'none',
  Reselect = 'reselect',
  SaveAs = 'saveAs',
  Retry = 'retry',
}

@ComponentV2
export struct FileSummaryPage {
  private readonly viewModel: AppViewModel = appViewModel
  @Local private busyAction: SummaryAction = SummaryAction.None
  @Local private bottomBarHeight: number = 0

  @Computed
  get access(): VaultAccess | undefined {
    return this.viewModel.fileSummary?.access
  }

  @Computed
  get readOnly(): boolean {
    return this.access === VaultAccess.ReadOnlyFormat
      || this.access === VaultAccess.ReadOnlyPermission
      || this.access === VaultAccess.ReadOnlyFileSystem
  }

  @Computed
  get statusTagType(): TagType {
    if (this.access === VaultAccess.Unreadable) {
      return TagType.Alert
    }
    return this.readOnly ? TagType.Warning : TagType.Confirm
  }

  @Computed
  get noticeVisible(): boolean {
    return this.access === VaultAccess.ReadOnlyFormat
      || this.access === VaultAccess.ReadOnlyPermission
      || this.access === VaultAccess.ReadOnlyFileSystem
  }

  // 错误态由不可读状态驱动：打开失败时仍保留摘要，供卡片显示是哪个文件。
  @Computed
  get errorVisible(): boolean {
    return this.access === VaultAccess.Unreadable
  }

  @Computed
  get emptyVisible(): boolean {
    return this.viewModel.fileSummary === undefined
  }

  // 只有读不到文件时才给出重试：格式不支持重试同一文件没有意义。
  @Computed
  get retryVisible(): boolean {
    return this.access === VaultAccess.Unreadable
      && this.viewModel.fileSummary?.unreadableReason === VaultUnreadableReason.CannotOpen
  }

  @Computed
  get errorBody(): Resource {
    return this.viewModel.fileSummary?.unreadableReason === VaultUnreadableReason.NotKdbx
      ? $r('app.string.file_summary_error_not_kdbx')
      : $r('app.string.file_summary_error_cannot_open')
  }

  // 缺写授权不是错误，用中性面底；格式与文件系统限制才用警示底。
  @Computed
  get noticeWarningTone(): boolean {
    return this.access !== VaultAccess.ReadOnlyPermission
  }

  @Computed
  get noticeTitle(): Resource {
    switch (this.access) {
      case VaultAccess.ReadOnlyFormat:
        return $r('app.string.read_only_format_title')
      case VaultAccess.ReadOnlyPermission:
        return $r('app.string.read_only_permission_title')
      default:
        return $r('app.string.read_only_file_system_title')
    }
  }

  @Computed
  get noticeBody(): Resource {
    switch (this.access) {
      case VaultAccess.ReadOnlyFormat:
        return $r('app.string.read_only_format_body')
      case VaultAccess.ReadOnlyPermission:
        return $r('app.string.read_only_permission_body')
      default:
        return $r('app.string.read_only_file_system_body')
    }
  }

  // 状态格图标与标签语义同步：可读写是开锁，只读与不可读是闭锁。
  @Computed
  get statusTileIcon(): Resource {
    return this.readOnly ? $r('app.string.symbol_lock') : $r('app.string.symbol_lock_open')
  }

  // 不可读时状态是「无法打开」而非「只读」，两者不能共用标签。
  @Computed
  get statusLabel(): Resource {
    if (this.access === VaultAccess.Unreadable) {
      return $r('app.string.file_access_unreadable')
    }
    return this.readOnly ? $r('app.string.read_only') : $r('app.string.writable')
  }

  private async reselectFile(): Promise<void> {
    this.busyAction = SummaryAction.Reselect
    try {
      await this.viewModel.chooseLocalVault()
    } finally {
      this.busyAction = SummaryAction.None
    }
  }

  private async retryOpen(): Promise<void> {
    this.busyAction = SummaryAction.Retry
    try {
      await this.viewModel.retryOpenVault()
    } finally {
      this.busyAction = SummaryAction.None
    }
  }

  private async saveAsOtherLocation(): Promise<void> {    this.busyAction = SummaryAction.SaveAs
    try {
      await this.viewModel.saveAsLocalVault()
    } finally {
      this.busyAction = SummaryAction.None
    }
  }

  @Builder
  private pageHeaderBuilder() {
    DsPageHeader({
      title: $r('app.string.file_selected_title'),
      showBack: true,
      onBack: () => appRouter.pop(),
    })
  }

  @Builder
  private fileCard() {
    Row({ space: $r('app.float.ds_space_10') }) {
      SymbolGlyph($r('app.string.symbol_description'))
        .fontSize($r('app.float.ds_icon_sm'))
        .fontColor([$r('app.color.ds_text_tertiary')])
        .foregroundColor($r('app.color.ds_text_tertiary'))
      Text(this.viewModel.fileSummary?.name ?? '')
        .layoutWeight(1)
        .fontSize($r('app.float.ds_font_title_md'))
        .fontWeight(600)
        .lineHeight(FILE_NAME_LINE_HEIGHT)
        .letterSpacing(TRACKING_TIGHT)
        .fontColor($r('app.color.ds_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .ellipsisMode(EllipsisMode.CENTER)
    }
    .width('100%')
    .padding($r('app.float.ds_space_16'))
    .backgroundColor($r('app.color.ds_surface_container'))
    .borderRadius($r('app.float.ds_radius_none'))
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private tileLabelRow(icon: Resource, label: Resource) {
    Row({ space: $r('app.float.ds_space_6') }) {
      SymbolGlyph(icon)
        .fontSize($r('app.float.ds_icon_tiny'))
        .fontColor([$r('app.color.ds_text_tertiary')])
        .foregroundColor($r('app.color.ds_text_tertiary'))
      Text(label)
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontColor($r('app.color.ds_text_tertiary'))
        .letterSpacing(TRACKING_WIDE_XS)
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private valueTile(icon: Resource, label: Resource, value: ResourceStr) {
    Column() {
      this.tileLabelRow(icon, label)
      Text(value)
        .width('100%')
        .fontSize($r('app.float.ds_font_body'))
        .fontWeight(600)
        .letterSpacing(TRACKING_TIGHT)
        .fontColor($r('app.color.ds_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(TILE_HEIGHT)
    .padding($r('app.float.ds_space_md'))
    .backgroundColor($r('app.color.ds_surface_container'))
    .borderRadius($r('app.float.ds_radius_none'))
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private statusTile() {
    Column() {
      this.tileLabelRow(this.statusTileIcon, $r('app.string.file_status'))
      Row() {
        Tag({ type: this.statusTagType, shape: TagShape.Square }) {
          Text(this.statusLabel)
            .fontSize($r('app.float.ds_font_label_sm'))
            .fontWeight(600)
            .letterSpacing(TRACKING_WIDE_MD)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
    }
    .layoutWeight(1)
    .height(TILE_HEIGHT)
    .padding($r('app.float.ds_space_md'))
    .backgroundColor($r('app.color.ds_surface_container'))
    .borderRadius($r('app.float.ds_radius_none'))
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Start)
  }

  @Computed
  get formatText(): ResourceStr {
    if (this.access === VaultAccess.Unreadable) {
      return $r('app.string.file_format_unknown')
    }
    return this.viewModel.formatName(this.viewModel.fileSummary?.format ?? VaultFormat.Unsupported)
  }

  @Computed
  get sizeText(): ResourceStr {
    const size: number = this.viewModel.fileSummary?.size ?? 0
    return size > 0 ? this.viewModel.formatSize(size) : $r('app.string.file_value_unknown')
  }

  @Computed
  get modifiedText(): ResourceStr {
    const modifiedAt: number = this.viewModel.fileSummary?.modifiedAt ?? 0
    return modifiedAt > 0
      ? this.viewModel.formatTime(modifiedAt * 1000) : $r('app.string.file_value_unknown')
  }

  @Builder
  private detailGrid() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      Row({ space: $r('app.float.ds_space_sm') }) {
        this.valueTile($r('app.string.symbol_data_object'), $r('app.string.file_format'), this.formatText)
        this.valueTile($r('app.string.symbol_database'), $r('app.string.file_size'), this.sizeText)
      }
      .width('100%')

      Row({ space: $r('app.float.ds_space_sm') }) {
        this.valueTile($r('app.string.symbol_schedule'), $r('app.string.last_modified'), this.modifiedText)
        this.statusTile()
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  private notice() {
    DsNotice({
      tone: this.noticeWarningTone ? DsNoticeTone.Warning : DsNoticeTone.Default,
      title: this.noticeTitle,
      body: this.noticeBody,
    })
  }

  @LocalBuilder
  private busyButtonContent(label: ResourceStr) {
    Row({ space: $r('app.float.ds_space_sm') }) {
      DsLoadingIndicator({
        indicatorSize: DsLoadingIndicatorSize.Small,
        tone: DsLoadingIndicatorTone.Surface,
      })
      Text(label)
        .fontSize($r('app.float.ds_font_title'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_tertiary'))
    }
  }

  // 同排按钮各自撑满半行：占位容器负责等分，按钮本身不能再用 100% 宽度。
  @Builder
  private secondaryButton() {
    if (this.access === VaultAccess.ReadOnlyPermission) {
      DsButton({
        variant: DsButtonVariant.Filled,
        tone: DsButtonTone.Tonal,
        buttonSize: DsButtonSize.Large,
        fullWidth: true,
        leadingIcon: $r('app.string.symbol_arrow_forward'),
        iconSizeOverride: $r('app.float.ds_icon_sm'),
        label: $r('app.string.continue_action'),
        onTap: () => this.viewModel.openUnlock(),
      })
    } else if (this.busyAction === SummaryAction.Reselect) {
      DsButton({
        variant: DsButtonVariant.Filled,
        tone: DsButtonTone.Tonal,
        buttonSize: DsButtonSize.Large,
        fullWidth: true,
        contentBuilder: () => { this.busyButtonContent($r('app.string.reselect_file')) },
      })
    } else {
      DsButton({
        variant: DsButtonVariant.Filled,
        tone: DsButtonTone.Tonal,
        buttonSize: DsButtonSize.Large,
        fullWidth: true,
        leadingIcon: $r('app.string.symbol_folder_open'),
        iconSizeOverride: $r('app.float.ds_icon_sm'),
        label: $r('app.string.reselect_file'),
        disabled: this.busyAction !== SummaryAction.None,
        onTap: () => {
          this.reselectFile()
        },
      })
    }
  }

  @Builder
  private primaryButton() {
    if (this.access === VaultAccess.ReadOnlyPermission) {
      DsButton({
        buttonSize: DsButtonSize.Large,
        fullWidth: true,
        trailingIcon: $r('app.string.symbol_arrow_forward'),
        label: $r('app.string.regrant_and_open'),
        disabled: this.busyAction !== SummaryAction.None,
        onTap: () => {
          this.reselectFile()
        },
      })
    } else {
      DsButton({
        buttonSize: DsButtonSize.Large,
        fullWidth: true,
        trailingIcon: $r('app.string.symbol_arrow_forward'),
        label: $r('app.string.continue_action'),
        disabled: this.busyAction !== SummaryAction.None,
        onTap: () => this.viewModel.openUnlock(),
      })
    }
  }

  @Builder
  private saveAsButton() {
    if (this.busyAction === SummaryAction.SaveAs) {
      DsButton({
        variant: DsButtonVariant.Filled,
        tone: DsButtonTone.Tonal,
        buttonSize: DsButtonSize.Large,
        fullWidth: true,
        contentBuilder: () => { this.busyButtonContent($r('app.string.save_to_other_location')) },
      })
    } else {
      DsButton({
        variant: DsButtonVariant.Filled,
        tone: DsButtonTone.Tonal,
        buttonSize: DsButtonSize.Large,
        fullWidth: true,
        leadingIcon: $r('app.string.symbol_save'),
        iconSizeOverride: $r('app.float.ds_icon_sm'),
        label: $r('app.string.save_to_other_location'),
        disabled: this.busyAction !== SummaryAction.None,
        onTap: () => {
          this.saveAsOtherLocation()
        },
      })
    }
  }

  @Builder
  private errorCard() {
    DsNotice({
      tone: DsNoticeTone.Error,
      title: $r('app.string.file_summary_error_title'),
      body: this.errorBody,
    })
  }

  @Builder
  private emptyState() {
    Text($r('app.string.file_summary_empty'))
      .fontSize($r('app.float.ds_font_body'))
      .fontColor($r('app.color.ds_text_tertiary'))
  }

  @Builder
  private reselectButton(iconSize: Resource, disabled: boolean) {
    DsButton({
      buttonSize: DsButtonSize.Large,
      fullWidth: true,
      leadingIcon: $r('app.string.symbol_folder_open'),
      iconSizeOverride: iconSize,
      label: $r('app.string.reselect_file'),
      disabled: disabled,
      onTap: () => {
        this.reselectFile()
      },
    })
  }

  @Builder
  private errorActions() {
    if (this.retryVisible) {
      Row({ space: $r('app.float.ds_space_md') }) {
        Row() {
          DsButton({
            variant: DsButtonVariant.Filled,
            tone: DsButtonTone.Tonal,
            buttonSize: DsButtonSize.Large,
            fullWidth: true,
            leadingIcon: $r('app.string.symbol_refresh'),
            iconSizeOverride: $r('app.float.ds_icon_sm'),
            label: $r('app.string.retry_action'),
            disabled: this.busyAction !== SummaryAction.None,
            onTap: () => {
              this.retryOpen()
            },
          })
        }
        .layoutWeight(1)

        Row() {
          this.reselectButton($r('app.float.ds_icon_sm'), this.busyAction !== SummaryAction.None)
        }
        .layoutWeight(1)
      }
      .width('100%')
    } else {
      // 格式不支持时重试同一文件没有意义，只保留重选。
      this.reselectButton($r('app.float.ds_icon_md'), this.busyAction !== SummaryAction.None)
    }
  }

  @Builder
  private emptyActions() {
    this.reselectButton($r('app.float.ds_icon_md'), false)
  }

  @Builder
  private normalActions() {
    if (this.access === VaultAccess.ReadOnlyFileSystem) {
      this.saveAsButton()
    }

    Row({ space: $r('app.float.ds_space_md') }) {
      Row() {
        this.secondaryButton()
      }
      .layoutWeight(1)

      Row() {
        this.primaryButton()
      }
      .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  private bottomActionContent() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      if (this.errorVisible) {
        this.errorActions()
      } else if (this.emptyVisible) {
        this.emptyActions()
      } else {
        this.normalActions()
      }
    }
    .width('100%')
  }

  @Builder
  private bottomPanel() {
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
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Scroll() {
          Column({ space: $r('app.float.ds_space_sm') }) {
            if (this.viewModel.fileSummary !== undefined) {
              this.fileCard()
              this.detailGrid()
            } else if (this.emptyVisible) {
              this.emptyState()
            }
            if (this.noticeVisible) {
              this.notice()
            }
            if (this.errorVisible) {
              this.errorCard()
            }
          }
          .width('100%')
          .height(this.emptyVisible ? '100%' : undefined)
          .justifyContent(this.emptyVisible ? FlexAlign.Center : FlexAlign.Start)
          .padding({
            top: $r('app.float.ds_space_lg'),
            bottom: this.bottomBarHeight,
            left: $r('app.float.ds_gutter'),
            right: $r('app.float.ds_gutter'),
          })
          .alignItems(this.emptyVisible ? HorizontalAlign.Center : HorizontalAlign.Start)
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .clip(false)
        .align(Alignment.Top)

        this.bottomPanel()
      }
      .width('100%')
      .height('100%')
    }
    .titleBar(dsNavPageTitleBarOptions((): void => this.pageHeaderBuilder()))
    .hideBackButton(true)
    .backgroundColor($r('app.color.ds_surface_canvas'))
  }
}

@Builder
export function fileSummaryPageBuilder() {
  FileSummaryPage()
}
