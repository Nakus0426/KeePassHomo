import { AnimationTokens } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { PASSWORD_FONT_FAMILY } from '../constants/FontConstants'

export enum DsNumberStepperSize {
  Small = 'small',
  Medium = 'medium',
  Large = 'large',
}

interface StepperMetrics {
  height: number
  button: number
  valueWidth: number
  icon: number
  fontSize: number
}

// 几何取自 pen 数字输入组件：四边 4vp 内边距，按钮=条高−8；宽度合计 sm 100 / md 128 / lg 156。
const INSET: number = 4
const SMALL: StepperMetrics = { height: 28, button: 20, valueWidth: 52, icon: 14, fontSize: 11 }
const MEDIUM: StepperMetrics = { height: 36, button: 28, valueWidth: 64, icon: 16, fontSize: 12 }
const LARGE: StepperMetrics = { height: 44, button: 36, valueWidth: 76, icon: 18, fontSize: 13 }
const TOUCH_TARGET: number = 40

@ComponentV2
export struct DsNumberStepper {
  @Param value: number = 0
  @Param min: number = 0
  @Param max: number = 100
  @Param step: number = 1
  @Param stepperSize: DsNumberStepperSize = DsNumberStepperSize.Small
  @Param disabled: boolean = false
  @Event onChange: (value: number) => void = () => {
  }

  @Local private minusHovered: boolean = false
  @Local private minusPressed: boolean = false
  @Local private plusHovered: boolean = false
  @Local private plusPressed: boolean = false

  @Computed
  get metrics(): StepperMetrics {
    if (this.stepperSize === DsNumberStepperSize.Medium) {
      return MEDIUM
    }
    return this.stepperSize === DsNumberStepperSize.Large ? LARGE : SMALL
  }

  @Computed
  get canDecrease(): boolean {
    return !this.disabled && this.value > this.min
  }

  @Computed
  get canIncrease(): boolean {
    return !this.disabled && this.value < this.max
  }

  private isEnabled(increase: boolean): boolean {
    return increase ? this.canIncrease : this.canDecrease
  }

  private hovered(increase: boolean): boolean {
    return increase ? this.plusHovered : this.minusHovered
  }

  private pressed(increase: boolean): boolean {
    return increase ? this.plusPressed : this.minusPressed
  }

  private setHovered(increase: boolean, value: boolean): void {
    if (increase) {
      this.plusHovered = value
    } else {
      this.minusHovered = value
    }
  }

  private setPressed(increase: boolean, value: boolean): void {
    if (increase) {
      this.plusPressed = value
    } else {
      this.minusPressed = value
    }
  }

  private glyphColor(enabled: boolean): ResourceColor {
    return enabled ? $r('app.color.ds_text_primary') : $r('app.color.ds_text_disabled')
  }

  private buttonBackground(enabled: boolean, hovered: boolean, pressed: boolean): ResourceColor {
    if (!enabled) {
      return Color.Transparent
    }
    if (pressed) {
      return $r('app.color.ds_overlay_muted')
    }
    return hovered ? $r('app.color.ds_overlay_subtle') : Color.Transparent
  }

  // 按钮视觉仅 20vp，用 responseRegion 把可点区域补到 40vp，避免缩小布局宽度。
  private touchRegion(): Rectangle {
    const offset: number = (this.metrics.button - TOUCH_TARGET) / 2
    return { x: offset, y: offset, width: TOUCH_TARGET, height: TOUCH_TARGET }
  }

  private change(increase: boolean): void {
    if (!this.isEnabled(increase)) {
      return
    }
    if (increase) {
      this.onChange(Math.min(this.max, this.value + this.step))
      return
    }
    this.onChange(Math.max(this.min, this.value - this.step))
  }

  @Builder
  private stepButton(increase: boolean) {
    Row() {
      SymbolGlyph(increase ? $r('app.string.symbol_add') : $r('app.string.symbol_remove'))
        .fontSize(this.metrics.icon)
        .fontColor([this.glyphColor(this.isEnabled(increase))])
        .foregroundColor(this.glyphColor(this.isEnabled(increase)))
        .animation({
          duration: AnimationTokens.DURATION_FEEDBACK,
          curve: AnimationTokens.EASE_STATE,
        })
    }
    .width(this.metrics.button)
    .height(this.metrics.button)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.buttonBackground(this.isEnabled(increase), this.hovered(increase), this.pressed(increase)))
    .borderRadius($r('app.float.ds_radius_none'))
    .responseRegion(this.touchRegion())
    .accessibilityText(ResUtil.getStringSync(
      increase ? $r('app.string.number_stepper_increase') : $r('app.string.number_stepper_decrease')))
    .animation({
      duration: AnimationTokens.DURATION_FEEDBACK,
      curve: AnimationTokens.EASE_STATE,
    })
    .enabled(this.isEnabled(increase))
    .onHover((isHover: boolean) => {
      if (this.isEnabled(increase)) {
        this.setHovered(increase, isHover)
      }
    })
    .onTouch((event: TouchEvent) => {
      if (!this.isEnabled(increase)) {
        return
      }
      if (event.type === TouchType.Down) {
        this.setPressed(increase, true)
        return
      }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.setPressed(increase, false)
      }
    })
    .onClick(() => {
      this.setPressed(increase, false)
      this.change(increase)
    })
  }

  build() {
    Row() {
      this.stepButton(false)

      Text(`${this.value}`)
        .width(this.metrics.valueWidth)
        .height(this.metrics.button)
        .textAlign(TextAlign.Center)
        .fontSize(this.metrics.fontSize)
        .fontWeight(600)
        .fontColor(this.disabled ? $r('app.color.ds_text_disabled') : $r('app.color.ds_text_primary'))
        .fontFamily(PASSWORD_FONT_FAMILY)
        .animation({
          duration: AnimationTokens.DURATION_FEEDBACK,
          curve: AnimationTokens.EASE_STATE,
        })

      this.stepButton(true)
    }
    .padding(INSET)
    .height(this.metrics.height)
    .backgroundColor(this.disabled ? $r('app.color.ds_surface_inset') : $r('app.color.ds_surface_low'))
    .borderRadius($r('app.float.ds_radius_none'))
    .alignItems(VerticalAlign.Center)
    .enabled(!this.disabled)
    .animation({
      duration: AnimationTokens.DURATION_FEEDBACK,
      curve: AnimationTokens.EASE_STATE,
    })
  }
}
