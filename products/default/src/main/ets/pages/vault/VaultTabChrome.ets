import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { vaultHomeViewModel, VaultHomeViewModel } from '../../viewmodel/VaultHomeViewModel'
import { ModuleTabChrome } from '../../components/ModuleTabChrome'
import { PASSWORD_FONT_FAMILY } from '../../constants/FontConstants'
import { ResUtil } from '@pura/harmony-utils'
import { DsButton, DsButtonSize, DsButtonVariant } from '../../components/DsButton'
import { DsInput, DsInputSize } from '../../components/DsInput'
import { DsSegmentedSwitch, DsSegmentedSwitchItem } from '../../components/DsSegmentedSwitch'
import { DsTag, DsTagSize, DsTagTone } from '../../components/DsTag'
import { EntryGroupPicker } from './EntryGroupPicker'

@ComponentV2
struct VaultHeaderBar {
  @Local private app: AppViewModel = appViewModel
  // 副标题可用宽度实测：标题列宽 − 版本 Tag 宽 − 间距，用于限制保险库名并中间省略。
  @Local private titleColumnWidth: number = 0
  @Local private versionTagWidth: number = 0

  @Computed
  get vaultName(): string {
    return this.app.vaultDisplayName()
  }

  @Computed
  get nameMaxWidth(): number {
    const gap: number = this.getUIContext().px2vp(ResUtil.getNumber($r('app.float.ds_space_6').id))
    const available: number = this.titleColumnWidth - this.versionTagWidth - gap
    return available > 0 ? available : 0
  }

  @Computed
  get formatLabel(): string {
    return this.app.currentFormatLabel()
  }

  build() {
    Row() {
      Column({ space: $r('app.float.ds_space_sm') }) {
        Text($r('app.string.vault_home'))
          .fontSize($r('app.float.ds_font_display'))
          .fontWeight(600)
          .letterSpacing($r('app.float.ds_tracking_tight'))
          .fontColor($r('app.color.ds_text_primary'))
          .maxLines(1)

        if (this.app.hasRecentVault()) {
          Row({ space: $r('app.float.ds_space_6') }) {
            Text(this.vaultName)
              .fontSize($r('app.float.ds_font_label_sm'))
              .fontWeight(500)
              .fontColor($r('app.color.ds_text_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .ellipsisMode(EllipsisMode.CENTER)
              .constraintSize({ maxWidth: this.nameMaxWidth })

            Row() {
              DsTag({ tone: DsTagTone.Default, tagSize: DsTagSize.Small, text: this.formatLabel })
            }
            .onAreaChange((_old: Area, newValue: Area) => {
              this.versionTagWidth = Number(newValue.width)
            })
          }
          .alignItems(VerticalAlign.Center)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Center)
      .onAreaChange((_old: Area, newValue: Area) => {
        this.titleColumnWidth = Number(newValue.width)
      })

      Row({ space: $r('app.float.ds_space_sm') }) {
        DsButton({
          variant: DsButtonVariant.Text,
          buttonSize: DsButtonSize.Medium,
          iconOnly: true,
          leadingIcon: $r('app.string.symbol_lock'),
          iconSizeOverride: $r('app.float.ds_icon_md'),
          iconColorOverride: $r('app.color.ds_text_primary'),
          accessibilityLabelResource: $r('app.string.lock'),
          onTap: () => {
            this.app.lockVault()
          },
        })

        // 参考解锁页右上角：图标按钮切换保险库。
        DsButton({
          variant: DsButtonVariant.Text,
          buttonSize: DsButtonSize.Medium,
          iconOnly: true,
          leadingIcon: $r('app.string.symbol_swap_horiz'),
          iconSizeOverride: $r('app.float.ds_icon_md'),
          iconColorOverride: $r('app.color.ds_text_primary'),
          accessibilityLabelResource: $r('app.string.choose_another_vault'),
          onTap: () => this.app.chooseAnotherVault(),
        })
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .alignItems(VerticalAlign.Center)
    .padding({
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
    })
  }
}

@Builder
function vaultTitleRowBuilder() {
  VaultHeaderBar()
}

@ComponentV2
struct VaultFilter {
  @Local private home: VaultHomeViewModel = vaultHomeViewModel
  @Local private app: AppViewModel = appViewModel
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private groupPickerVisible: boolean = false
  private groupPickerBackHandler: (() => boolean) | undefined = undefined

  @Computed
  get browseIndex(): number {
    return this.home.browseIndex
  }

  @Computed
  get modeItems(): DsSegmentedSwitchItem[] {
    return [
      { label: $r('app.string.all_entry'), enabled: true },
      { label: $r('app.string.favorited'), enabled: true },
      { label: $r('app.string.archived'), enabled: true },
    ]
  }

  @Computed
  get groupFilterLabel(): string {
    return this.home.selectedGroupLabel()
  }

  @Computed
  get groupPickerBottomOffset(): number {
    return this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx)
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
    if (this.home.searchQuery.length > 0) {
      DsButton({
        variant: DsButtonVariant.Text,
        buttonSize: DsButtonSize.Small,
        iconOnly: true,
        leadingIcon: $r('app.string.symbol_close'),
        iconSizeOverride: $r('app.float.ds_icon_xs'),
        iconColorOverride: $r('app.color.ds_text_secondary'),
        accessibilityLabelResource: $r('app.string.close'),
        onTap: () => this.home.setSearchQuery(''),
      })
    }
  }

  @Builder
  private groupPickerSheet() {
    EntryGroupPicker({
      initialGroupUuid: this.home.selectedGroupUuids.length > 0 ? this.home.selectedGroupUuids[0] : '',
      bottomOffset: this.groupPickerBottomOffset,
      onPicked: (groupUuid: string) => {
        this.home.selectBrowseGroups([groupUuid])
        this.groupPickerVisible = false
      },
      onClose: () => this.groupPickerVisible = false,
      onActivity: () => this.app.recordActivity(),
      onBackHandler: (handler: () => boolean) => this.groupPickerBackHandler = handler,
    })
  }

  // 返回键、边缘返回手势、导航栏返回都归入 PRESS_BACK，先交给选择器消费；其余原因按默认关闭。
  private onGroupPickerWillDismiss(action: DismissSheetAction): void {
    const backHandler: (() => boolean) | undefined = this.groupPickerBackHandler
    if (action.reason === DismissReason.PRESS_BACK && backHandler !== undefined && backHandler()) {
      return
    }
    action.dismiss()
  }

  build() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      DsInput({
        placeholder: $r('app.string.search_vault'),
        text: this.home.searchQuery,
        inputSize: DsInputSize.Medium,
        leadingBuilder: this.searchLeading,
        trailingBuilder: this.searchTrailing,
        onChange: (value: string) => this.home.setSearchQuery(value),
        onSubmit: () => this.app.recordActivity(),
      })

      Row() {
        Row() {
          DsSegmentedSwitch({
            items: this.modeItems,
            selectedIndex: this.browseIndex,
            transparentBackground: true,
            onSelect: (index: number) => this.home.setBrowseModeAtIndex(index),
          })
        }
        .layoutWeight(1)

        DsButton({
          label: this.groupFilterLabel,
          variant: DsButtonVariant.Text,
          buttonSize: DsButtonSize.Small,
          leadingIcon: $r('app.string.symbol_folder'),
          trailingIcon: $r('app.string.symbol_chevron_down'),
          iconSizeOverride: $r('app.float.ds_icon_xs'),
          iconColorOverride: $r('app.color.ds_text_secondary'),
          contentColorOverride: $r('app.color.ds_text_secondary'),
          labelFontSizeOverride: $r('app.float.ds_font_label_md'),
          labelWeightOverride: FontWeight.Medium,
          horizontalPaddingOverride: $r('app.float.ds_space_xs'),
          onTap: () => this.groupPickerVisible = true,
        })
      }
      .width('100%')
      .height($r('app.float.ds_tab_height_md'))
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
      top: $r('app.float.ds_space_sm'),
      bottom: $r('app.float.ds_space_sm'),
    })
    .bindSheet($$this.groupPickerVisible, this.groupPickerSheet(), {
      dragBar: true,
      showClose: false,
      backgroundColor: $r('app.color.ds_surface_lowest'),
      onWillDismiss: (action: DismissSheetAction) => this.onGroupPickerWillDismiss(action),
      onDisappear: () => {
        this.groupPickerVisible = false
        this.groupPickerBackHandler = undefined
      },
    })
  }
}

@ComponentV2
struct VaultSelectionHeader {
  @Local private home: VaultHomeViewModel = vaultHomeViewModel

  @Computed
  get selectedCount(): number {
    return this.home.selectedUuids.length
  }

  private format(resId: number, value: string): string {
    return ResUtil.getStringSync(resId, [value])
  }

  build() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      DsButton({
        variant: DsButtonVariant.Text,
        buttonSize: DsButtonSize.Medium,
        iconOnly: true,
        leadingIcon: $r('app.string.symbol_close'),
        iconSizeOverride: $r('app.float.ds_icon_md'),
        iconColorOverride: $r('app.color.ds_text_primary'),
        accessibilityLabelResource: $r('app.string.entry_batch_cancel'),
        onTap: () => this.home.exitBatch(),
      })

      Column({ space: $r('app.float.ds_space_2') }) {
        Text(this.format($r('app.string.entry_batch_title').id, String(this.selectedCount)))
          .fontSize($r('app.float.ds_font_headline'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_text_primary'))
          .maxLines(1)

        Text($r('app.string.entry_batch_note'))
          .fontSize($r('app.float.ds_font_label_sm'))
          .fontFamily(PASSWORD_FONT_FAMILY)
          .fontColor($r('app.color.ds_text_tertiary'))
          .maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      DsButton({
        label: $r('app.string.entry_batch_select_all'),
        variant: DsButtonVariant.Text,
        buttonSize: DsButtonSize.Medium,
        horizontalPaddingOverride: $r('app.float.ds_space_sm'),
        contentColorOverride: $r('app.color.ds_text_primary'),
        onTap: () => this.home.selectAllVisible(),
      })
    }
    .width('100%')
    .height($r('app.float.ds_page_header_height_lg'))
    .padding({
      top: $r('app.float.ds_space_10'),
      bottom: $r('app.float.ds_space_10'),
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
    })
    .alignItems(VerticalAlign.Center)
  }
}

@Builder
function vaultSelectionRowBuilder() {
  VaultSelectionHeader()
}

@Builder
function vaultBottomRowBuilder() {
  VaultFilter()
}

export const vaultTabChrome: ModuleTabChrome = {
  titleRowBuilder: wrapBuilder(vaultTitleRowBuilder),
  selectionRowBuilder: wrapBuilder(vaultSelectionRowBuilder),
  bottomRowBuilder: wrapBuilder(vaultBottomRowBuilder),
}
