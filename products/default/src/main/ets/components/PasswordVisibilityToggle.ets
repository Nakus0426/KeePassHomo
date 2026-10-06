import { IconToggleButton } from './IconToggleButton'

@ComponentV2
export struct PasswordVisibilityToggle {
  @Param visible: boolean = false
  /** 嵌入整行可点区域时置 true，避免同时触发外层点击。 */
  @Param exclusive: boolean = false
  @Event onChange: (visible: boolean) => void = () => {
  }

  build() {
    IconToggleButton({
      symbol: this.visible ? $r('sys.symbol.eye') : $r('sys.symbol.eye_slash'),
      accessibilityLabel: this.visible ? $r('app.string.hide') : $r('app.string.show'),
      exclusive: this.exclusive,
      onToggle: () => this.onChange(!this.visible),
    })
  }
}
