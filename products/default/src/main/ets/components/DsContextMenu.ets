@ComponentV2
export struct DsContextMenu {
  @BuilderParam header: () => void = this.empty
  @BuilderParam content: () => void = this.empty
  @BuilderParam footer: () => void = this.empty

  @Builder
  private empty() {
  }

  build() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      Column() {
        this.header()
      }
      .width('100%')

      Column({ space: $r('app.float.ds_space_sm') }) {
        this.content()
      }
      .width('100%')

      Column() {
        this.footer()
      }
      .width('100%')
    }
    .width($r('app.float.ds_context_menu_content_width'))
    .padding({ bottom: $r('app.float.ds_space_sm') })
    .backgroundColor($r('app.color.ds_surface_lowest'))
    .clip(true)
  }
}
