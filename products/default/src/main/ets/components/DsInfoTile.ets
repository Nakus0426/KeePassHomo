import { PASSWORD_FONT_FAMILY } from '../constants/FontConstants'

// 设计稿 Tile 固定高 68vp（无对应 pen 变量）；内容高度推导不出该值，用常量保证两栏等高。
const TILE_HEIGHT: number = 68

// 指标卡：图标+标签在上、值在下；值可为普通/等宽文本，或经 valueBuilder 放自定义内容（如状态标签）。
@ComponentV2
export struct DsInfoTile {
  @Require @Param icon: Resource
  @Param label: ResourceStr = ''
  @Param value: ResourceStr = ''
  @Param monospace: boolean = false
  @BuilderParam valueBuilder?: () => void

  @Builder
  private labelRow() {
    Row({ space: $r('app.float.ds_space_6') }) {
      SymbolGlyph(this.icon)
        .fontSize($r('app.float.ds_icon_tiny'))
        .fontColor([$r('app.color.ds_text_tertiary')])
        .foregroundColor($r('app.color.ds_text_tertiary'))
      Text(this.label)
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontColor($r('app.color.ds_text_tertiary'))
        .letterSpacing($r('app.float.ds_tracking_wide_xs'))
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private valueText() {
    if (this.monospace) {
      Text(this.value)
        .width('100%')
        .fontSize($r('app.float.ds_font_body'))
        .fontWeight(600)
        .fontFamily(PASSWORD_FONT_FAMILY)
        .letterSpacing($r('app.float.ds_tracking_wide_xs'))
        .fontColor($r('app.color.ds_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    } else {
      Text(this.value)
        .width('100%')
        .fontSize($r('app.float.ds_font_body'))
        .fontWeight(600)
        .letterSpacing($r('app.float.ds_tracking_tight'))
        .fontColor($r('app.color.ds_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  build() {
    Column() {
      this.labelRow()
      if (this.valueBuilder !== undefined) {
        this.valueBuilder()
      } else {
        this.valueText()
      }
    }
    .layoutWeight(1)
    .height(TILE_HEIGHT)
    .padding($r('app.float.ds_space_md'))
    .backgroundColor($r('app.color.ds_surface_low'))
    .borderRadius($r('app.float.ds_radius_none'))
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Start)
  }
}
