export enum DsTagTone {
  Default = 'default',
  Primary = 'primary',
  Success = 'success',
  Warning = 'warning',
  Error = 'error',
}

export enum DsTagSize {
  Small = 'small',
  Medium = 'medium',
  Large = 'large',
}

interface TagPalette {
  container: ResourceColor
  content: ResourceColor
}

interface TagMetrics {
  fontSize: Resource
  padVertical: Resource
  padHorizontal: Resource
  gap: Resource
}

@ComponentV2
export struct DsTag {
  @Param tone: DsTagTone = DsTagTone.Default
  // 不能命名为 size：与 CustomComponent.size() 冲突。
  @Param tagSize: DsTagSize = DsTagSize.Medium
  @Param text: ResourceStr = ''
  // 自定义内容插槽：提供后替代 text，内容自带前景色。
  @BuilderParam contentBuilder?: () => void

  @Computed
  get palette(): TagPalette {
    switch (this.tone) {
      case DsTagTone.Primary:
        return { container: $r('app.color.ds_primary'), content: $r('app.color.ds_on_primary') }
      case DsTagTone.Success:
        return {
          container: $r('app.color.ds_success_container'),
          content: $r('app.color.ds_on_success_container'),
        }
      case DsTagTone.Warning:
        return {
          container: $r('app.color.ds_warning_container'),
          content: $r('app.color.ds_on_warning_container'),
        }
      case DsTagTone.Error:
        return { container: $r('app.color.ds_error_container'), content: $r('app.color.ds_on_error_container') }
      default:
        return { container: $r('app.color.ds_surface_high'), content: $r('app.color.ds_text_primary') }
    }
  }

  @Computed
  get metrics(): TagMetrics {
    switch (this.tagSize) {
      case DsTagSize.Large:
        return {
          fontSize: $r('app.float.ds_font_body'),
          padVertical: $r('app.float.ds_space_xs'),
          padHorizontal: $r('app.float.ds_space_10'),
          gap: $r('app.float.ds_space_6'),
        }
      case DsTagSize.Small:
        return {
          fontSize: $r('app.float.ds_font_label_sm'),
          padVertical: $r('app.float.ds_space_2'),
          padHorizontal: $r('app.float.ds_space_6'),
          gap: $r('app.float.ds_space_xs'),
        }
      default:
        return {
          fontSize: $r('app.float.ds_font_label_md'),
          padVertical: $r('app.float.ds_space_3'),
          padHorizontal: $r('app.float.ds_space_sm'),
          gap: $r('app.float.ds_space_xs'),
        }
    }
  }

  build() {
    Row({ space: this.metrics.gap }) {
      if (this.contentBuilder !== undefined) {
        this.contentBuilder()
      } else {
        Text(this.text)
          .fontSize(this.metrics.fontSize)
          .fontWeight(600)
          .letterSpacing($r('app.float.ds_tracking_wide_md'))
          .fontColor(this.palette.content)
          .maxLines(1)
      }
    }
    .padding({
      top: this.metrics.padVertical,
      bottom: this.metrics.padVertical,
      left: this.metrics.padHorizontal,
      right: this.metrics.padHorizontal,
    })
    .backgroundColor(this.palette.container)
    .borderRadius($r('app.float.ds_radius_none'))
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }
}
