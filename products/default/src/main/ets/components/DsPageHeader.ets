@ComponentV2
export struct DsPageHeader {
  @Param title: ResourceStr = ''
  @Param subtitle: ResourceStr | undefined = undefined
  @Param showBack: boolean = true
  @Param showMore: boolean = true
  @Event onBack: () => void = () => {
  }
  @Event onMore: () => void = () => {
  }

  build() {
    Row({ space: $r('app.float.ds_space_md') }) {
      if (this.showBack) {
        Row() {
          SymbolGlyph($r('sys.symbol.arrow_left'))
            .fontSize($r('app.float.ds_icon_md'))
            .fontColor([$r('app.color.ds_text_primary')])
        }
        .width($r('app.float.ds_button_height'))
        .height($r('app.float.ds_button_height'))
        .justifyContent(FlexAlign.Center)
        .onClick(() => this.onBack())
      }

      Column({ space: 3 }) {
        Text(this.title)
          .fontSize($r('app.float.ds_font_display'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_text_primary'))
          .maxLines(1)
        if (this.subtitle !== undefined) {
          Text(this.subtitle)
            .fontSize($r('app.float.ds_font_label_sm'))
            .fontWeight(600)
            .fontColor($r('app.color.ds_text_tertiary'))
            .maxLines(1)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (this.showMore) {
        Row() {
          SymbolGlyph($r('sys.symbol.more'))
            .fontSize($r('app.float.ds_icon_md'))
            .fontColor([$r('app.color.ds_text_primary')])
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .onClick(() => this.onMore())
      }
    }
    .width('100%')
    .height($r('app.float.ds_header_height'))
    .padding({
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
      top: $r('app.float.ds_space_md'),
      bottom: $r('app.float.ds_space_md'),
    })
    .alignItems(VerticalAlign.Center)
  }
}
