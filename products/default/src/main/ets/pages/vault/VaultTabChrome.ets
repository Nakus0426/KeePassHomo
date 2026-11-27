import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { vaultHomeViewModel, VaultHomeViewModel } from '../../viewmodel/VaultHomeViewModel'
import { ModuleTabChrome } from '../../components/ModuleTabChrome'
import { PASSWORD_FONT_FAMILY } from '../../constants/FontConstants'
import { ResUtil } from '@pura/harmony-utils'
import { AnimationTokens, VaultGroup } from '@ohos/common'
import { DsBadge, DsBadgeSize } from '../../components/DsBadge'
import { DsButton, DsButtonVariant } from '../../components/DsButton'
import { DsContextMenu, dsMenuOptions } from '../../components/DsContextMenu'
import { DsInput } from '../../components/DsInput'
import { DsMenuItem } from '../../components/DsMenuItem'
import { DsSegmentedSwitch, DsSegmentedSwitchItem } from '../../components/DsSegmentedSwitch'
import { DsTag, DsTagSize, DsTagTone } from '../../components/DsTag'
import { DsGroupPicker, GroupPickerSource } from '../../components/DsGroupPicker'
import { createGroupFromPicker } from './GroupPickerActions'
import { dsSheetOptions } from '../../components/DsSheetOptions'
import { DsControlSize } from '../../components/DsControlSize'
import { VaultSortField, VaultTagOption } from '../../model/StageOneVaultStore'
import { dsTagFilterSheetHeight, TagFilterSheet } from './TagFilterSheet'

// 设计稿：模式切换固定 216（3 × 72），右侧三个图标按钮各 32、间距 8。
const SWITCH_WIDTH_VP: number = 216
const ACTION_SIZE_VP: number = 32

@ComponentV2
struct VaultHeaderBar {
  @Local private app: AppViewModel = appViewModel
  // 副标题可用宽度实测：标题列宽 − 版本 Tag 宽 − 间距，用于限制保险库名并中间省略。
  @Local private titleColumnWidth: number = 0
  @Local private versionTagWidth: number = 0

  // 不能写成 @Computed：@Computed 在组件构造期求值，未选保险库时 currentSource 会抛错，
  // 而 hasRecentVault 只在 build 里挡住渲染，挡不住构造。
  private vaultName(): string {
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
            Text(this.vaultName())
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
          buttonSize: DsControlSize.Medium,
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
          buttonSize: DsControlSize.Medium,
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

// 标题行与批量选择头同高：切换时交叉淡入，避免整行闪现。
// 只挂载当前模式那一行：常驻叠放会让不可见层在几何上盖住可见层的按钮。
const HEADER_FADE: TransitionEffect = TransitionEffect.OPACITY.animation(AnimationTokens.FEEDBACK_ANIMATION)

@ComponentV2
struct VaultHeaderStack {
  @Local private home: VaultHomeViewModel = vaultHomeViewModel

  build() {
    Stack() {
      if (this.home.batchMode) {
        Row() {
          VaultSelectionHeader()
        }
        .width('100%')
        .height('100%')
        .transition(HEADER_FADE)
      } else {
        Row() {
          VaultHeaderBar()
        }
        .width('100%')
        .height('100%')
        .transition(HEADER_FADE)
      }
    }
    .width('100%')
    .height('100%')
  }
}

@Builder
function vaultTitleRowBuilder() {
  VaultHeaderStack()
}

@ComponentV2
struct VaultFilter {
  @Local private home: VaultHomeViewModel = vaultHomeViewModel
  @Local private app: AppViewModel = appViewModel
  @Local private groupPickerVisible: boolean = false
  @Local private tagSheetVisible: boolean = false
  // 打开面板时一次性取全库标签，避免每次渲染都遍历条目。
  @Local private tagOptions: VaultTagOption[] = []
  // 半模态高度由面板导出函数按标签内容计算。
  @Local private tagSheetHeight: number = 300
  // 筛选区实测宽度：面板宽度随之变化，而不是按手机稿写死。
  @Local private filterWidthVp: number = 0
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

  private openTagFilter(): void {
    this.tagOptions = this.home.tagOptions()
    const width: number = this.filterWidthVp > 0 ? this.filterWidthVp : 390
    this.tagSheetHeight = dsTagFilterSheetHeight(this.getUIContext(),
      this.tagOptions.map((option: VaultTagOption) => option.tag), width)
    this.tagSheetVisible = true
  }

  @Builder
  private tagSheet() {
    TagFilterSheet({
      tags: this.tagOptions,
      initialTags: this.home.selectedTags,
      onApply: (tags: string[]) => {
        this.getUIContext().animateTo(AnimationTokens.FEEDBACK_ANIMATION, () => this.home.setSelectedTags(tags))
        this.tagSheetVisible = false
      },
      onClose: () => this.tagSheetVisible = false,
    })
  }

  @Builder
  private sortMenuHeader() {
    Column({ space: $r('app.float.ds_space_2') }) {
      Text($r('app.string.sort_menu_title'))
        .fontSize($r('app.float.ds_font_body'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))
        .maxLines(1)

      Text($r('app.string.sort_menu_subtitle'))
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontColor($r('app.color.ds_text_secondary'))
        .maxLines(1)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: $r('app.float.ds_space_16'),
      right: $r('app.float.ds_space_16'),
      top: $r('app.float.ds_space_md'),
      bottom: $r('app.float.ds_space_md'),
    })
    .backgroundColor($r('app.color.ds_surface_low'))
  }

  @Builder
  private sortRow(label: Resource, field: VaultSortField) {
    Row() {
      Text(label)
        .fontSize($r('app.float.ds_font_body'))
        .fontColor($r('app.color.ds_text_primary'))
        .maxLines(1)

      Blank()

      if (this.home.sortField === field) {
        SymbolGlyph($r('app.string.symbol_check'))
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([$r('app.color.ds_primary')])
          .foregroundColor($r('app.color.ds_primary'))
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: $r('app.float.ds_space_16'),
      right: $r('app.float.ds_space_16'),
    })
    .alignItems(VerticalAlign.Center)
  }

  // @BuilderParam 的内容必须委托给 @Builder：在箭头里直接构造自定义组件会在渲染时抛
  // class constructor cannot called without 'new'。
  @LocalBuilder
  private sortItems() {
    DsMenuItem({
      customRow: () => {
        this.sortRow($r('app.string.sort_by_title'), VaultSortField.Title)
      },
      onAction: () => this.home.setSortField(VaultSortField.Title),
    })
    DsMenuItem({
      customRow: () => {
        this.sortRow($r('app.string.sort_by_modified'), VaultSortField.LastModified)
      },
      onAction: () => this.home.setSortField(VaultSortField.LastModified),
    })
  }

  // 跨组件传给 DsButton 的 builder 必须用 @LocalBuilder，否则 this 指向调用方、菜单打不开。
  @LocalBuilder
  private sortMenu() {
    DsContextMenu({
      header: () => {
        this.sortMenuHeader()
      },
      content: () => {
        this.sortItems()
      },
    })
  }

  @LocalBuilder
  private searchLeading() {
    SymbolGlyph($r('app.string.symbol_search'))
      .fontSize($r('app.float.ds_icon_sm'))
      .fontColor([$r('app.color.ds_text_secondary')])
      .foregroundColor($r('app.color.ds_text_secondary'))
  }

  @Builder
  private groupPickerSheet() {
    DsGroupPicker({
      groupSource: (): GroupPickerSource => {
        const allGroups: VaultGroup[] = this.app.groups()
        return {
          rootGroup: allGroups[0],
          topLevelGroups: this.app.topLevelGroups(),
          allGroups,
        }
      },
      initialGroupUuid: this.home.selectedGroupUuids.length > 0 ? this.home.selectedGroupUuids[0] : '',
      busy: this.app.busy,
      onPicked: (groupUuid: string) => {
        this.home.selectBrowseGroups([groupUuid])
        this.groupPickerVisible = false
      },
      onClose: () => this.groupPickerVisible = false,
      onCreateGroup: (parentUuid: string, name: string) =>
      createGroupFromPicker(this.getUIContext(), this.app, parentUuid, name),
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
        inputSize: DsControlSize.Medium,
        leadingBuilder: this.searchLeading,
        clearable: true,
        onClear: () => this.home.setSearchQuery(''),
        onChange: (value: string) => this.home.setSearchQuery(value),
        onSubmit: () => this.app.recordActivity(),
      })

      Row() {
        // 设计稿固定 216（每段 72），不占满剩余宽度。
        Row() {
          DsSegmentedSwitch({
            items: this.modeItems,
            selectedIndex: this.browseIndex,
            transparentBackground: true,
            onSelect: (index: number) => this.home.setBrowseModeAtIndex(index),
          })
        }
        .width(SWITCH_WIDTH_VP)

        Row({ space: $r('app.float.ds_space_sm') }) {
          DsButton({
            variant: DsButtonVariant.Text,
            buttonSize: DsControlSize.Small,
            iconOnly: true,
            leadingIcon: this.home.isGroupFiltering
              ? $r('app.string.symbol_folder_filled') : $r('app.string.symbol_folder'),
            iconSizeOverride: $r('app.float.ds_icon_sm'),
            iconColorOverride: this.home.isGroupFiltering
              ? $r('app.color.ds_primary') : $r('app.color.ds_text_secondary'),
            accessibilityLabelResource: $r('app.string.filter_group_a11y'),
            onTap: () => this.groupPickerVisible = true,
          })

          Stack({ alignContent: Alignment.TopEnd }) {
            DsButton({
              variant: DsButtonVariant.Text,
              buttonSize: DsControlSize.Small,
              iconOnly: true,
              leadingIcon: $r('app.string.symbol_label'),
              iconSizeOverride: $r('app.float.ds_icon_sm'),
              iconColorOverride: this.home.isTagFiltering
                ? $r('app.color.ds_primary') : $r('app.color.ds_text_secondary'),
              accessibilityLabelResource: $r('app.string.filter_tag_a11y'),
              onTap: () => this.openTagFilter(),
            })

            if (this.home.isTagFiltering) {
              DsBadge({ badgeSize: DsBadgeSize.Medium })
                .margin({ top: -2, right: -2 })
            }
          }
          .width(ACTION_SIZE_VP)
          .height(ACTION_SIZE_VP)
          .clip(false)
          .bindSheet($$this.tagSheetVisible, this.tagSheet(), dsSheetOptions({
            detents: [this.tagSheetHeight],
            // 系统控制条样式与设计不符，面板只用 DsHalfModalSheet 自绘拖拽条。
            dragBar: false,
            onDisappear: () => {
              this.tagSheetVisible = false
            },
          }))

          DsButton({
            variant: DsButtonVariant.Text,
            buttonSize: DsControlSize.Small,
            iconOnly: true,
            leadingIcon: $r('app.string.symbol_sort'),
            iconSizeOverride: $r('app.float.ds_icon_sm'),
            iconColorOverride: this.home.sortField === VaultSortField.LastModified
              ? $r('app.color.ds_primary') : $r('app.color.ds_text_secondary'),
            accessibilityLabelResource: $r('app.string.filter_sort_a11y'),
            menuBuilder: this.sortMenu,
            menuOptions: dsMenuOptions(Placement.BottomRight),
          })
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height($r('app.float.ds_tab_height_md'))
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
      top: $r('app.float.ds_space_sm'),
      bottom: $r('app.float.ds_space_sm'),
    })
    // 批量态筛选区高度由标题栏收到 0，内容同步淡出，避免高度收起时文字被硬裁。
    .opacity(this.home.batchMode ? 0 : 1)
    .animation(AnimationTokens.FEEDBACK_ANIMATION)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      // Area 宽高本身以 vp 计，不要再做 px→vp 换算。
      this.filterWidthVp = Number(newValue.width)
    })
    .bindSheet($$this.groupPickerVisible, this.groupPickerSheet(), dsSheetOptions({
      onWillDismiss: (action: DismissSheetAction) => this.onGroupPickerWillDismiss(action),
      onDisappear: () => {
        this.groupPickerVisible = false
        this.groupPickerBackHandler = undefined
      },
    }))
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
        buttonSize: DsControlSize.Medium,
        iconOnly: true,
        leadingIcon: $r('app.string.symbol_close'),
        iconSizeOverride: $r('app.float.ds_icon_md'),
        iconColorOverride: $r('app.color.ds_text_primary'),
        accessibilityLabelResource: $r('app.string.entry_batch_cancel'),
        onTap: () => animateBatchTransition(this.getUIContext(), () => this.home.exitBatch()),
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
        buttonSize: DsControlSize.Medium,
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
function vaultBottomRowBuilder() {
  VaultFilter()
}

// 批量态切换必须走显式动画：HDS 标题栏安全区高度只有显式动画才会跟着过渡。
export function animateBatchTransition(uiContext: UIContext, action: () => void): void {
  uiContext.animateTo(AnimationTokens.FEEDBACK_ANIMATION, action)
}

export const vaultTabChrome: ModuleTabChrome = {
  titleRowBuilder: wrapBuilder(vaultTitleRowBuilder),
  bottomRowBuilder: wrapBuilder(vaultBottomRowBuilder),
}
