import { ResUtil } from '@pura/harmony-utils'
import { BounceAnimator } from '@ohos/common'

const ICON_SIZE: number = 22

@ComponentV2
export struct PasswordVisibilityToggle {
  @Param visible: boolean = false
  @Event onChange: (visible: boolean) => void = () => {
  }
  private bounce: BounceAnimator = new BounceAnimator()

  private get buttonSize(): number {
    const buttonHeight: number = ResUtil.getNumber($r('app.float.control_height').id)
    const padding: number = ResUtil.getNumber($r('sys.float.padding_level4').id)
    return this.getUIContext().px2vp(buttonHeight - padding * 2)
  }

  private toggleVisibility(): void {
    const nextVisible: boolean = !this.visible
    this.bounce.play(this.getUIContext(), () => this.onChange(nextVisible))
  }

  build() {
    Button({ type: ButtonType.Circle, stateEffect: true }) {
      SymbolGlyph(this.visible ? $r('sys.symbol.eye') : $r('sys.symbol.eye_slash'))
        .fontSize($r('sys.float.ohos_id_textfield_icon_size'))
        .fontColor([$r('sys.color.font_secondary')])
        .scale({ x: this.bounce.scale, y: this.bounce.scale })
    }
    .width(this.buttonSize)
    .height(this.buttonSize)
    .backgroundColor(Color.Transparent)
    .stateStyles({
      pressed: {
        .backgroundColor($r('sys.color.interactive_pressed'))
      },
    })
    .accessibilityText(this.visible ? $r('app.string.hide') : $r('app.string.show'))
    .onClick(() => this.toggleVisibility())
  }
}
