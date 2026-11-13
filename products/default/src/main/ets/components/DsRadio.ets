import { AnimationTokens } from '@ohos/common'
import { DsControlSize } from './DsControlSize'


@ComponentV2
export struct DsRadio {
  @Param checked: boolean = false
  @Param disabled: boolean = false
  // 不能命名为 size：与 CustomComponent.size() 冲突。
  @Param radioSize: DsControlSize = DsControlSize.Medium
  // 交互态由承载行传入，组件自身不抢占整行热区。
  @Param hovered: boolean = false
  @Param pressed: boolean = false

  @Computed
  private get controlSize(): Resource {
    switch (this.radioSize) {
      case DsControlSize.Small:
        return $r('app.float.ds_radio_size_sm')
      case DsControlSize.Large:
        return $r('app.float.ds_radio_size_lg')
      default:
        return $r('app.float.ds_radio_size_md')
    }
  }

  @Computed
  private get dotSize(): Resource {
    switch (this.radioSize) {
      case DsControlSize.Small:
        return $r('app.float.ds_radio_dot_sm')
      case DsControlSize.Large:
        return $r('app.float.ds_radio_dot_lg')
      default:
        return $r('app.float.ds_radio_dot_md')
    }
  }

  @Computed
  private get strokeWidth(): Resource {
    switch (this.radioSize) {
      case DsControlSize.Small:
        return $r('app.float.ds_radio_stroke_sm')
      case DsControlSize.Large:
        return $r('app.float.ds_radio_stroke_lg')
      default:
        return $r('app.float.ds_radio_stroke_md')
    }
  }

  @Computed
  private get ringColor(): ResourceColor {
    if (this.disabled) {
      return $r('app.color.ds_text_disabled')
    }
    if (this.checked || this.pressed) {
      return $r('app.color.ds_primary')
    }
    return this.hovered ? $r('app.color.ds_on_surface_variant') : $r('app.color.ds_outline')
  }

  @Computed
  private get dotColor(): ResourceColor {
    return this.disabled ? $r('app.color.ds_text_disabled') : $r('app.color.ds_primary')
  }

  build() {
    Stack() {
      Column()
        .width(this.controlSize)
        .height(this.controlSize)
        .border({ width: this.strokeWidth, color: this.ringColor })
        .borderRadius($r('app.float.ds_radius_none'))
        .animation(AnimationTokens.FEEDBACK_ANIMATION)
      Column()
        .width(this.dotSize)
        .height(this.dotSize)
        .backgroundColor(this.dotColor)
        .borderRadius($r('app.float.ds_radius_none'))
        .opacity(this.checked ? 1 : 0)
        .scale({ x: this.checked ? 1 : 0, y: this.checked ? 1 : 0 })
        .animation(AnimationTokens.FEEDBACK_ANIMATION)
    }
    .width(this.controlSize)
    .height(this.controlSize)
    .hitTestBehavior(HitTestMode.None)
  }
}
