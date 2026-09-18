import { VaultEntry, VaultField } from '@ohos/common'
import { EntryAvatar } from './EntryAvatar'
import { FavoriteToggle } from './FavoriteToggle'

const USERNAME_FIELD_NAME: string = 'UserName'

@ComponentV2
export struct EntryCard {
  @Require @Param entry: VaultEntry
  @Param avatarData: ArrayBuffer | undefined = undefined
  @Param favoriteEnabled: boolean = true
  @Event onEntryClick: (entry: VaultEntry) => void = () => {
  }
  @Event onFavoriteToggle: (next: boolean) => void = () => {
  }
  @Local private favorite: boolean = false

  aboutToAppear(): void {
    this.favorite = this.entry.favorite
  }

  @Monitor('entry')
  private onEntryChanged(): void {
    this.favorite = this.entry.favorite
  }

  @Computed
  private get username(): string {
    return this.entry.fields.find((field: VaultField) => field.name === USERNAME_FIELD_NAME)?.value ?? ''
  }

  private toggleFavorite(): void {
    this.favorite = !this.favorite
    this.onFavoriteToggle(this.favorite)
  }

  build() {
    Button({ type: ButtonType.Normal }) {
      Row({ space: $r('sys.float.padding_level8') }) {
        EntryAvatar({ title: this.entry.title, avatarData: this.avatarData })

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

        FavoriteToggle({
          favorite: this.favorite,
          clickable: this.favoriteEnabled,
          onToggle: () => this.toggleFavorite(),
        })

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize($r('sys.float.Title_S'))
          .fontWeight(FontWeight.Medium)
          .fontColor([$r('sys.color.font_secondary')])
      }
      .width('100%')
      .padding($r('sys.float.padding_level8'))
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding(0)
    .backgroundColor($r('sys.color.comp_background_primary'))
    // border 的适用性大于 borderRadius，必须先写 border，否则圆角会被覆盖掉。
    .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
    .borderRadius($r('sys.float.corner_radius_level10'))
    .onClick(() => this.onEntryClick(this.entry))
  }
}
