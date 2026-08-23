@ComponentV2
export struct DescriptionItem {
  @Param label: ResourceStr | undefined = undefined
  @Param value: ResourceStr | undefined = undefined

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

        Row() {
          if (this.value !== undefined) {
            Text(this.value)
              .fontColor($r('sys.color.font_primary'))
              .fontSize($r('sys.float.Body_M'))
              .fontWeight(FontWeight.Medium)
              .textAlign(TextAlign.End)
          } else {
            this.valueBuilder()
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
      .backgroundColor(Color.Transparent)
    }
    .width('100%')
    .backgroundColor(Color.Transparent)
  }
}
