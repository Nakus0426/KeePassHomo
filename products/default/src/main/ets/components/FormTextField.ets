import { AnimationTokens } from '@ohos/common'

// 成员与 sys.color 同名资源一一对应
export enum FormTextFieldStatus {
  Brand = 'brand',
  Confirm = 'confirm',
  Alert = 'alert',
  Warning = 'warning',
}

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

@ComponentV2
export struct FormTextField {
  @Param text: string = ''
  @Param placeholder: ResourceStr | undefined = undefined
  @Param type: InputType = InputType.Normal
  // 仅 Password 类型生效，配合外部切换按钮使用
  @Param showPassword: boolean = false
  @Param status: FormTextFieldStatus | undefined = undefined
  @Event onChange: (value: string) => void = () => { }
  @Event onFocusChange: (focused: boolean) => void = () => {
  }
  @Event onSubmit: (value: string) => void = () => {
  }
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
