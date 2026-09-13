import { IconToggleButton } from './IconToggleButton'

@ComponentV2
export struct PasswordVisibilityToggle {
  @Param visible: boolean = false
  @Event onChange: (visible: boolean) => void = () => {
  }

  build() {
    IconToggleButton({
      symbol: this.visible ? $r('sys.symbol.eye') : $r('sys.symbol.eye_slash'),
      accessibilityLabel: this.visible ? $r('app.string.hide') : $r('app.string.show'),
      onToggle: () => this.onChange(!this.visible),
    })
  }
}
