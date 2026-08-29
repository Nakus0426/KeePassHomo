import { AnimationTokens } from '@ohos/common'

/**
 * 通用文本输入框：统一封装边框、圆角、背景、高度等视觉样式与 Focus/Blur 状态过渡动画。
 * 获得焦点时边框平滑过渡至 brand 色，失焦后恢复默认色；
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
  @Event onChange: (value: string) => void = () => { }
  /** 尾部附加内容插槽 */
  @BuilderParam suffixBuilder?: () => void
  @Local private focused: boolean = false

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
        })
        .onBlur(() => {
          this.focused = false
        })
        .onChange((value: string) => this.onChange(value))

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
      color: this.focused ? $r('sys.color.brand') : $r('sys.color.comp_background_secondary'),
    })
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })
  }
}
