@ComponentV2
export struct DsInput {
  @Param text: string = ''
  @Param placeholder: ResourceStr = ''
  @Param type: InputType = InputType.Normal
  @Param showPassword: boolean = false
  @Param prefix: ResourceStr | undefined = undefined
  @Param suffix: ResourceStr | undefined = undefined
  @Event onChange: (value: string) => void = () => {
  }
  @Event onSubmit: (value: string) => void = () => {
  }
  @BuilderParam trailingBuilder?: () => void

  build() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      if (this.prefix !== undefined) {
        Text(this.prefix)
          .fontSize($r('app.float.ds_font_body_sm'))
          .fontColor($r('app.color.ds_text_tertiary'))
      }

      TextInput({ placeholder: this.placeholder, text: this.text })
        .type(this.type)
        .showPasswordIcon(false)
        .showPassword(this.showPassword)
        .height('100%')
        .padding(0)
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .fontSize($r('app.float.ds_font_body'))
        .fontColor($r('app.color.ds_text_primary'))
        .placeholderFont({ size: $r('app.float.ds_font_body') })
        .placeholderColor($r('app.color.ds_text_tertiary'))
        .caretColor($r('app.color.ds_primary'))
        .onChange((value: string) => this.onChange(value))
        .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => this.onSubmit(event.text))

      if (this.suffix !== undefined) {
        Text(this.suffix)
          .fontSize($r('app.float.ds_font_body_sm'))
          .fontColor($r('app.color.ds_text_tertiary'))
      }

      if (this.trailingBuilder !== undefined) {
        this.trailingBuilder()
      }
    }
    .width('100%')
    .height($r('app.float.ds_input_height'))
    .padding({ left: $r('app.float.ds_space_md'), right: $r('app.float.ds_space_md') })
    .backgroundColor($r('app.color.ds_surface_low'))
  }
}
