import { VaultEntry, VaultField } from '@ohos/common'
import { IconToggleButton } from './IconToggleButton'

const USERNAME_FIELD_NAME: string = 'UserName'
const EMPTY_TITLE_PLACEHOLDER: string = '?'

/**
 * 保险库条目行：左侧首字圆形图标，中间名称与用户名两行，右侧收藏按钮与箭头。
 * 整行为 Button，点击反馈由按压背景色表达。
 */
@ComponentV2
export struct EntryRow {
  @Require @Param entry: VaultEntry
  @Param favoriteEnabled: boolean = true
  @Event onEntryClick: (entry: VaultEntry) => void = () => {
  }
  @Event onFavoriteToggle: (next: boolean) => void = () => {
  }
  /** 乐观显示态：点击立即翻转，父层落盘失败时由 entry 重新传入纠正。 */
  @Local private favorite: boolean = false

  aboutToAppear(): void {
    this.favorite = this.entry.favorite
  }

  @Monitor('entry')
  private onEntryChanged(): void {
    this.favorite = this.entry.favorite
  }

  @Computed
  private get initial(): string {
    const title: string = this.entry.title.trim()
    return title.length === 0 ? EMPTY_TITLE_PLACEHOLDER : title.charAt(0).toUpperCase()
  }

  @Computed
  private get username(): string {
    return this.entry.fields.find((field: VaultField) => field.name === USERNAME_FIELD_NAME)?.value ?? ''
  }

  @Computed
  private get favoriteColor(): ResourceColor {
    return this.favorite && this.favoriteEnabled ? $r('sys.color.brand') : $r('sys.color.font_secondary')
  }

  private toggleFavorite(): void {
    const next: boolean = !this.favorite
    this.favorite = next
    this.onFavoriteToggle(next)
  }

  build() {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Row({ space: $r('sys.float.padding_level4') }) {
        Text(this.initial)
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.brand'))
          .textAlign(TextAlign.Center)
          .padding($r('sys.float.padding_level4'))
          // 直径由首字与内边距撑开，aspectRatio 保证正圆而非椭圆。
          .aspectRatio(1)
          .borderRadius('50%')
          .backgroundColor($r('sys.color.comp_emphasize_secondary'))

        Column({ space: $r('sys.float.padding_level1') }) {
          Text(this.entry.title)
            .width('100%')
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(this.username)
            .width('100%')
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        IconToggleButton({
          symbol: this.favorite ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'),
          symbolColor: this.favoriteColor,
          accessibilityLabel: this.favorite ? $r('app.string.remove_favorite') : $r('app.string.add_favorite'),
          clickable: this.favoriteEnabled,
          onToggle: () => this.toggleFavorite(),
        })

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor([$r('sys.color.font_secondary')])
      }
      .width('100%')
      .padding($r('sys.float.padding_level4'))
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor(Color.Transparent)
    .borderRadius($r('sys.float.corner_radius_level8'))
    .stateStyles({
      pressed: {
        .backgroundColor($r('sys.color.interactive_pressed'))
      },
    })
    .onClick(() => this.onEntryClick(this.entry))
  }
}
