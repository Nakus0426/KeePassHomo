import { ColorMetrics } from '@kit.ArkUI'
import { ColorUtil } from '@ohos/common'
import { ColorModeState, colorModeState } from '../state/ColorModeState'

export enum TagType {
  Brand = 'brand',
  Warning = 'warning',
  Alert = 'alert',
  Confirm = 'confirm',
  Default = 'default',
}

export enum TagShape {
  Pill = 'pill',
  Square = 'square',
}

const PILL_VERTICAL_PADDING: number = 4
const INITIAL_CORNER_RADIUS: number = 14
const SQUARE_CORNER_RADIUS: number = 4
const TAG_BACKGROUND_OPACITY: number = 0.2

@ComponentV2
export struct Tag {
  @Param type: TagType | ResourceColor | ColorMetrics = TagType.Default
  // Pill 是胶囊徽标（圆角取高度一半），Square 是设计系统的方角标签。
  @Param shape: TagShape = TagShape.Pill
  @BuilderParam content: () => void = this.emptyBuilder
  @Local private cornerRadius: number = INITIAL_CORNER_RADIUS
  @Local private colorMode: ColorModeState = colorModeState

  @Builder
  emptyBuilder() {
  }

  @Computed
  get typeColor(): ResourceColor {
    if (typeof this.type === 'string') {
      if (this.shape === TagShape.Square) {
        return this.squareContainerColor
      }
      switch (this.type) {
        case TagType.Brand:
          return $r('app.color.ds_primary')
        case TagType.Warning:
          return $r('app.color.ds_warning')
        case TagType.Alert:
          return $r('app.color.ds_error')
        case TagType.Confirm:
          return $r('app.color.ds_success')
        case TagType.Default:
          return $r('app.color.ds_text_primary')
        default:
          return this.type
      }
    }
    if (this.type instanceof ColorMetrics) {
      return this.type.color
    }
    return this.type
  }

  @Computed
  get squareContainerColor(): ResourceColor {
    switch (this.type) {
      case TagType.Brand:
        return $r('app.color.ds_primary')
      case TagType.Warning:
        return $r('app.color.ds_warning_container')
      case TagType.Alert:
        return $r('app.color.ds_error_container')
      case TagType.Confirm:
        return $r('app.color.ds_success_container')
      default:
        return $r('app.color.ds_surface_high')
    }
  }

  @Computed
  get contentColor(): ResourceColor {
    if (this.shape !== TagShape.Square || typeof this.type !== 'string') {
      return this.typeColor
    }
    switch (this.type) {
      case TagType.Brand:
        return $r('app.color.ds_on_primary')
      case TagType.Warning:
        return $r('app.color.ds_on_warning_container')
      case TagType.Alert:
        return $r('app.color.ds_on_error_container')
      case TagType.Confirm:
        return $r('app.color.ds_on_success_container')
      default:
        return $r('app.color.ds_text_primary')
    }
  }

  @Computed
  get backgroundColorValue(): number | ResourceColor {
    this.colorMode.isDark
    if (this.shape === TagShape.Square) {
      return this.typeColor
    }
    return ColorUtil.withAlpha(this.typeColor, TAG_BACKGROUND_OPACITY)
  }

  build() {
    Row() {
      this.content()
    }
    .backgroundColor(this.backgroundColorValue)
    .borderRadius(this.shape === TagShape.Square ? SQUARE_CORNER_RADIUS : this.cornerRadius)
    .foregroundColor(this.contentColor)
    .padding({
      top: this.paddingVertical,
      bottom: this.paddingVertical,
      left: this.paddingHorizontal,
      right: this.paddingHorizontal,
    })
    .onSizeChange((_oldValue: SizeResult, newValue: SizeResult) => {
      if (this.shape === TagShape.Square) {
        return
      }
      this.cornerRadius = newValue.height / 2
    })
  }

  @Computed
  get paddingVertical(): number | Resource {
    return this.shape === TagShape.Square ? $r('app.float.ds_space_2') : PILL_VERTICAL_PADDING
  }

  @Computed
  get paddingHorizontal(): number | Resource {
    return this.shape === TagShape.Square ? $r('app.float.ds_space_6') : this.cornerRadius
  }
}
