import { AnimationTokens } from '@ohos/common'
import { DsColorLadder } from './DsColorLadder'
import { DsControlSize } from './DsControlSize'

// 实心方块 + 几何勾，0 圆角；交互态由承载行传入，组件自身不抢占整行热区。
@ComponentV2
export struct DsCheckbox {
  @Param checked: boolean = false
  @Param disabled: boolean = false
  // 不能命名为 size：与 CustomComponent.size() 冲突。
  @Param checkboxSize: DsControlSize = DsControlSize.Medium
  @Param hovered: boolean = false
  @Param pressed: boolean = false

  @Computed
  private get controlSize(): Resource {
    switch (this.checkboxSize) {
      case DsControlSize.Small:
        return $r('app.float.ds_checkbox_size_sm')
      case DsControlSize.Large:
        return $r('app.float.ds_checkbox_size_lg')
      default:
        return $r('app.float.ds_checkbox_size_md')
    }
  }

  @Computed
  private get markSize(): Resource {
    switch (this.checkboxSize) {
      case DsControlSize.Small:
        return $r('app.float.ds_checkbox_mark_sm')
      case DsControlSize.Large:
        return $r('app.float.ds_checkbox_mark_lg')
      default:
        return $r('app.float.ds_checkbox_mark_md')
    }
  }

  @Computed
  private get active(): boolean {
    return !this.disabled && (this.hovered || this.pressed)
  }

  @Computed
  private get boxColor(): ResourceColor {
    if (this.disabled) {
      return this.checked ? $r('app.color.ds_outline_variant') : $r('app.color.ds_surface_high')
    }
    if (this.checked) {
      if (this.pressed) {
        return DsColorLadder.PRIMARY.press
      }
      return this.hovered ? DsColorLadder.PRIMARY.hover : DsColorLadder.PRIMARY.base
    }
    return this.hovered || this.pressed ? $r('app.color.ds_surface_highest') : $r('app.color.ds_surface_hover')
  }

  @Computed
  private get markColor(): ResourceColor {
    return this.disabled ? $r('app.color.ds_surface_canvas') : DsColorLadder.PRIMARY.onColor
  }

  @Computed
  private get ringColor(): ResourceColor {
    return this.pressed ? DsColorLadder.RING_MUTED : DsColorLadder.RING_SUBTLE
  }

  @Computed
  private get pressScale(): number {
    return this.pressed && !this.disabled ? 0.98 : 1
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 外描边不占布局；透明度承载 300ms 出现 / 消失。
      Column()
        .width(this.controlSize)
        .height(this.controlSize)
        .outline({
          width: $r('app.float.ds_checkbox_ring_width'),
          color: this.ringColor,
          radius: $r('app.float.ds_radius_none'),
        })
        .opacity(this.active ? 1 : 0)
        .animation(AnimationTokens.FEEDBACK_ANIMATION)

      Column()
        .width(this.controlSize)
        .height(this.controlSize)
        .backgroundColor(this.boxColor)
        .borderRadius($r('app.float.ds_radius_none'))
        .animation(AnimationTokens.FEEDBACK_ANIMATION)

      SymbolGlyph($r('app.string.symbol_check'))
        .fontSize(this.markSize)
        .fontColor([this.markColor])
        .foregroundColor(this.markColor)
        .opacity(this.checked ? 1 : 0)
        .scale({ x: this.checked ? 1 : 0.6, y: this.checked ? 1 : 0.6 })
        .animation(AnimationTokens.FEEDBACK_ANIMATION)
    }
    .width(this.controlSize)
    .height(this.controlSize)
    .scale({ x: this.pressScale, y: this.pressScale })
    .hitTestBehavior(HitTestMode.None)
    .animation(AnimationTokens.FEEDBACK_ANIMATION)
  }
}
