@ComponentV2
export struct Cell {
  @Param label: ResourceStr | undefined = undefined
  @Param value: ResourceStr | undefined = undefined
  @Param clickable: boolean = true
  @Param showArrow: boolean | undefined = undefined
  @Event onCellClick: () => void = () => {
  }
  @BuilderParam labelBuilder?: () => void
  @BuilderParam valueBuilder?: () => void

  @Computed
  get arrowVisible() {
    return this.showArrow ?? this.clickable
  }

  build() {
    ListItem() {
      Row({ space: $r('sys.float.padding_level8') }) {
        Row() {
          if (this.label !== undefined) {
            Text(this.label)
              .fontColor($r('sys.color.font_secondary'))
              .fontSize($r('sys.float.Body_M'))
              .textAlign(TextAlign.Start)
          } else if (this.labelBuilder !== undefined) {
            this.labelBuilder()
          }
        }
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)

        Row({ space: $r('sys.float.padding_level4') }) {
          if (this.value !== undefined) {
            Text(this.value)
              .fontColor($r('sys.color.font_primary'))
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .textAlign(TextAlign.End)
          } else if (this.valueBuilder !== undefined) {
            this.valueBuilder()
          }
          if (this.arrowVisible) {
            SymbolGlyph($r('sys.symbol.chevron_forward'))
              .fontSize($r('sys.float.Title_S'))
              .fontColor([$r('sys.color.font_secondary')])
              .fontWeight(FontWeight.Medium)
          }
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)
      }
      .padding($r('sys.float.padding_level6'))
      .margin($r('sys.float.padding_level2'))
      .alignItems(VerticalAlign.Center)
      .stateStyles({
        normal: {
          .backgroundColor(Color.Transparent)
        },
        pressed: {
          .backgroundColor(this.clickable ? $r('sys.color.interactive_pressed') : Color.Transparent)
        },
      })
      .borderRadius($r('sys.float.corner_radius_level8'))
      .onClick(() => {
        if (!this.clickable) {
          return
        }
        this.onCellClick()
      })
    }
    .width('100%')
    .backgroundColor(Color.Transparent)
  }
}
