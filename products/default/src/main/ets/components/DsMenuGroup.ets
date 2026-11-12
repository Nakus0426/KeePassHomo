@ComponentV2
export struct DsMenuGroup {
  @Param dividerTop: boolean = false
  @BuilderParam content: () => void = this.empty

  @Builder
  private empty() {
  }

  build() {
    Column() {
      if (this.dividerTop) {
        Divider()
          .width('100%')
          .strokeWidth(1)
          .color($r('app.color.ds_outline_variant'))
          .margin({ bottom: $r('app.float.ds_space_sm') })
      }
      Column() {
        this.content()
      }
      .width('100%')
    }
    .width('100%')
  }
}
