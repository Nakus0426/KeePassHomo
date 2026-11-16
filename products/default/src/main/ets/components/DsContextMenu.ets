@ComponentV2
export struct DsContextMenu {
  @BuilderParam header: () => void = this.empty
  @BuilderParam content: () => void = this.empty
  @BuilderParam footer: () => void = this.empty

  @Builder
  private empty() {
  }

  build() {
    // 空 Footer 与列间距已留出末项下边距；再叠加 padding 会与分隔线后的上边距不一致。
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
    .backgroundColor($r('app.color.ds_surface_lowest'))
    .clip(true)
  }
}
