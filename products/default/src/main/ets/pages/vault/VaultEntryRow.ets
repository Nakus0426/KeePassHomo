import { AnimationTokens } from '@ohos/common'
import { DsCheckbox } from '../../components/DsCheckbox'
import { EntryAvatar } from '../../components/EntryAvatar'
import { FavoriteToggle } from '../../components/FavoriteToggle'
import { EntryRowModel } from '../../viewmodel/EntryRowModel'
import { VaultHomeViewModel, vaultHomeViewModel } from '../../viewmodel/VaultHomeViewModel'

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
    Row({ space: $r('app.float.ds_space_md') }) {
      if (this.home.batchMode) {
        DsCheckbox({ checked: this.home.isSelected(this.row.uuid) })
      }

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

      if (!this.home.batchMode) {
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
    }
    .width('100%')
    .clip(true)
    .height(this.row.leaving ? 0 : $r('app.float.ds_entry_row_height'))
    .opacity(this.row.leaving ? 0 : 1)
    .padding({ left: $r('app.float.ds_gutter'), right: $r('app.float.ds_gutter') })
    .backgroundColor(this.pressed
      ? $r('app.color.ds_surface_highest')
      : (this.hovered ? $r('app.color.ds_surface_hover') : $r('app.color.ds_surface_canvas')))
    // 离场由隐式动画驱动：V2 的行状态刷新时机早于首页的 animateTo 上下文，显式动画可能拿不到目标属性。
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })
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
