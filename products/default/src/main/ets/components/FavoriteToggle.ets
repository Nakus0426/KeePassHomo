import { IconToggleButton } from './IconToggleButton'

// 收藏只换图标与主色，不换按钮形态；独占交互避免同时触发所在行点击。
@ComponentV2
export struct FavoriteToggle {
  @Param favorite: boolean = false
  @Param visible: boolean = true
  @Param clickable: boolean = true
  @Event onToggle: (next: boolean) => void = () => {
  }

  build() {
    if (this.visible) {
      IconToggleButton({
        symbol: this.favorite ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'),
        symbolColor: this.favorite ? $r('app.color.ds_primary') : $r('app.color.ds_text_tertiary'),
        accessibilityLabel: this.favorite ? $r('app.string.remove_favorite') : $r('app.string.add_favorite'),
        clickable: this.clickable,
        // 收藏按钮嵌在整卡可点区域里，独占交互才能避免同时触发卡片点击。
        exclusive: true,
        onToggle: () => this.onToggle(!this.favorite),
      })
    }
  }
}
