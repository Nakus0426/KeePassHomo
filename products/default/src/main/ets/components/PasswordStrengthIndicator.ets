import { PasswordStrengthCalculator, StrengthLevel } from '@ohos/common'

@ComponentV2
export struct PasswordStrengthIndicator {
  @Param password: string = ''
  @Local private level: StrengthLevel = StrengthLevel.Invalid

  aboutToAppear(): void {
    this.level = PasswordStrengthCalculator.calculate(this.password)
  }

  @Monitor('password')
  private onPasswordChanged(): void {
    this.level = PasswordStrengthCalculator.calculate(this.password)
  }

  private levelColor(): ResourceColor {
    if (this.level <= StrengthLevel.Weak) {
      return $r('sys.color.alert')
    }
    if (this.level === StrengthLevel.Medium) {
      return $r('sys.color.warning')
    }
    return $r('sys.color.confirm')
  }

  private levelLabel(): ResourceStr {
    switch (this.level) {
      case StrengthLevel.VeryWeak:
        return $r('app.string.password_strength_very_weak')
      case StrengthLevel.Weak:
        return $r('app.string.password_strength_weak')
      case StrengthLevel.Medium:
        return $r('app.string.password_strength_medium')
      case StrengthLevel.Strong:
        return $r('app.string.password_strength_strong')
      case StrengthLevel.VeryStrong:
        return $r('app.string.password_strength_very_strong')
      default:
        return ''
    }
  }

  build() {
    Row({ space: $r('sys.float.padding_level8') }) {
      Text($r('app.string.password_strength_label'))
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))

      Row({ space: $r('sys.float.padding_level4') }) {
        ForEach([0, 1, 2, 3, 4], (index: number) => {
          Rect()
            .height('14vp')
            .radius(7)
            .fill(index < this.level ? this.levelColor() : $r('sys.color.comp_background_secondary'))
            .layoutWeight(1)
        }, (index: number) => index.toString())
      }
      .layoutWeight(1)

      Stack() {
        Text($r('app.string.password_strength_very_weak'))
          .fontSize($r('sys.float.Body_M'))
          .opacity(0)
        Text(this.levelLabel())
          .fontSize($r('sys.float.Body_M'))
          .fontColor(this.levelColor())
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
