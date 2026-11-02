import { ResUtil } from '@pura/harmony-utils'
import { DsButton, DsButtonSize, DsButtonTone, DsButtonVariant } from './DsButton'
import { MorphIcon } from './MorphIcon'

// 图标按钮：外观与反馈全部来自 DsButton，图标通过内容插槽提供
@ComponentV2
export struct IconToggleButton {
  // 默认图标走设计系统 Material Symbols 字体
  @Param symbol: Resource = $r('app.string.symbol_eye')
  // 传入时按 checked 在两个图标间切换，symbol 即未选中态
  @Param symbolChecked: Resource | undefined = undefined
  @Param checked: boolean = false
  @Param symbolColor: ResourceColor = $r('app.color.ds_on_surface_variant')
  @Require @Param accessibilityLabel: Resource
  @Param clickable: boolean = true
  // 与 DsButton 对齐的外观属性
  @Param variant: DsButtonVariant = DsButtonVariant.Text
  @Param tone: DsButtonTone = DsButtonTone.Default
  @Param buttonSize: DsButtonSize = DsButtonSize.Small
  // 输入框图标框等非标准边长覆盖；不传时使用 buttonSize
  @Param boxSize: Resource | undefined = undefined
  @Param iconSizeOverride: Resource | undefined = undefined
  // 按钮被更大的可点区域包住时，独占交互避免两层同时响应点击
  @Param exclusive: boolean = false
  @Event onToggle: () => void = () => {
  }

  @Computed
  private get iconSize(): number {
    const size: Resource = this.iconSizeOverride ?? $r('app.float.ds_icon_sm')
    return this.getUIContext().px2vp(ResUtil.getNumber(size.id))
  }

  @Computed
  private get effectiveSymbolColor(): ResourceColor {
    return this.clickable ? this.symbolColor : $r('app.color.ds_text_disabled')
  }

  @LocalBuilder
  private iconContent() {
    if (this.symbolChecked === undefined) {
      SymbolGlyph(this.symbol)
        .fontSize(this.iconSize)
        .fontColor([this.effectiveSymbolColor])
        .foregroundColor(this.effectiveSymbolColor)
    } else {
      MorphIcon({
        iconOff: this.symbol,
        iconOn: this.symbolChecked,
        checked: this.checked,
        iconSize: this.iconSize,
        color: this.effectiveSymbolColor,
      })
    }
  }

  build() {
    DsButton({
      variant: this.variant,
      tone: this.tone,
      buttonSize: this.buttonSize,
      controlHeightOverride: this.boxSize,
      iconSizeOverride: this.iconSizeOverride,
      iconOnly: true,
      disabled: !this.clickable,
      accessibilityLabelResource: this.accessibilityLabel,
      contentBuilder: this.iconContent,
      onTap: () => this.onToggle(),
    })
      .monopolizeEvents(this.exclusive)
  }
}
