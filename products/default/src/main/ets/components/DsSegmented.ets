export interface DsSegmentItem {
  label: ResourceStr
  enabled: boolean
}

@ComponentV2
export struct DsSegmented {
  @Param items: DsSegmentItem[] = []
  @Param selectedIndex: number = 0
  @Event onSelect: (index: number) => void = () => {
  }

  build() {
    Row({ space: $r('app.float.ds_space_xs') }) {
      ForEach(this.items, (item: DsSegmentItem, index: number) => {
        Row() {
          Text(item.label)
            .fontSize($r('app.float.ds_font_body_sm'))
            .fontWeight(600)
            .fontColor(index === this.selectedIndex
              ? $r('app.color.ds_on_primary')
              : item.enabled ? $r('app.color.ds_text_secondary') : $r('app.color.ds_text_disabled'))
            .maxLines(1)
        }
        .layoutWeight(1)
        .height($r('app.float.ds_segment_height'))
        .justifyContent(FlexAlign.Center)
        .backgroundColor(index === this.selectedIndex ? $r('app.color.ds_primary') : Color.Transparent)
        .enabled(item.enabled)
        .onClick(() => this.onSelect(index))
      }, (item: DsSegmentItem, index: number) => `${index}_${item.enabled}`)
    }
    .width('100%')
    .padding($r('app.float.ds_space_xs'))
    .backgroundColor($r('app.color.ds_surface_low'))
  }
}
