import { ResUtil } from '@pura/harmony-utils'
import { AnimationTokens } from '@ohos/common'

export enum DsTabsSize {
  Small = 'sm',
  Medium = 'md',
  Large = 'lg',
}

export interface DsTabsItem {
  label: ResourceStr
  // 单项禁止：不响应点击与按压反馈，也不参与切换。
  disabled?: boolean
}

// 自定义槽位拿到的状态：selected 表示该页签当前选中，调用方据此决定内容取色。
export interface DsTabsSlot {
  index: number
  selected: boolean
}

const LABEL_LETTER_SPACING: number = 0.2

// 等分下划线标签栏：底部 1vp 基线 + 选中项主色滑动指示块；只点击切换，不支持拖动切换。
@ComponentV2
export struct DsTabs {
  @Param items: DsTabsItem[] = []
  @Param selectedIndex: number = 0
  // 不能命名为 size：与 CustomComponent.size() 冲突。
  @Param tabSize: DsTabsSize = DsTabsSize.Medium
  @Event onSelect: (index: number) => void = () => {
  }
  // 提供后替代默认文本标签，槽位可放图标、图标 + 文本或任意节点；等分宽度与点击区域不变。
  @BuilderParam slotBuilder?: (slot: DsTabsSlot) => void
  // 全部禁止：所有页签不可切换；当前项仍保留主色标示，其余文字置灰。
  @Param disabled: boolean = false

  @Local private indicatorX: number = 0
  @Local private contentWidth: number = 0
  @Local private tabHeightVp: number = 0
  @Local private indicatorVp: number = 0
  @Local private baselineVp: number = 0

  aboutToAppear(): void {
    this.measure()
  }

  @Monitor('tabSize')
  onTabSizeChanged(): void {
    this.measure()
  }

  @Monitor('selectedIndex')
  onSelectedIndexChanged(): void {
    this.moveIndicator(this.selectedIndex, true)
  }

  @Monitor('items')
  onItemsChanged(): void {
    this.moveIndicator(this.selectedIndex, false)
  }

  @Computed
  get heightRes(): Resource {
    switch (this.tabSize) {
      case DsTabsSize.Small:
        return $r('app.float.ds_tab_height_sm')
      case DsTabsSize.Large:
        return $r('app.float.ds_tab_height_lg')
      default:
        return $r('app.float.ds_tab_height_md')
    }
  }

  @Computed
  get indicatorRes(): Resource {
    switch (this.tabSize) {
      case DsTabsSize.Small:
        return $r('app.float.ds_tab_indicator_sm')
      case DsTabsSize.Large:
        return $r('app.float.ds_tab_indicator_lg')
      default:
        return $r('app.float.ds_tab_indicator_md')
    }
  }

  @Computed
  get fontSizeRes(): Resource {
    switch (this.tabSize) {
      case DsTabsSize.Small:
        return $r('app.float.ds_tab_font_size_sm')
      case DsTabsSize.Large:
        return $r('app.float.ds_tab_font_size_lg')
      default:
        return $r('app.float.ds_tab_font_size_md')
    }
  }

  @Computed
  get slotWidth(): number {
    const count: number = this.items.length
    if (count === 0 || this.contentWidth <= 0) {
      return 0
    }
    return this.contentWidth / count
  }

  @Computed
  get baselineY(): number {
    return this.tabHeightVp - this.baselineVp
  }

  @Computed
  get indicatorY(): number {
    return this.tabHeightVp - this.indicatorVp
  }

  private measure(): void {
    const uiContext: UIContext = this.getUIContext()
    this.tabHeightVp = uiContext.px2vp(ResUtil.getNumber(this.heightRes.id))
    this.indicatorVp = uiContext.px2vp(ResUtil.getNumber(this.indicatorRes.id))
    this.baselineVp = uiContext.px2vp(ResUtil.getNumber($r('app.float.ds_border_width').id))
  }

  private moveIndicator(index: number, animated: boolean): void {
    if (this.slotWidth <= 0) {
      return
    }
    const target: number = Math.max(0, Math.min(this.items.length - 1, index)) * this.slotWidth
    if (!animated) {
      this.indicatorX = target
      return
    }
    this.getUIContext().animateTo({
      duration: AnimationTokens.DURATION_FEEDBACK,
      curve: AnimationTokens.EASE_STATE,
    }, () => {
      this.indicatorX = target
    })
  }

  private isItemDisabled(index: number): boolean {
    if (this.disabled) {
      return true
    }
    const item: DsTabsItem | undefined = this.items[index]
    return item !== undefined && item.disabled === true
  }

  private handleSelect(index: number): void {
    if (index === this.selectedIndex || this.isItemDisabled(index)) {
      return
    }
    this.moveIndicator(index, true)
    this.onSelect(index)
  }

  private labelColor(index: number): ResourceColor {
    if (index === this.selectedIndex) {
      return $r('app.color.ds_text_primary')
    }
    return this.isItemDisabled(index)
      ? $r('app.color.ds_text_disabled') : $r('app.color.ds_text_secondary')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row()
        .width('100%')
        .height(this.baselineVp)
        .backgroundColor($r('app.color.ds_outline_variant'))
        .position({ x: 0, y: this.baselineY })

      if (this.slotWidth > 0) {
        Row()
          .width(this.slotWidth)
          .height(this.indicatorVp)
          .backgroundColor($r('app.color.ds_primary'))
          .position({ x: this.indicatorX, y: this.indicatorY })
          .hitTestBehavior(HitTestMode.Transparent)
      }

      Row() {
        ForEach(this.items, (item: DsTabsItem, index: number) => {
          Row() {
            if (this.slotBuilder !== undefined) {
              this.slotBuilder({ index: index, selected: index === this.selectedIndex })
            } else {
              Text(item.label)
                .fontSize(this.fontSizeRes)
                .fontWeight(600)
                .letterSpacing(LABEL_LETTER_SPACING)
                .fontColor(this.labelColor(index))
                .maxLines(1)
                .animation({
                  duration: AnimationTokens.DURATION_FEEDBACK,
                  curve: AnimationTokens.EASE_STATE,
                })
            }
          }
          .layoutWeight(1)
          .height(this.tabHeightVp)
          .justifyContent(FlexAlign.Center)
          .onClick(() => this.handleSelect(index))
        }, (item: DsTabsItem, index: number) => `${index}_${item.label}`)
      }
      .width('100%')
      .height(this.tabHeightVp)
    }
    .width('100%')
    .height(this.tabHeightVp)
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.contentWidth = newValue.width as number
      if (this.slotWidth > 0) {
        this.moveIndicator(this.selectedIndex, false)
      }
    })
  }
}
