import { AnimationTokens } from '@ohos/common'

export enum DsInputTone {
  Default = 'default',
  Primary = 'primary',
  Success = 'success',
  Warning = 'warning',
  Error = 'error',
}

export enum DsInputSize {
  Large = 'large',
  Medium = 'medium',
  Small = 'small',
}

@ComponentV2
export struct DsInput {
  @Param text: string = ''
  @Param placeholder: ResourceStr = ''
  @Param type: InputType = InputType.Normal
  @Param showPassword: boolean = false
  @Param inputSize: DsInputSize = DsInputSize.Medium
  @Param tone: DsInputTone = DsInputTone.Default
  @Param readOnly: boolean = false
  @Param disabled: boolean = false
  @Param prefix: ResourceStr | undefined = undefined
  @Param suffix: ResourceStr | undefined = undefined
  @Event onChange: (value: string) => void = () => {
  }
  @Event onSubmit: (value: string) => void = () => {
  }
  @Event onFocusChange: (focused: boolean) => void = () => {
  }
  // 首尾插槽内容由调用方自绘，readOnly/disabled 下的置灰也由调用方负责。
  @BuilderParam leadingBuilder?: () => void
  @BuilderParam trailingBuilder?: () => void

  @Local private focused: boolean = false

  @Computed
  get toneColor(): ResourceColor {
    switch (this.tone) {
      case DsInputTone.Primary:
        return $r('app.color.ds_primary')
      case DsInputTone.Success:
        return $r('app.color.ds_success')
      case DsInputTone.Warning:
        return $r('app.color.ds_warning')
      case DsInputTone.Error:
        return $r('app.color.ds_error')
      default:
        return Color.Transparent
    }
  }

  @Computed
  get inputBorderColor(): ResourceColor {
    if (this.disabled) {
      return Color.Transparent
    }
    if (this.readOnly) {
      return $r('app.color.ds_outline_variant')
    }
    if (this.focused && this.tone === DsInputTone.Default) {
      return $r('app.color.ds_primary')
    }
    return this.toneColor
  }

  @Computed
  get inputBorderWidth(): Length {
    if (this.canEdit && this.focused) {
      return $r('app.float.ds_border_width_focus')
    }
    return $r('app.float.ds_border_width')
  }

  @Computed
  get fillColor(): ResourceColor {
    return this.disabled ? $r('app.color.ds_surface_high') : $r('app.color.ds_surface_low')
  }

  @Computed
  get valueColor(): ResourceColor {
    if (this.disabled) {
      return $r('app.color.ds_text_disabled')
    }
    if (this.readOnly) {
      return $r('app.color.ds_on_surface_variant')
    }
    return $r('app.color.ds_text_primary')
  }

  @Computed
  get placeholderColor(): ResourceColor {
    return this.disabled ? $r('app.color.ds_text_disabled') : $r('app.color.ds_text_tertiary')
  }

  @Computed
  get accessoryColor(): ResourceColor {
    return this.disabled ? $r('app.color.ds_text_disabled') : $r('app.color.ds_on_surface_variant')
  }

  @Computed
  get canEdit(): boolean {
    return !this.readOnly && !this.disabled
  }

  @Computed
  get controlHeight(): Resource {
    switch (this.inputSize) {
      case DsInputSize.Large:
        return $r('app.float.ds_input_height_lg')
      case DsInputSize.Small:
        return $r('app.float.ds_input_height_sm')
      default:
        return $r('app.float.ds_input_height_md')
    }
  }

  @Computed
  get horizontalPadding(): Resource {
    switch (this.inputSize) {
      case DsInputSize.Large:
        return $r('app.float.ds_input_pad_x_lg')
      case DsInputSize.Small:
        return $r('app.float.ds_input_pad_x_sm')
      default:
        return $r('app.float.ds_input_pad_x_md')
    }
  }

  @Computed
  get inputFontSize(): Resource {
    switch (this.inputSize) {
      case DsInputSize.Large:
        return $r('app.float.ds_input_font_size_lg')
      case DsInputSize.Small:
        return $r('app.float.ds_input_font_size_sm')
      default:
        return $r('app.float.ds_input_font_size_md')
    }
  }

  @Computed
  get contentGap(): Resource {
    switch (this.inputSize) {
      case DsInputSize.Large:
        return $r('app.float.ds_input_gap_lg')
      case DsInputSize.Small:
        return $r('app.float.ds_input_gap_sm')
      default:
        return $r('app.float.ds_input_gap_md')
    }
  }

  build() {
    Row({ space: this.contentGap }) {
      if (this.prefix !== undefined || this.leadingBuilder !== undefined) {
        Row({ space: $r('app.float.ds_space_xs') }) {
          if (this.prefix !== undefined) {
            Text(this.prefix)
              .fontSize(this.inputFontSize)
              .fontColor(this.accessoryColor)
              .flexShrink(0)
          }
          if (this.leadingBuilder !== undefined) {
            this.leadingBuilder()
          }
        }
        .height('100%')
        .flexShrink(0)
      }

      TextInput({ placeholder: this.placeholder, text: this.text })
        .type(this.type)
        .showPasswordIcon(false)
        .showPassword(this.showPassword)
        .height('100%')
        .padding(0)
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .fontSize(this.inputFontSize)
        .fontColor(this.valueColor)
        .placeholderFont({ size: this.inputFontSize })
        .placeholderColor(this.placeholderColor)
        .caretColor($r('app.color.ds_primary'))
        .focusable(this.canEdit)
        .focusOnTouch(this.canEdit)
        .enabled(!this.disabled)
        .onFocus(() => {
          this.focused = true
          this.onFocusChange(true)
        })
        .onBlur(() => {
          this.focused = false
          this.onFocusChange(false)
        })
        .onChange((value: string) => this.onChange(value))
        .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => this.onSubmit(event.text))

      if (this.suffix !== undefined || this.trailingBuilder !== undefined) {
        Row({ space: $r('app.float.ds_space_xs') }) {
          if (this.suffix !== undefined) {
            Text(this.suffix)
              .fontSize(this.inputFontSize)
              .fontColor(this.accessoryColor)
              .flexShrink(0)
          }
          if (this.trailingBuilder !== undefined) {
            this.trailingBuilder()
          }
        }
        .height('100%')
        .flexShrink(0)
      }
    }
    .width('100%')
    .height(this.controlHeight)
    .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
    .backgroundColor(this.fillColor)
    .border({
      width: this.inputBorderWidth,
      color: this.inputBorderColor,
    })
    .animation({
      duration: AnimationTokens.DURATION_FEEDBACK,
      curve: AnimationTokens.EASE_STATE,
    })
  }
}
