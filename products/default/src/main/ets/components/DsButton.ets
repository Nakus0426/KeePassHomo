export enum DsButtonVariant {
  Filled = 'filled',
  Secondary = 'secondary',
}

@ComponentV2
export struct DsButton {
  @Param label: ResourceStr = ''
  @Param variant: DsButtonVariant = DsButtonVariant.Filled
  @Param leadingIcon: Resource | undefined = undefined
  @Param trailingIcon: Resource | undefined = undefined
  @Param active: boolean = true
  @Event onTap: () => void = () => {
  }

  @Computed
  get fillColor(): ResourceColor {
    if (this.variant === DsButtonVariant.Secondary) {
      return $r('app.color.ds_surface_highest')
    }
    return this.active ? $r('app.color.ds_primary') : $r('app.color.ds_surface_high')
  }

  @Computed
  get contentColor(): ResourceColor {
    if (this.variant === DsButtonVariant.Secondary) {
      return this.active ? $r('app.color.ds_text_primary') : $r('app.color.ds_text_disabled')
    }
    return this.active ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_disabled')
  }

  @Computed
  get controlHeight(): Resource {
    return this.variant === DsButtonVariant.Filled
      ? $r('app.float.ds_cta_height') : $r('app.float.ds_button_height')
  }

  @Computed
  get labelSize(): Resource {
    return this.variant === DsButtonVariant.Filled
      ? $r('app.float.ds_font_title') : $r('app.float.ds_font_body_sm')
  }

  build() {
    Row({ space: $r('app.float.ds_space_xs') }) {
      if (this.leadingIcon !== undefined) {
        SymbolGlyph(this.leadingIcon)
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([this.contentColor])
      }
      Text(this.label)
        .fontSize(this.labelSize)
        .fontWeight(600)
        .fontColor(this.contentColor)
        .maxLines(1)
      if (this.trailingIcon !== undefined) {
        SymbolGlyph(this.trailingIcon)
          .fontSize($r('app.float.ds_icon_sm'))
          .fontColor([this.contentColor])
      }
    }
    .width('100%')
    .height(this.controlHeight)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.fillColor)
    .enabled(this.active)
    .onClick(() => this.onTap())
  }
}
