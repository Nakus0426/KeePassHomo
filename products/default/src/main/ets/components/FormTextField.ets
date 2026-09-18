import { AnimationTokens } from '@ohos/common'

/** 输入框语义状态，成员与 sys.color 同名资源一一对应 */
export enum FormTextFieldStatus {
  Brand = 'brand',
  Confirm = 'confirm',
  Alert = 'alert',
  Warning = 'warning',
}

/**
 * 输入类控件的边框色：status 优先，无 status 时聚焦为 brand、失焦回落默认色。
 * 单行与多行输入框共用同一条规则。
 */
export function formFieldBorderColor(status: FormTextFieldStatus | undefined, focused: boolean): ResourceColor {
  switch (status) {
    case FormTextFieldStatus.Brand:
      return $r('sys.color.brand')
    case FormTextFieldStatus.Confirm:
      return $r('sys.color.confirm')
    case FormTextFieldStatus.Alert:
      return $r('sys.color.alert')
    case FormTextFieldStatus.Warning:
      return $r('sys.color.warning')
  }
  return focused ? $r('sys.color.brand') : $r('sys.color.comp_background_secondary')
}

/**
 * 通用文本输入框：统一封装边框、圆角、背景、高度等视觉样式与 Focus/Blur 状态过渡动画。
 * 未设置 status 时，获得焦点边框平滑过渡至 brand 色，失焦后恢复默认色；
 * 设置 status 时边框恒为对应语义色，优先于聚焦状态，颜色变化同样带过渡动画；
 * suffixBuilder 用于渲染尾部附加内容（如密码可见性切换、功能入口按钮）。
 */
@ComponentV2
export struct FormTextField {
  /** 受控文本，由外部状态驱动 */
  @Param text: string = ''
  @Param placeholder: ResourceStr | undefined = undefined
  @Param type: InputType = InputType.Normal
  /** 密码明文显示，仅 Password 类型生效，配合外部切换按钮使用 */
  @Param showPassword: boolean = false
  /** 语义状态色；undefined 表示无反馈，边框回落到默认/聚焦逻辑 */
  @Param status: FormTextFieldStatus | undefined = undefined
  @Event onChange: (value: string) => void = () => { }
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
      TextInput({ placeholder: this.placeholder, text: this.text })
        .type(this.type)
        .showPasswordIcon(false)
        .showPassword(this.showPassword)
        .height($r('app.float.control_height'))
        .layoutWeight(1)
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
    .height($r('app.float.control_height'))
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
