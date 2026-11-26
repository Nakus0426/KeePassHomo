import { AnimationTokens, PasswordStrengthCalculator, StrengthLevel } from '@ohos/common'

@ComponentV2
export struct DsStrengthMeter {
  @Param password: string = ''
  @Local private level: StrengthLevel = StrengthLevel.Invalid

  aboutToAppear(): void {
    this.level = PasswordStrengthCalculator.calculate(this.password)
  }

  @Monitor('password')
  private onPasswordChanged(): void {
    this.level = PasswordStrengthCalculator.calculate(this.password)
  }

  @Computed
  get levelColor(): ResourceColor {
    if (this.level <= StrengthLevel.Weak) {
      return $r('app.color.ds_error')
    }
    if (this.level === StrengthLevel.Medium) {
      return $r('app.color.ds_warning')
    }
    return $r('app.color.ds_success')
  }

  build() {
    Row({ space: $r('app.float.ds_space_xs') }) {
      ForEach([0, 1, 2, 3, 4], (index: number) => {
        Row()
          .height($r('app.float.ds_meter_height'))
          .layoutWeight(1)
          .backgroundColor(index < this.level ? this.levelColor : $r('app.color.ds_surface_highest'))
          // 级联：逐段错开填充，颜色变化不整条闪。
          .animation({
            duration: AnimationTokens.DURATION_FEEDBACK,
            curve: AnimationTokens.EASE_STATE,
            delay: index * AnimationTokens.STRENGTH_CASCADE_DELAY,
          })
      }, (index: number) => index.toString())
    }
    .width('100%')
  }
}
