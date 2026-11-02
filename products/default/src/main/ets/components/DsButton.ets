import { LengthMetrics } from '@kit.ArkUI'
import { ResUtil } from '@pura/harmony-utils'
import { AnimationTokens } from '@ohos/common'

export enum DsButtonVariant {
  Filled = 'filled',
  Dashed = 'dashed',
  Text = 'text',
}

export enum DsButtonTone {
  Primary = 'primary',
  Success = 'success',
  Warning = 'warning',
  Error = 'error',
  Default = 'default',
  // 次级实心按钮：面底比 Default 低一档，用于同排的次要动作。
  Tonal = 'tonal',
}

export enum DsButtonSize {
  Large = 'large',
  Medium = 'medium',
  Small = 'small',
}

const LABEL_LETTER_SPACING: number = 0.2
// 设计稿虚线节奏 6 / 6.25，ArkUI 默认 Dashed 无法指定节奏。
const DASH_WIDTH: LengthMetrics = LengthMetrics.vp(6)
const DASH_GAP: LengthMetrics = LengthMetrics.vp(6.25)

interface DsButtonToneColors {
  base: ResourceColor
  hover: ResourceColor
  press: ResourceColor
  onColor: ResourceColor
}

@ComponentV2
export struct DsButton {
  @Param label: ResourceStr = ''
  @Param variant: DsButtonVariant = DsButtonVariant.Filled
  @Param tone: DsButtonTone = DsButtonTone.Primary
  // 不能命名为 size：与 CustomComponent.size() 冲突。
  @Param buttonSize: DsButtonSize = DsButtonSize.Medium
  // 仅 iconOnly 用；覆盖按钮边长，供图标框等非标准尺寸使用。
  @Param controlHeightOverride: Resource | undefined = undefined
  // Small 文本态默认 8vp；设计稿行内文本按钮要求与实心态一致的 12vp。
  @Param horizontalPaddingOverride: Resource | undefined = undefined
  @Param leadingIcon: Resource | undefined = undefined
  @Param trailingIcon: Resource | undefined = undefined
  @Param fullWidth: boolean = false
  @Param disabled: boolean = false
  @Param iconOnly: boolean = false
  @Param iconSizeOverride: Resource | undefined = undefined
  @Param iconColorOverride: ResourceColor | undefined = undefined
  // 仅覆盖实心态常态面底；hover / press 仍按 tone 取反馈色。
  @Param backgroundColorOverride: ResourceColor | undefined = undefined
  // 不能命名为 accessibilityText：与同名通用属性方法冲突；仅无可见文本时使用。
  @Param accessibilityLabel: string = ''
  @Param accessibilityLabelResource: Resource | undefined = undefined
  // 插槽内容默认继承按钮内容色；提供后替代 label。
  @BuilderParam contentBuilder?: () => void
  @Event onTap: () => void = () => {
  }

  @Local private hovered: boolean = false
  @Local private pressed: boolean = false

  private static readonly TONE_TABLE: Record<string, DsButtonToneColors> = {
    'primary': {
      base: $r('app.color.ds_primary'),
      hover: $r('app.color.ds_primary_hover'),
      press: $r('app.color.ds_primary_press'),
      onColor: $r('app.color.ds_on_primary'),
    },
    'success': {
      base: $r('app.color.ds_success'),
      hover: $r('app.color.ds_success_hover'),
      press: $r('app.color.ds_success_press'),
      onColor: $r('app.color.ds_on_primary'),
    },
    'warning': {
      base: $r('app.color.ds_warning'),
      hover: $r('app.color.ds_warning_hover'),
      press: $r('app.color.ds_warning_press'),
      onColor: $r('app.color.ds_on_primary'),
    },
    'error': {
      base: $r('app.color.ds_error'),
      hover: $r('app.color.ds_error_hover'),
      press: $r('app.color.ds_error_press'),
      onColor: $r('app.color.ds_on_primary'),
    },
    'default': {
      base: $r('app.color.ds_surface_highest'),
      hover: $r('app.color.ds_default_hover'),
      press: $r('app.color.ds_default_press'),
      onColor: $r('app.color.ds_text_primary'),
    },
    'tonal': {
      base: $r('app.color.ds_surface_high'),
      hover: $r('app.color.ds_default_hover'),
      press: $r('app.color.ds_default_press'),
      onColor: $r('app.color.ds_text_primary'),
    },
  }

  @Monitor('disabled')
  onDisabledChanged(): void {
    if (this.disabled) {
      this.hovered = false
      this.pressed = false
    }
  }

  @Computed
  get toneBaseColor(): ResourceColor {
    return DsButton.TONE_TABLE[this.tone]!.base
  }

  @Computed
  get toneHoverColor(): ResourceColor {
    return DsButton.TONE_TABLE[this.tone]!.hover
  }

  @Computed
  get tonePressColor(): ResourceColor {
    return DsButton.TONE_TABLE[this.tone]!.press
  }

  @Computed
  get fillColor(): ResourceColor {
    if (this.variant !== DsButtonVariant.Filled) {
      if (this.disabled) {
        return Color.Transparent
      }
      if (this.pressed) {
        return $r('app.color.ds_overlay_muted')
      }
      if (this.hovered) {
        return $r('app.color.ds_overlay_subtle')
      }
      return Color.Transparent
    }
    if (this.disabled) {
      return this.backgroundColorOverride ?? $r('app.color.ds_surface_inset')
    }
    if (this.pressed) {
      return this.tonePressColor
    }
    if (this.hovered) {
      return this.toneHoverColor
    }
    return this.backgroundColorOverride ?? this.toneBaseColor
  }

  @Computed
  get buttonBorderColor(): ResourceColor {
    if (this.variant !== DsButtonVariant.Dashed) {
      return Color.Transparent
    }
    if (this.disabled) {
      return $r('app.color.ds_outline_variant')
    }
    return this.tone === DsButtonTone.Default || this.tone === DsButtonTone.Tonal
      ? $r('app.color.ds_outline') : this.toneBaseColor
  }

  @Computed
  get buttonBorderWidth(): Length {
    return this.variant === DsButtonVariant.Dashed ? $r('app.float.ds_border_width') : 0
  }

  @Computed
  get contentColor(): ResourceColor {
    if (this.disabled) {
      return $r('app.color.ds_text_disabled')
    }
    if (this.variant === DsButtonVariant.Filled) {
      return DsButton.TONE_TABLE[this.tone]!.onColor
    }
    return this.tone === DsButtonTone.Default || this.tone === DsButtonTone.Tonal
      ? $r('app.color.ds_on_surface_variant') : this.toneBaseColor
  }

  @Computed
  get controlHeight(): Resource {
    if (this.controlHeightOverride !== undefined) {
      return this.controlHeightOverride
    }
    switch (this.buttonSize) {
      case DsButtonSize.Large:
        return $r('app.float.ds_cta_height')
      case DsButtonSize.Small:
        return $r('app.float.ds_button_small_height')
      default:
        return $r('app.float.ds_button_height')
    }
  }

  @Computed
  get labelSize(): Resource {
    switch (this.buttonSize) {
      case DsButtonSize.Large:
        return $r('app.float.ds_font_title')
      case DsButtonSize.Small:
        return $r('app.float.ds_font_label_sm')
      default:
        return $r('app.float.ds_font_body')
    }
  }

  @Computed
  get iconSize(): Resource {
    if (this.iconSizeOverride !== undefined) {
      return this.iconSizeOverride
    }
    switch (this.buttonSize) {
      case DsButtonSize.Large:
        return $r('app.float.ds_icon_md')
      case DsButtonSize.Small:
        return $r('app.float.ds_icon_xs')
      default:
        return $r('app.float.ds_icon_sm')
    }
  }

  @Computed
  get iconColor(): ResourceColor {
    if (this.disabled) {
      return $r('app.color.ds_text_disabled')
    }
    return this.iconColorOverride ?? this.contentColor
  }

  @Computed
  get contentGap(): Resource {
    return this.buttonSize === DsButtonSize.Small ? $r('app.float.ds_space_6') : $r('app.float.ds_space_sm')
  }

  @Computed
  get horizontalPadding(): Length {
    if (this.iconOnly) {
      return 0
    }
    if (this.horizontalPaddingOverride !== undefined) {
      return this.horizontalPaddingOverride
    }
    switch (this.buttonSize) {
      case DsButtonSize.Large:
        switch (this.variant) {
          case DsButtonVariant.Filled:
            return $r('app.float.ds_space_24')
          case DsButtonVariant.Dashed:
            return $r('app.float.ds_space_lg')
          default:
            return $r('app.float.ds_space_16')
        }
      case DsButtonSize.Small:
        return this.variant === DsButtonVariant.Text
          ? $r('app.float.ds_space_sm') : $r('app.float.ds_space_md')
      default:
        switch (this.variant) {
          case DsButtonVariant.Filled:
            return $r('app.float.ds_space_lg')
          case DsButtonVariant.Dashed:
            return $r('app.float.ds_space_16')
          default:
            return $r('app.float.ds_space_md')
        }
    }
  }

  @Computed
  get buttonWidth(): Length {
    if (this.iconOnly) {
      return this.controlHeight
    }
    return this.fullWidth ? '100%' : 'auto'
  }

  @Computed
  get effectiveAccessibilityLabel(): string {
    if (this.accessibilityLabelResource !== undefined) {
      return ResUtil.getStringSync(this.accessibilityLabelResource)
    }
    return this.accessibilityLabel
  }

  build() {
    Row({ space: this.contentGap }) {
      if (this.leadingIcon !== undefined) {
        SymbolGlyph(this.leadingIcon)
          .fontColor([this.iconColor])
          .foregroundColor(this.iconColor)
          .animation({
            duration: AnimationTokens.DURATION_FEEDBACK,
            curve: AnimationTokens.EASE_STATE,
          })
          .fontSize(this.iconSize)
      }
      if (this.contentBuilder !== undefined) {
        this.contentBuilder()
      } else if (!this.iconOnly) {
        Text(this.label)
          .fontColor(this.contentColor)
          .animation({
            duration: AnimationTokens.DURATION_FEEDBACK,
            curve: AnimationTokens.EASE_STATE,
          })
          .fontSize(this.labelSize)
          .fontWeight(600)
          .letterSpacing(LABEL_LETTER_SPACING)
          .maxLines(1)
      }
      if (this.trailingIcon !== undefined) {
        SymbolGlyph(this.trailingIcon)
          .fontColor([this.iconColor])
          .foregroundColor(this.iconColor)
          .animation({
            duration: AnimationTokens.DURATION_FEEDBACK,
            curve: AnimationTokens.EASE_STATE,
          })
          .fontSize(this.iconSize)
      }
    }
    .backgroundColor(this.fillColor)
    .border({
      width: this.buttonBorderWidth,
      color: this.buttonBorderColor,
      style: BorderStyle.Dashed,
      dashWidth: DASH_WIDTH,
      dashGap: DASH_GAP,
    })
    .foregroundColor(this.contentColor)
    .animation({
      duration: AnimationTokens.DURATION_FEEDBACK,
      curve: AnimationTokens.EASE_STATE,
    })
    .width(this.buttonWidth)
    .height(this.controlHeight)
    .padding({ left: this.horizontalPadding, right: this.horizontalPadding })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .enabled(!this.disabled)
    .accessibilityText(this.effectiveAccessibilityLabel)
    .onHover((isHover: boolean) => {
      if (this.disabled) {
        return
      }
      this.hovered = isHover
    })
    .onTouch((event: TouchEvent) => {
      if (this.disabled) {
        return
      }
      if (event.type === TouchType.Down) {
        this.pressed = true
        return
      }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false
      }
    })
    .onClick(() => this.onTap())
  }
}
