@ComponentV2
export struct DsField {
  @Param label: ResourceStr = ''
  @Param required: boolean = false
  @Param error: ResourceStr | undefined = undefined
  @BuilderParam contentBuilder: () => void

  build() {
    Column({ space: $r('app.float.ds_space_xs') }) {
      Row({ space: $r('app.float.ds_space_xs') }) {
        Text(this.label)
          .fontSize($r('app.float.ds_font_body_sm'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_text_primary'))
        if (this.required) {
          Text($r('app.string.section_required_mark'))
            .fontSize($r('app.float.ds_font_body'))
            .fontWeight(600)
            .fontColor($r('app.color.ds_primary'))
        }
      }

      this.contentBuilder()

      if (this.error !== undefined) {
        Row({ space: $r('app.float.ds_space_xs') }) {
          SymbolGlyph($r('sys.symbol.exclamationmark_circle_fill'))
            .fontSize($r('app.float.ds_icon_tiny'))
            .fontColor([$r('app.color.ds_error')])
          Text(this.error)
            .fontSize($r('app.float.ds_font_body_sm'))
            .fontColor($r('app.color.ds_error'))
            .layoutWeight(1)
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
