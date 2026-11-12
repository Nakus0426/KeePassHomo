import { AnimationTokens } from '@ohos/common'
import { IconToggleButton } from './IconToggleButton'

// 收藏只换图标与主色，不换按钮形态；独占交互避免同时触发所在行点击。
@ComponentV2
export struct FavoriteToggle {
  @Param favorite: boolean = false
  @Param visible: boolean = true
  @Param clickable: boolean = true
  @Event onToggle: (next: boolean) => void = () => {
  }
  @Local private iconScale: number = 1

  private playBounce(): void {
    this.getUIContext().keyframeAnimateTo({
      expectedFrameRateRange: { min: 30, max: 120, expected: 60 },
    }, [
      {
        duration: AnimationTokens.DURATION_FAST,
        curve: AnimationTokens.EASE_STATE,
        event: () => {
          this.iconScale = AnimationTokens.FAVORITE_PRESS_SCALE
        },
      },
      {
        duration: AnimationTokens.DURATION_FAST,
        curve: AnimationTokens.EASE_ENTER,
        event: () => {
          this.iconScale = AnimationTokens.FAVORITE_BOUNCE_SCALE
        },
      },
      {
        duration: AnimationTokens.DURATION_FAST,
        curve: AnimationTokens.EASE_STATE,
        event: () => {
          this.iconScale = 1
        },
      },
    ])
  }

  build() {
    if (this.visible) {
      Row() {
        IconToggleButton({
          symbol: $r('app.string.symbol_star'),
          symbolChecked: $r('app.string.symbol_star_filled'),
          checked: this.favorite,
          symbolColor: $r('app.color.ds_text_tertiary'),
          symbolColorChecked: $r('app.color.ds_primary'),
          boxSize: $r('app.float.ds_button_height'),
          iconSizeOverride: $r('app.float.ds_entry_action_icon'),
          accessibilityLabel: this.favorite ? $r('app.string.remove_favorite') : $r('app.string.add_favorite'),
          clickable: this.clickable,
          exclusive: true,
          onToggle: () => {
            this.playBounce()
            this.onToggle(!this.favorite)
          },
        })
      }
      .scale({ x: this.iconScale, y: this.iconScale })
      // 独占触摸区阻断父条目点击与长按，避免收藏操作冒泡。
      .hitTestBehavior(HitTestMode.BLOCK_HIERARCHY)
    }
  }
}
