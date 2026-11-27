import { AnimationTokens } from '@ohos/common'
import { DsButton, DsButtonTone, DsButtonVariant } from './DsButton'
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
  // 尾部清除按钮：常驻占位，仅在有值时可见，可编辑状态由调用方通过该开关控制。
  @Param clearable: boolean = false
  @Param clearLabel: Resource = $r('app.string.close')
  @Event onClear: () => void = () => {
  }
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

  // 描边走 outline：不参与布局，宽度的出现与消失不会顶开周围内容。
  @Computed
  get inputBorderWidth(): Dimension {
    if (this.variant === DsInputVariant.Inline || this.disabled) {
      return 0
    }
    if (this.readOnly || this.focused || this.tone !== DsInputTone.Default) {
      return $r('app.float.ds_border_width')
    }
    return 0
  }

  // 常态是内陷井底，聚焦换成画布底色；错误态保持井底。
  @Computed
  get fillColor(): ResourceColor {
    if (this.variant === DsInputVariant.Inline) {
      return Color.Transparent
    }
    if (this.focused) {
      return $r('app.color.ds_surface_canvas')
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
  get hasClearValue(): boolean {
    return this.text.length > 0
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

  // 始终占住 32 的宽度：显隐只淡入淡出并缩放，输入文本不会随按钮出现而重排。
  @Builder
  private clearSlot() {
    Stack() {
      DsButton({
        variant: DsButtonVariant.Text,
        tone: DsButtonTone.Default,
        buttonSize: DsControlSize.Small,
        iconOnly: true,
        leadingIcon: $r('app.string.symbol_close'),
        iconColorOverride: $r('app.color.ds_text_secondary'),
        accessibilityLabelResource: this.clearLabel,
        onTap: () => this.onClear(),
      })
    }
    .width($r('app.float.ds_button_small_height'))
    .height($r('app.float.ds_button_small_height'))
    .opacity(this.hasClearValue ? 1 : 0)
    .scale({
      x: this.hasClearValue ? 1 : AnimationTokens.INPUT_CLEAR_SCALE,
      y: this.hasClearValue ? 1 : AnimationTokens.INPUT_CLEAR_SCALE,
    })
    .animation(AnimationTokens.FEEDBACK_ANIMATION)
    .hitTestBehavior(this.hasClearValue ? HitTestMode.Default : HitTestMode.None)
    .accessibilityLevel(this.hasClearValue ? 'auto' : 'no-hide-descendants')
  }

  @Builder
  private trailingSlot() {
    if (this.suffix !== undefined || this.clearable || this.trailingBuilder !== undefined) {
      Row({ space: $r('app.float.ds_space_xs') }) {
        if (this.clearable) {
          this.clearSlot()
        }
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
    .outline({
      width: this.inputBorderWidth,
      color: this.inputBorderColor,
      radius: $r('app.float.ds_radius_none'),
    })
    .animation(AnimationTokens.FEEDBACK_ANIMATION)
  }
}
