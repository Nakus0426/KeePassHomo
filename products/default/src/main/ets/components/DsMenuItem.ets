import { AnimationTokens } from '@ohos/common'

export enum DsMenuItemTheme {
  Default,
  Success,
  Warning,
  Error,
}

@ComponentV2
export struct DsMenuItem {
  @Param icon: Resource | undefined = undefined
  // 品牌图等非字体图标：传入时替代字体图标。
  @Param iconImage: Resource | undefined = undefined
  @Param label: ResourceStr = ''
  @Param theme: DsMenuItemTheme = DsMenuItemTheme.Default
  @Event onAction: () => void = () => {}
  // 传入即整行替换默认的图标 + 标签，优先级高于 icon / label。
  @BuilderParam customRow?: () => void
  @Local private hovered: boolean = false
  @Local private pressed: boolean = false

  private contentColor(): ResourceColor {
    if (this.theme === DsMenuItemTheme.Success) {
      return $r('app.color.ds_success')
    }
    if (this.theme === DsMenuItemTheme.Warning) {
      return $r('app.color.ds_warning')
    }
    if (this.theme === DsMenuItemTheme.Error) {
      return $r('app.color.ds_error')
    }
    return $r('app.color.ds_text_primary')
  }

  private iconColor(): ResourceColor {
    return this.theme === DsMenuItemTheme.Default ? $r('app.color.ds_text_secondary') : this.contentColor()
  }

  build() {
    if (this.customRow !== undefined) {
      Column() {
        this.customRow()
      }
      .width('100%')
      .height($r('app.float.ds_context_menu_item_height'))
      .backgroundColor(this.pressed
        ? $r('app.color.ds_surface_highest')
        : (this.hovered ? $r('app.color.ds_surface_hover') : $r('app.color.ds_surface_lowest')))
      .animation({
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
      })
      .onHover((isHover: boolean) => {
        this.hovered = isHover
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressed = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressed = false
        }
      })
      .onClick(() => this.onAction())
    } else {
      Row({ space: $r('app.float.ds_space_md') }) {
        if (this.iconImage !== undefined) {
          Image(this.iconImage)
            .width($r('app.float.ds_icon_md'))
            .height($r('app.float.ds_icon_md'))
            .objectFit(ImageFit.Contain)
        } else if (this.icon !== undefined) {
          SymbolGlyph(this.icon)
            .fontSize($r('app.float.ds_icon_md'))
            .fontColor([this.iconColor()])
            .foregroundColor(this.iconColor())
        }

        Text(this.label)
          .fontSize($r('app.float.ds_font_body'))
          .fontColor(this.contentColor())
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .height($r('app.float.ds_context_menu_item_height'))
      .padding({ left: $r('app.float.ds_gutter'), right: $r('app.float.ds_gutter') })
      .backgroundColor(this.pressed
        ? $r('app.color.ds_surface_highest')
        : (this.hovered ? $r('app.color.ds_surface_hover') : $r('app.color.ds_surface_lowest')))
      .animation({
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
      })
      .onHover((isHover: boolean) => {
        this.hovered = isHover
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.pressed = true
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          this.pressed = false
        }
      })
      .onClick(() => this.onAction())
    }
  }
}
