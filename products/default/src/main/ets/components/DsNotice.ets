const NOTICE_BODY_LINE_HEIGHT: number = 18

export enum DsNoticeTone {
  Default = 'default',
  Success = 'success',
  Warning = 'warning',
  Error = 'error',
}

@ComponentV2
export struct DsNotice {
  // 设计稿默认 error：解锁失败与文件错误卡都用它，中性说明才显式传 Default。
  @Param tone: DsNoticeTone = DsNoticeTone.Error
  @Param title: ResourceStr = ''
  @Param body: ResourceStr = ''
  // 标题插槽整体替换标题行（图标 + 文字）；不再单独提供图标覆盖。
  @BuilderParam titleBuilder?: () => void
  @BuilderParam bodyBuilder?: () => void

  @Computed
  get hasTitleRow(): boolean {
    if (this.titleBuilder !== undefined) {
      return true
    }
    return typeof this.title === 'string' ? this.title.length > 0 : true
  }

  @Computed
  get hasBody(): boolean {
    if (this.bodyBuilder !== undefined) {
      return true
    }
    return typeof this.body === 'string' ? this.body.length > 0 : true
  }

  @Computed
  get containerColor(): ResourceColor {
    switch (this.tone) {
      case DsNoticeTone.Success:
        return $r('app.color.ds_success_container')
      case DsNoticeTone.Warning:
        return $r('app.color.ds_warning_container')
      case DsNoticeTone.Default:
        return $r('app.color.ds_surface_high')
      default:
        return $r('app.color.ds_error_container')
    }
  }

  @Computed
  get iconColor(): ResourceColor {
    switch (this.tone) {
      case DsNoticeTone.Success:
        return $r('app.color.ds_success')
      case DsNoticeTone.Warning:
        return $r('app.color.ds_warning')
      case DsNoticeTone.Default:
        return $r('app.color.ds_text_primary')
      default:
        return $r('app.color.ds_error')
    }
  }

  @Computed
  get titleColor(): ResourceColor {
    switch (this.tone) {
      case DsNoticeTone.Success:
        return $r('app.color.ds_on_success_container')
      case DsNoticeTone.Warning:
        return $r('app.color.ds_on_warning_container')
      case DsNoticeTone.Default:
        return $r('app.color.ds_text_primary')
      default:
        return $r('app.color.ds_on_error_container')
    }
  }

  @Computed
  get bodyColor(): ResourceColor {
    switch (this.tone) {
      case DsNoticeTone.Default:
        return $r('app.color.ds_on_surface_variant')
      default:
        return this.titleColor
    }
  }

  @Computed
  get icon(): Resource {
    switch (this.tone) {
      case DsNoticeTone.Success:
        return $r('app.string.symbol_check_circle')
      case DsNoticeTone.Warning:
        return $r('app.string.symbol_warning')
      case DsNoticeTone.Error:
        return $r('app.string.symbol_error')
      default:
        return $r('app.string.symbol_info')
    }
  }

  @Builder
  private defaultTitle() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      SymbolGlyph(this.icon)
        .fontSize($r('app.float.ds_icon_xs'))
        .fontColor([this.iconColor])
        .foregroundColor(this.iconColor)
      Text(this.title)
        .fontSize($r('app.float.ds_font_body'))
        .fontWeight(600)
        .fontColor(this.titleColor)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private defaultBody() {
    Text(this.body)
      .width('100%')
      .fontSize($r('app.float.ds_font_body_sm'))
      .lineHeight($r('app.float.ds_font_body_sm'))
      .fontColor(this.bodyColor)
  }

  build() {
    Column({ space: $r('app.float.ds_space_6') }) {
      if (this.hasTitleRow) {
        if (this.titleBuilder !== undefined) {
          this.titleBuilder()
        } else {
          this.defaultTitle()
        }
      }
      if (this.bodyBuilder !== undefined) {
        this.bodyBuilder()
      } else if (this.hasBody) {
        this.defaultBody()
      }
    }
    .width('100%')
    .padding($r('app.float.ds_space_16'))
    .backgroundColor(this.containerColor)
    .borderRadius($r('app.float.ds_radius_none'))
    .alignItems(HorizontalAlign.Start)
    .accessibilityGroup(true)
  }
}
