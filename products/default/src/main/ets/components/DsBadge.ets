import { AnimationTokens } from '@ohos/common'

export enum DsBadgeSize {
  Small,
  Medium,
  Large,
}

// 出现 0.6→1，消失 1→0.4，均带淡入淡出；数字变化只换文本，不重播。
const BADGE_APPEAR: TransitionEffect = TransitionEffect.OPACITY
  .combine(TransitionEffect.scale({ x: 0.6, y: 0.6 }))
  .animation(AnimationTokens.FEEDBACK_ANIMATION)
const BADGE_DISAPPEAR: TransitionEffect = TransitionEffect.OPACITY
  .combine(TransitionEffect.scale({ x: 0.4, y: 0.4 }))
  .animation(AnimationTokens.FEEDBACK_ANIMATION)

// 状态徽标：0 画方点，大于 0 画数字（超过 9 显示 9+）。组件不带定位，挂载由宿主负责。
@ComponentV2
export struct DsBadge {
  @Param badgeSize: DsBadgeSize = DsBadgeSize.Medium
  @Param value: number = 0

  @Computed
  get dotSize(): Resource {
    switch (this.badgeSize) {
      case DsBadgeSize.Small:
        return $r('app.float.ds_badge_dot_sm')
      case DsBadgeSize.Large:
        return $r('app.float.ds_badge_dot_lg')
      default:
        return $r('app.float.ds_badge_dot_md')
    }
  }

  @Computed
  get boxSize(): Resource {
    switch (this.badgeSize) {
      case DsBadgeSize.Small:
        return $r('app.float.ds_badge_box_sm')
      case DsBadgeSize.Large:
        return $r('app.float.ds_badge_box_lg')
      default:
        return $r('app.float.ds_badge_box_md')
    }
  }

  @Computed
  get fontSize(): Resource {
    return this.badgeSize === DsBadgeSize.Large
      ? $r('app.float.ds_badge_font_lg') : $r('app.float.ds_badge_font_sm')
  }

  @Computed
  get isDot(): boolean {
    return this.value <= 0
  }

  build() {
    Row() {
      if (this.value > 0) {
        Text(this.value > 9 ? '9+' : String(this.value))
          .fontSize(this.fontSize)
          .fontWeight(600)
          .fontColor($r('app.color.ds_on_primary'))
          .maxLines(1)
      }
    }
    .width(this.isDot ? this.dotSize : this.boxSize)
    .height(this.isDot ? this.dotSize : this.boxSize)
    .constraintSize({ minWidth: this.isDot ? this.dotSize : this.boxSize })
    .padding({
      left: this.isDot ? 0 : $r('app.float.ds_space_2'),
      right: this.isDot ? 0 : $r('app.float.ds_space_2'),
    })
    .backgroundColor($r('app.color.ds_primary'))
    .borderRadius($r('app.float.ds_radius_none'))
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .transition(TransitionEffect.asymmetric(BADGE_APPEAR, BADGE_DISAPPEAR))
  }
}
