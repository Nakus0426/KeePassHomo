import { AnimationTokens } from '@ohos/common'
import { DsColorLadder } from './DsColorLadder'

export enum DsTagTone {
  Default = 'default',
  Primary = 'primary',
  Success = 'success',
  Warning = 'warning',
  Error = 'error',
}

export enum DsTagSize {
  Small = 'small',
  Medium = 'medium',
  Large = 'large',
}

interface TagPalette {
  container: ResourceColor
  content: ResourceColor
}

export interface TagMetrics {
  fontSize: Resource
  padVertical: Resource
  padHorizontal: Resource
  gap: Resource
  // 设计 $leading-tight 1.2 取整（12/15/18 → 14/18/22）；lineHeight 数值单位是 fp，不能由字号经 px2vp 推导。
  lineHeight: number
}

// 标签几何的唯一来源：可编辑标签的输入井与 × 需要与 DsTag 严格同高，不能各写一份规格。
export function dsTagMetrics(size: DsTagSize): TagMetrics {
  switch (size) {
    case DsTagSize.Large:
      return {
        fontSize: $r('app.float.ds_font_headline_md'),
        padVertical: $r('app.float.ds_space_6'),
        padHorizontal: $r('app.float.ds_space_md'),
        gap: $r('app.float.ds_space_sm'),
        lineHeight: 22,
      }
    case DsTagSize.Small:
      return {
        fontSize: $r('app.float.ds_font_label_md'),
        padVertical: $r('app.float.ds_space_3'),
        padHorizontal: $r('app.float.ds_space_sm'),
        gap: $r('app.float.ds_space_xs'),
        lineHeight: 14,
      }
    default:
      return {
        fontSize: $r('app.float.ds_font_title'),
        padVertical: $r('app.float.ds_space_xs'),
        padHorizontal: $r('app.float.ds_space_10'),
        gap: $r('app.float.ds_space_6'),
        lineHeight: 18,
      }
  }
}

@ComponentV2
export struct DsTag {
  @Param tone: DsTagTone = DsTagTone.Default
  // 不能命名为 size：与 CustomComponent.size() 冲突。
  @Param tagSize: DsTagSize = DsTagSize.Medium
  @Param text: ResourceStr = ''
  // 筛选 chip：选中走 primary 主题，并提供 hover / press 反馈；静态标签保持默认行为。
  @Param selected: boolean = false
  @Param interactive: boolean = false
  @Event onTap: () => void = () => {
  }
  // 自定义内容插槽：提供后替代 text，内容自带前景色。
  @BuilderParam contentBuilder?: () => void
  @Local private hovered: boolean = false
  @Local private pressed: boolean = false

  @Computed
  get palette(): TagPalette {
    if (this.interactive) {
      if (this.selected) {
        const primary = DsColorLadder.PRIMARY
        return {
          container: this.pressed ? primary.press : (this.hovered ? primary.hover : primary.base),
          content: primary.onColor,
        }
      }
      if (this.pressed) {
        return { container: $r('app.color.ds_surface_highest'), content: $r('app.color.ds_text_primary') }
      }
      if (this.hovered) {
        return { container: $r('app.color.ds_surface_hover'), content: $r('app.color.ds_text_primary') }
      }
    }
    switch (this.tone) {
      case DsTagTone.Primary:
        return { container: $r('app.color.ds_primary'), content: $r('app.color.ds_on_primary') }
      case DsTagTone.Success:
        return {
          container: $r('app.color.ds_success_container'),
          content: $r('app.color.ds_on_success_container'),
        }
      case DsTagTone.Warning:
        return {
          container: $r('app.color.ds_warning_container'),
          content: $r('app.color.ds_on_warning_container'),
        }
      case DsTagTone.Error:
        return { container: $r('app.color.ds_error_container'), content: $r('app.color.ds_on_error_container') }
      default:
        return { container: $r('app.color.ds_surface_high'), content: $r('app.color.ds_text_primary') }
    }
  }

  @Computed
  get metrics(): TagMetrics {
    return dsTagMetrics(this.tagSize)
  }

  build() {
    Row({ space: this.metrics.gap }) {
      if (this.contentBuilder !== undefined) {
        this.contentBuilder()
      } else {
        Text(this.text)
          .fontSize(this.metrics.fontSize)
          .fontWeight(600)
          .letterSpacing($r('app.float.ds_tracking_wide_md'))
          .lineHeight(this.metrics.lineHeight)
          .fontColor(this.palette.content)
          .maxLines(1)
      }
    }
    .padding({
      top: this.metrics.padVertical,
      bottom: this.metrics.padVertical,
      left: this.metrics.padHorizontal,
      right: this.metrics.padHorizontal,
    })
    .backgroundColor(this.palette.container)
    .borderRadius($r('app.float.ds_radius_none'))
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .animation(AnimationTokens.FEEDBACK_ANIMATION)
    .onHover((isHover: boolean) => {
      if (this.interactive) {
        this.hovered = isHover
      }
    })
    .onTouch((event: TouchEvent) => {
      if (!this.interactive) {
        return
      }
      if (event.type === TouchType.Down) {
        this.pressed = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false
      }
    })
    .onClick(() => {
      if (this.interactive) {
        this.onTap()
      }
    })
  }
}
