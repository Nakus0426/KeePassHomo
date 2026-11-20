import { AnimationTokens, measureVp } from '@ohos/common'
import { DsCheckbox } from '../../components/DsCheckbox'
import { EntryAvatar } from '../../components/EntryAvatar'
import { FavoriteToggle } from '../../components/FavoriteToggle'
import { EntryRowModel } from '../../viewmodel/EntryRowModel'
import { VaultHomeViewModel, vaultHomeViewModel } from '../../viewmodel/VaultHomeViewModel'
import { DsControlSize } from '../../components/DsControlSize'

// 密集条目行：只渲染行模型与本地点击，业务动作由首页统一编排。
@ComponentV2
export struct VaultEntryRow {
  @Require @Param row: EntryRowModel
  @Param favoriteEnabled: boolean = true
  @Local private home: VaultHomeViewModel = vaultHomeViewModel
  @Event onRowClick: () => void = () => {
  }
  @Event onFavoriteToggle: (next: boolean) => void = () => {
  }
  @Local private hovered: boolean = false
  @Local private pressed: boolean = false

  @Computed
  get checkboxSlot(): number {
    return measureVp(this.getUIContext(), $r('app.float.ds_checkbox_size_sm'))
  }

  @Computed
  get inlineGap(): number {
    return measureVp(this.getUIContext(), $r('app.float.ds_space_md'))
  }

  // pen 条目行尾部：收藏 44 + 间距 12 + 箭头 24 + 间距 12。
  @Computed
  get trailingInset(): number {
    return measureVp(this.getUIContext(), $r('app.float.ds_button_height'))
      + measureVp(this.getUIContext(), $r('app.float.ds_entry_action_icon'))
      + this.inlineGap * 2
  }

  @Computed
  get selected(): boolean {
    return this.home.batchMode && this.home.isSelected(this.row.uuid)
  }

  aboutToAppear(): void {
    this.row.ensureAvatar()
  }

  @Monitor('row')
  onRowChanged(): void {
    this.row.ensureAvatar()
  }

  @Monitor('row.hasAvatar')
  onAvatarAvailabilityChanged(): void {
    this.row.ensureAvatar()
  }

  build() {
    Stack({ alignContent: Alignment.End }) {
      Row() {
        // 复选框槽常态用负外边距抵消自身宽度：进出多选时与内容同向横移，不裁剪以保留 3vp 状态环。
        Row() {
          DsCheckbox({
            checked: this.selected,
            checkboxSize: DsControlSize.Small,
            hovered: this.hovered,
            pressed: this.pressed,
          })
        }
        .width(this.checkboxSlot)
        .margin({
          left: this.home.batchMode ? 0 : -(this.checkboxSlot + this.inlineGap),
          right: this.inlineGap,
        })
        .opacity(this.home.batchMode ? 1 : 0)
        .accessibilityLevel(this.home.batchMode ? 'auto' : 'no-hide-descendants')
        .animation(AnimationTokens.FEEDBACK_ANIMATION)

        EntryAvatar({
          title: this.row.title,
          avatarData: this.row.avatarData,
          avatarSize: $r('app.float.ds_entry_avatar_size'),
          initialsFontSize: $r('app.float.ds_font_label_sm'),
          square: true,
          fallbackIcon: this.row.templateIcon,
          fallbackIconSize: $r('app.float.ds_icon_sm'),
        })

        Column({ space: $r('app.float.ds_space_2') }) {
          Text(this.row.title)
            .width('100%')
            .fontSize($r('app.float.ds_font_title'))
            .fontWeight(600)
            .fontColor($r('app.color.ds_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.row.subtitle)
            .width('100%')
            .fontSize($r('app.float.ds_font_body_sm'))
            .fontColor($r('app.color.ds_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        // 尾部操作区叠放在行尾，文本右让位随之收放，批量态文本区宽度与 pen 一致。
        .margin({
          left: this.inlineGap,
          right: this.home.batchMode ? 0 : this.trailingInset,
        })
        .animation(AnimationTokens.FEEDBACK_ANIMATION)
      }
      .width('100%')
      .height('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: $r('app.float.ds_space_md') }) {
        FavoriteToggle({
          favorite: this.row.favorite,
          clickable: this.favoriteEnabled,
          onToggle: (next: boolean) => this.onFavoriteToggle(next),
        })

        SymbolGlyph($r('app.string.symbol_chevron_right'))
          .fontSize($r('app.float.ds_entry_action_icon'))
          .fontColor([$r('app.color.ds_text_tertiary')])
          .foregroundColor($r('app.color.ds_text_tertiary'))
      }
      .opacity(this.home.batchMode ? 0 : 1)
      .hitTestBehavior(this.home.batchMode ? HitTestMode.None : HitTestMode.Default)
      .accessibilityLevel(this.home.batchMode ? 'no-hide-descendants' : 'auto')
      .animation(AnimationTokens.FEEDBACK_ANIMATION)
    }
    .width('100%')
    .clip(true)
    .height($r('app.float.ds_entry_row_height'))
    .padding({ left: $r('app.float.ds_gutter'), right: $r('app.float.ds_gutter') })
    .backgroundColor(this.pressed
      ? $r('app.color.ds_surface_highest')
      : (this.hovered || this.selected ? $r('app.color.ds_surface_hover') : $r('app.color.ds_surface_canvas')))
    // 离场收高与倒塌由 DsListRowMotion 承担，这里只保留底色切换的反馈动画。
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
    .onClick(() => this.onRowClick())
  }
}
