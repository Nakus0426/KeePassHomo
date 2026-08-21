@ComponentV2
export struct PageTopBar {
  @Param title: Resource = $r('app.string.app_title')
  @Param showBack: boolean = false
  @Param showLock: boolean = false
  @Event onBack: () => void = () => {
  }
  @Event onLock: () => void = () => {
  }

  build() {
    Row({ space: 12 }) {
      if (this.showBack) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_backward'))
            .fontSize(22)
            .fontColor([$r('sys.color.brand')])
        }
        .width($r('app.float.control_height'))
        .height($r('app.float.control_height'))
        .backgroundColor(Color.Transparent)
        .onClick(() => this.onBack())
      }
      Text(this.title)
        .fontSize($r('app.float.text_heading'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
      if (this.showLock) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.lock_fill'))
            .fontSize(22)
            .fontColor([$r('sys.color.brand')])
        }
        .width($r('app.float.control_height'))
        .height($r('app.float.control_height'))
        .backgroundColor(Color.Transparent)
        .onClick(() => this.onLock())
      }
    }
    .width('100%')
    .height($r('app.float.control_height'))
  }
}

@ComponentV2
export struct StatusText {
  @Param status: string = ''

  build() {
    if (this.status.length > 0) {
      Text(this.status)
        .width('100%')
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.warning'))
    }
  }
}
