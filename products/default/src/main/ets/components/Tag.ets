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

const TAG_VERTICAL_PADDING: number = 4
const INITIAL_CORNER_RADIUS: number = 14
const TAG_BACKGROUND_OPACITY: number = 0.2

@ComponentV2
export struct Tag {
  @Param type: TagType | ResourceColor | ColorMetrics = TagType.Default
  @BuilderParam content: () => void = this.emptyBuilder
  @Local private cornerRadius: number = INITIAL_CORNER_RADIUS
  @Local private colorMode: ColorModeState = colorModeState

  @Builder
  emptyBuilder() {
  }

  @Computed
  get typeColor(): ResourceColor {
    if (typeof this.type === 'string') {
      switch (this.type) {
        case TagType.Brand:
          return $r('sys.color.brand')
        case TagType.Warning:
          return $r('sys.color.warning')
        case TagType.Alert:
          return $r('sys.color.alert')
        case TagType.Confirm:
          return $r('sys.color.confirm')
        case TagType.Default:
          return $r('sys.color.font_primary')
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
  get backgroundColorValue(): number {
    this.colorMode.isDark
    return ColorUtil.withAlpha(this.typeColor, TAG_BACKGROUND_OPACITY)
  }

  build() {
    Row() {
      this.content()
    }
    .backgroundColor(this.backgroundColorValue)
    .borderRadius(this.cornerRadius)
    .foregroundColor(this.typeColor)
    .padding({
      top: TAG_VERTICAL_PADDING,
      bottom: TAG_VERTICAL_PADDING,
      left: this.cornerRadius,
      right: this.cornerRadius,
    })
    .onSizeChange((_oldValue: SizeResult, newValue: SizeResult) => {
      this.cornerRadius = newValue.height / 2
    })
  }
}
