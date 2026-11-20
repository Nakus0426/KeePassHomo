import { AnimationTokens } from '@ohos/common'
import { DsControlSize } from './DsControlSize'


export enum DsInputTone {
  Default = 'default',
  Primary = 'primary',
  Success = 'success',
  Warning = 'warning',
  Error = 'error',
}

export enum DsInputVariant {
  Standard = 'standard',
  // 沉浸行内编辑：无边框、无底色、无内距，单行高度与行高一致，用于卡片内就地编辑。
  Inline = 'inline',
}

@ComponentV2
export struct DsInput {
  @Param text: string = ''
  @Param placeholder: ResourceStr = ''
  @Param type: InputType = InputType.Normal
  // -1 为不限制，与系统 TextInput 默认一致。
  @Param maxLength: number = -1
  @Param showPassword: boolean = false
  @Param inputSize: DsControlSize = DsControlSize.Medium
  @Param tone: DsInputTone = DsInputTone.Default
  @Param readOnly: boolean = false
  @Param disabled: boolean = false
  // 行内紧凑档：字段卡等密集场景覆盖字号、字重、字族与行高，不新增尺寸档位。
  @Param variant: DsInputVariant = DsInputVariant.Standard
  // 多行模式：占位与文本左上对齐，高度按最小行数撑开。
  @Param multiline: boolean = false
  @Param minLines: number = 3
  @Param fontSizeOverride: Resource | undefined = undefined
  @Param fontWeightOverride: FontWeight | number = FontWeight.Normal
  @Param fontFamilyOverride: string | undefined = undefined
  // 不大于 0 表示不限制行高，与系统输入框一致；行内变体用它决定单行高度与多行最小高度。
  @Param lineHeightOverride: number = 0
  // 获焦后全选文本：初始全选会在获焦前用平台默认高亮遮住文字，与 ds_selection 不一致。
  @Param selectAll: boolean = false
  // 就地编辑需要在挂载后立刻取焦，id 由调用方给，保证同页多实例不冲突。
  @Param focusKey: string = ''
  @Param autoFocus: boolean = false
  @Param enterKeyType: EnterKeyType | undefined = undefined
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
  private readonly controller: TextInputController = new TextInputController()

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
    if (this.disabled || this.variant === DsInputVariant.Inline) {
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
    if (this.variant === DsInputVariant.Inline) {
      return 0
    }
    if (this.canEdit && this.focused) {
      return $r('app.float.ds_border_width_focus')
    }
    return $r('app.float.ds_border_width')
  }

  // 行内变体全程不着色，聚焦只留光标；常规表单域始终是输入井底色。
  @Computed
  get fillColor(): ResourceColor {
    if (this.variant === DsInputVariant.Inline) {
      return Color.Transparent
    }
    return $r('app.color.ds_surface_inset')
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
    return this.disabled ? $r('app.color.ds_text_disabled') : $r('app.color.ds_text_secondary')
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
  get controlHeight(): Length {
    if (this.variant === DsInputVariant.Inline) {
      return this.lineHeightOverride
    }
    switch (this.inputSize) {
      case DsControlSize.Large:
        return $r('app.float.ds_input_height_lg')
      case DsControlSize.Small:
        return $r('app.float.ds_input_height_sm')
      default:
        return $r('app.float.ds_input_height_md')
    }
  }

  @Computed
  get horizontalPadding(): Length {
    if (this.variant === DsInputVariant.Inline) {
      return 0
    }
    switch (this.inputSize) {
      case DsControlSize.Large:
        return $r('app.float.ds_input_pad_x_lg')
      case DsControlSize.Small:
        return $r('app.float.ds_input_pad_x_sm')
      default:
        return $r('app.float.ds_input_pad_x_md')
    }
  }

  @Computed
  get inputFontSize(): Resource {
    if (this.fontSizeOverride !== undefined) {
      return this.fontSizeOverride
    }
    switch (this.inputSize) {
      case DsControlSize.Large:
        return $r('app.float.ds_input_font_size_lg')
      case DsControlSize.Small:
        return $r('app.float.ds_input_font_size_sm')
      default:
        return $r('app.float.ds_input_font_size_md')
    }
  }

  @Computed
  get contentGap(): Resource {
    switch (this.inputSize) {
      case DsControlSize.Large:
        return $r('app.float.ds_input_gap_lg')
      case DsControlSize.Small:
        return $r('app.float.ds_input_gap_sm')
      default:
        return $r('app.float.ds_input_gap_md')
    }
  }

  @Computed
  get verticalPadding(): Length {
    if (this.variant === DsInputVariant.Inline) {
      return 0
    }
    return this.multiline ? $r('app.float.ds_space_sm') : 0
  }

  // 行高按调用方覆盖值计算，否则调了行高最小高度会对不上。
  @Computed
  get textAreaMinHeight(): number {
    return (this.lineHeightOverride > 0 ? this.lineHeightOverride : 20) * this.minLines
  }

  private focusOnAppear(): void {
    if (this.autoFocus) {
      this.getUIContext().getFocusController().requestFocus(this.focusKey)
    }
  }

  private handleFocus(): void {
    this.focused = true
    if (this.selectAll && !this.multiline) {
      this.controller.setTextSelection(0, this.text.length)
    }
    this.onFocusChange(true)
  }

  private handleBlur(): void {
    this.focused = false
    this.onFocusChange(false)
  }

  @Builder
  private leadingSlot() {
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
  }

  @Builder
  private trailingSlot() {
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

  @Builder
  private singleLineInput() {
    Row({ space: this.contentGap }) {
      this.leadingSlot()

      TextInput({ placeholder: this.placeholder, text: this.text, controller: this.controller })
        .id(this.focusKey)
        .type(this.type)
        .maxLength(this.maxLength)
        .showPasswordIcon(false)
        .showPassword(this.showPassword)
        .height('100%')
        .padding(0)
        .borderRadius(0)
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .fontSize(this.inputFontSize)
        .fontWeight(this.fontWeightOverride)
        .fontFamily(this.fontFamilyOverride)
        .lineHeight(this.lineHeightOverride)
        .fontColor(this.valueColor)
        .placeholderFont({ size: this.inputFontSize })
        .placeholderColor(this.placeholderColor)
        .caretColor($r('app.color.ds_primary'))
        // 不指定时系统用默认蓝色，与设计系统的黑白主色不符。
        .selectedBackgroundColor($r('app.color.ds_selection'))
        .enterKeyType(this.enterKeyType ?? EnterKeyType.Done)
        .focusable(this.canEdit)
        .focusOnTouch(this.canEdit)
        .enabled(!this.disabled)
        .onAppear(() => this.focusOnAppear())
        .onFocus(() => this.handleFocus())
        .onBlur(() => this.handleBlur())
        .onChange((value: string) => this.onChange(value))
        .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => this.onSubmit(event.text))

      this.trailingSlot()
    }
    .height(this.controlHeight)
    .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
  }

  // 多行输入井：内距交给 TextArea 自己承担，外层不再加 padding，避免占位文字被容器裁切。
  @Builder
  private multilineInput() {
    Column() {
      TextArea({ placeholder: this.placeholder, text: this.text })
        .id(this.focusKey)
        .constraintSize({ minHeight: this.textAreaMinHeight })
        .width('100%')
        .padding({
          top: this.verticalPadding,
          bottom: this.verticalPadding,
          left: this.horizontalPadding,
          right: this.horizontalPadding,
        })
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .fontSize(this.inputFontSize)
        .fontWeight(this.fontWeightOverride)
        .fontFamily(this.fontFamilyOverride)
        .lineHeight(this.lineHeightOverride)
        .fontColor(this.valueColor)
        .placeholderFont({ size: this.inputFontSize })
        .placeholderColor(this.placeholderColor)
        .caretColor($r('app.color.ds_primary'))
        .selectedBackgroundColor($r('app.color.ds_selection'))
        .textAlign(TextAlign.Start)
        .enterKeyType(this.enterKeyType ?? EnterKeyType.NEW_LINE)
        .focusable(this.canEdit)
        .focusOnTouch(this.canEdit)
        .enabled(!this.disabled)
        .onAppear(() => this.focusOnAppear())
        .onFocus(() => this.handleFocus())
        .onBlur(() => this.handleBlur())
        .onChange((value: string) => this.onChange(value))
        .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => this.onSubmit(event.text))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      if (this.multiline) {
        this.multilineInput()
      } else {
        this.singleLineInput()
      }
    }
    .width('100%')
    .backgroundColor(this.fillColor)
    .border({
      width: this.inputBorderWidth,
      color: this.inputBorderColor,
    })
    .animation(AnimationTokens.FEEDBACK_ANIMATION)
  }
}
