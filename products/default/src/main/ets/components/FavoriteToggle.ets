import { IconToggleButton } from './IconToggleButton'

/**
 * 收藏切换按钮：已收藏为实心星、未收藏为空心星，切换时播放弹跳动画。
 * 状态由宿主持有并落盘，组件只负责反馈与回调。
 * 星标色用 app.color.favorite：系统色板没有收藏语义，橘黄为产品指定色。
 */
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
        symbolColor: this.favorite ? $r('app.color.favorite') : $r('sys.color.font_secondary'),
        accessibilityLabel: this.favorite ? $r('app.string.remove_favorite') : $r('app.string.add_favorite'),
        clickable: this.clickable,
        // 收藏按钮嵌在整卡可点区域里，独占交互才能避免同时触发卡片点击。
        exclusive: true,
        onToggle: () => this.onToggle(!this.favorite),
      })
    }
  }
}
