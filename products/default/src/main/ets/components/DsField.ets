const FIELD_LABEL_LETTER_SPACING: number = 0.6
const FIELD_FEEDBACK_LINE_HEIGHT: number = 17

export enum DsFieldTone {
  Default = 'default',
  Primary = 'primary',
  Success = 'success',
  Warning = 'warning',
  Error = 'error',
}

@ComponentV2
export struct DsField {
  @Param label: ResourceStr = ''
  @Param required: boolean = false
  @Param feedback: ResourceStr | undefined = undefined
  // 设计稿默认 error；Default 是中性反馈色。
  @Param tone: DsFieldTone = DsFieldTone.Error
  // 预留一行反馈高度，避免校验消息出现时把下方内容顶下去。
  @Param reserveFeedbackSpace: boolean = false
  @BuilderParam labelBuilder?: () => void
  @BuilderParam contentBuilder: () => void
  @BuilderParam feedbackBuilder?: () => void

  @Computed
  get hasLabel(): boolean {
    if (this.labelBuilder !== undefined) {
      return true
    }
    return typeof this.label === 'string' ? this.label.length > 0 : true
  }

  @Computed
  get hasFeedbackText(): boolean {
    if (this.feedback === undefined) {
      return false
    }
    return typeof this.feedback === 'string' ? this.feedback.length > 0 : true
  }

  @Computed
  get hasFeedbackRow(): boolean {
    return this.feedbackBuilder !== undefined || this.hasFeedbackText || this.reserveFeedbackSpace
  }

  @Computed
  get feedbackText(): ResourceStr {
    return this.feedback ?? ''
  }

  @Computed
  get toneColor(): ResourceColor {
    switch (this.tone) {
      case DsFieldTone.Primary:
        return $r('app.color.ds_primary')
      case DsFieldTone.Success:
        return $r('app.color.ds_success')
      case DsFieldTone.Warning:
        return $r('app.color.ds_warning')
      case DsFieldTone.Default:
        return $r('app.color.ds_on_surface_variant')
      default:
        return $r('app.color.ds_error')
    }
  }

  @Computed
  get feedbackIcon(): Resource {
    switch (this.tone) {
      case DsFieldTone.Success:
        return $r('app.string.symbol_check_circle')
      case DsFieldTone.Warning:
        return $r('app.string.symbol_warning')
      case DsFieldTone.Primary:
        return $r('app.string.symbol_info')
      case DsFieldTone.Default:
        return $r('app.string.symbol_info')
      default:
        return $r('app.string.symbol_error')
    }
  }

  @Builder
  private defaultLabel() {
    Row({ space: $r('app.float.ds_space_2') }) {
      Text(this.label)
        .fontSize($r('app.float.ds_font_label_md'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))
        .letterSpacing(FIELD_LABEL_LETTER_SPACING)
      if (this.required) {
        Text($r('app.string.section_required_mark'))
          .fontSize($r('app.float.ds_font_body'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_error'))
      }
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private defaultFeedback() {
    Row({ space: $r('app.float.ds_space_xs') }) {
      if (this.hasFeedbackText) {
        Row() {
          SymbolGlyph(this.feedbackIcon)
            .fontSize($r('app.float.ds_icon_tiny'))
            .fontColor([this.toneColor])
            .foregroundColor(this.toneColor)
        }
        .padding({ top: $r('app.float.ds_space_2') })
        .flexShrink(0)
      }
      if (this.hasFeedbackText) {
        Text(this.feedbackText)
          .fontSize($r('app.float.ds_font_body_sm'))
          .fontColor(this.toneColor)
          .lineHeight(FIELD_FEEDBACK_LINE_HEIGHT)
          .layoutWeight(1)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: FIELD_FEEDBACK_LINE_HEIGHT })
    .alignItems(VerticalAlign.Top)
  }

  build() {
    Column({ space: $r('app.float.ds_space_xs') }) {
      if (this.hasLabel) {
        Row() {
          if (this.labelBuilder !== undefined) {
            this.labelBuilder()
          } else {
            this.defaultLabel()
          }
        }
        .width('100%')
        .padding({ bottom: $r('app.float.ds_space_xs') })
        .alignItems(VerticalAlign.Center)
      }

      Row() {
        this.contentBuilder()
      }
      .width('100%')

      if (this.hasFeedbackRow) {
        if (this.feedbackBuilder !== undefined) {
          this.feedbackBuilder()
        } else {
          this.defaultFeedback()
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
