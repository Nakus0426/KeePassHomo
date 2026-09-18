import { AnimationTokens } from '@ohos/common'
import { formFieldBorderColor, FormTextFieldStatus } from './FormTextField'

/**
 * 通用多行文本输入框：边框、圆角、背景与 Focus/Blur 过渡与 FormTextField 保持一致，
 * 高度在 min/max 区间内随内容自适应。
 */
@ComponentV2
export struct FormTextArea {
  @Param text: string = ''
  @Param placeholder: ResourceStr | undefined = undefined
  /** 语义状态色；undefined 表示无反馈，边框回落到默认/聚焦逻辑 */
  @Param status: FormTextFieldStatus | undefined = undefined
  @Event onChange: (value: string) => void = () => {
  }
  /** 焦点变化回调，供外部驱动尾部内容的条件渲染 */
  @Event onFocusChange: (focused: boolean) => void = () => {
  }
  /** 键盘提交回调（回车/前往） */
  @Event onSubmit: (value: string) => void = () => {
  }
  /** 尾部附加内容插槽 */
  @BuilderParam suffixBuilder?: () => void
  @Local private focused: boolean = false

  @Computed
  get borderColorValue(): ResourceColor {
    return formFieldBorderColor(this.status, this.focused)
  }

  build() {
    Row({ space: $r('sys.float.padding_level2') }) {
      TextArea({ placeholder: this.placeholder, text: this.text })
        .constraintSize({
          minHeight: $r('app.float.text_area_min_height'),
          maxHeight: $r('app.float.text_area_max_height'),
        })
        .layoutWeight(1)
        .padding({
          top: $r('sys.float.padding_level4'),
          bottom: $r('sys.float.padding_level4'),
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
        })
        .backgroundColor(Color.Transparent)
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

      if (this.suffixBuilder !== undefined) {
        this.suffixBuilder()
      }
    }
    .width('100%')
    .padding({ right: this.suffixBuilder !== undefined ? $r('sys.float.padding_level4') : 0 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.ohos_id_corner_radius_text_field'))
    .border({
      width: $r('sys.float.border_width'),
      color: this.borderColorValue,
    })
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })
  }
}
