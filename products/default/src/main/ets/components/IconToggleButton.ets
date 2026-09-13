import { ResUtil } from '@pura/harmony-utils'
import { BounceAnimator } from '@ohos/common'

/**
 * 圆形图标开关按钮：点击时播放弹跳动画，在收缩点回调业务切换。
 * 尺寸由 app.float.control_height 推出，保证与表单控件同高。
 */
@ComponentV2
export struct IconToggleButton {
  @Param symbol: Resource = $r('sys.symbol.eye')
  @Param symbolColor: ResourceColor = $r('sys.color.font_secondary')
  @Require @Param accessibilityLabel: Resource
  @Param clickable: boolean = true
  @Event onToggle: () => void = () => {
  }
  private bounce: BounceAnimator = new BounceAnimator()

  @Computed
  private get buttonSize(): number {
    const buttonHeight: number = ResUtil.getNumber($r('app.float.control_height').id)
    const padding: number = ResUtil.getNumber($r('sys.float.padding_level4').id)
    return this.getUIContext().px2vp(buttonHeight - padding * 2)
  }

  @Computed
  private get pressedBackground(): ResourceColor {
    return this.clickable ? $r('sys.color.interactive_pressed') : Color.Transparent
  }

  private handleClick(): void {
    if (!this.clickable) {
      return
    }
    this.bounce.play(this.getUIContext(), () => this.onToggle())
  }

  build() {
    Button({ type: ButtonType.Circle, stateEffect: this.clickable }) {
      SymbolGlyph(this.symbol)
        .fontSize($r('sys.float.ohos_id_textfield_icon_size'))
        .fontColor([this.symbolColor])
        .scale({ x: this.bounce.scale, y: this.bounce.scale })
    }
    .width(this.buttonSize)
    .height(this.buttonSize)
    .backgroundColor(Color.Transparent)
    .stateStyles({
      pressed: {
        .backgroundColor(this.pressedBackground)
      },
    })
    .accessibilityText(this.accessibilityLabel)
    .onClick(() => this.handleClick())
  }
}
