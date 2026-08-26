@ComponentV2
export struct Cell {
  @Param label: ResourceStr | undefined = undefined
  @Param value: ResourceStr | undefined = undefined
  @Param clickable: boolean = true
  @Param showArrow: boolean | undefined = undefined
  @Event onCellClick: () => void = () => {
  }

  @Computed
  get arrowVisible(): boolean {
    return this.showArrow ?? this.clickable
  }

  @Builder
  private emptyBuilder() {
  }

  @BuilderParam labelBuilder: () => void = this.emptyBuilder
  @BuilderParam valueBuilder: () => void = this.emptyBuilder

  build() {
    ListItem() {
      Row() {
        Row() {
          if (this.label !== undefined) {
            Text(this.label)
              .fontColor($r('sys.color.font_secondary'))
              .fontSize($r('sys.float.Body_M'))
              .textAlign(TextAlign.Start)
          } else {
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
          } else {
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
      .width('100%')
      .padding({
        top: $r('sys.float.padding_level8'),
        bottom: $r('sys.float.padding_level8'),
      })
      .alignItems(VerticalAlign.Center)
      .stateStyles({
        normal: {
          .backgroundColor(Color.Transparent)
        },
        pressed: {
          .backgroundColor(this.clickable ? $r('sys.color.interactive_pressed') : Color.Transparent)
        },
      })
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
