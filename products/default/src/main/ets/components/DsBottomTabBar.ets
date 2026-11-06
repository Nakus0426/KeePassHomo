import { AnimationTokens } from '@ohos/common'
import {
  TAB_BAR_FLOAT_BOTTOM_MARGIN_VP,
  TAB_BAR_FLOAT_HEIGHT_VP,
  TAB_BAR_FLOAT_TOP_INSET_VP,
  TAB_BAR_INNER_PADDING_VP,
  TAB_BAR_SIDE_MARGIN_VP,
  TAB_BAR_SLOT_GAP_VP,
  TAB_ICON_LABEL_GAP_VP,
  TAB_ICON_SIZE_VP,
  TAB_LABEL_FONT_SIZE_FP,
} from '../constants/TabBarMetrics'

export interface DsBottomTabBarItem {
  label: ResourceStr
  icon: Resource
}

const COVER_RATIO: number = 0.5

// 与分段选择器一致的实色滑块：滑块位置是唯一选中视觉，槽位本身不画选中底。
@ComponentV2
export struct DsBottomTabBar {
  @Param items: DsBottomTabBarItem[] = []
  @Param selectedIndex: number = 0
  @Event onSelect: (index: number) => void = () => {
  }

  @Local private thumbX: number = 0
  @Local private contentWidth: number = 0

  @Computed
  get slotWidth(): number {
    const count: number = this.items.length
    if (count === 0 || this.contentWidth <= 0) {
      return 0
    }
    const innerWidth: number = this.contentWidth - TAB_BAR_INNER_PADDING_VP * 2
    return (innerWidth - (count - 1) * TAB_BAR_SLOT_GAP_VP) / count
  }

  @Computed
  get slotHeight(): number {
    return TAB_BAR_FLOAT_HEIGHT_VP - TAB_BAR_INNER_PADDING_VP * 2
  }

  @Monitor('selectedIndex')
  onSelectedIndexChanged(): void {
    this.moveThumbTo(this.selectedIndex, true)
  }

  @Monitor('items')
  onItemsChanged(): void {
    this.moveThumbTo(this.selectedIndex, false)
  }

  // onAreaChange 内同步读取 @Computed 仍可能是旧值，尺寸落定后再归位滑块。
  @Monitor('contentWidth')
  onContentWidthChanged(): void {
    this.moveThumbTo(this.selectedIndex, false)
  }

  private slotLeft(index: number): number {
    return TAB_BAR_INNER_PADDING_VP + index * (this.slotWidth + TAB_BAR_SLOT_GAP_VP)
  }

  private moveThumbTo(index: number, animated: boolean): void {
    if (this.slotWidth <= 0) {
      return
    }
    const target: number = this.slotLeft(Math.max(0, Math.min(this.items.length - 1, index)))
    if (!animated) {
      this.thumbX = target
      return
    }
    this.getUIContext().animateTo({
      duration: AnimationTokens.DURATION_FEEDBACK,
      curve: AnimationTokens.EASE_STATE,
    }, () => {
      this.thumbX = target
    })
  }

  private isCovered(index: number): boolean {
    if (this.slotWidth <= 0) {
      return index === this.selectedIndex
    }
    const slotLeft: number = this.slotLeft(index)
    const overlap: number = Math.min(this.thumbX + this.slotWidth, slotLeft + this.slotWidth)
      - Math.max(this.thumbX, slotLeft)
    return Math.max(0, overlap) / this.slotWidth > COVER_RATIO
  }

  private select(index: number): void {
    if (index === this.selectedIndex) {
      return
    }
    this.moveThumbTo(index, true)
    this.onSelect(index)
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        Row()
          .width('100%')
          .height(TAB_BAR_FLOAT_HEIGHT_VP)
          .backgroundColor($r('app.color.ds_surface_low'))
          .hitTestBehavior(HitTestMode.None)

        if (this.slotWidth > 0) {
          Column()
            .width(this.slotWidth)
            .height(this.slotHeight)
            .backgroundColor($r('app.color.ds_primary'))
            .position({ x: this.thumbX, y: TAB_BAR_INNER_PADDING_VP })
            .hitTestBehavior(HitTestMode.None)
        }

        Row({ space: TAB_BAR_SLOT_GAP_VP }) {
          ForEach(this.items, (item: DsBottomTabBarItem, index: number) => {
            Column({ space: TAB_ICON_LABEL_GAP_VP }) {
              SymbolGlyph(item.icon)
                .fontSize(TAB_ICON_SIZE_VP)
                .fontColor([this.isCovered(index)
                  ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_secondary')])
                .foregroundColor(this.isCovered(index)
                  ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_secondary'))
              Text(item.label)
                .fontSize(TAB_LABEL_FONT_SIZE_FP)
                .fontWeight(600)
                .fontColor(this.isCovered(index)
                  ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_secondary'))
                .maxLines(1)
            }
            .layoutWeight(1)
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .onClick(() => this.select(index))
          }, (_item: DsBottomTabBarItem, index: number) => index.toString())
        }
        .width('100%')
        .height(TAB_BAR_FLOAT_HEIGHT_VP)
        .padding(TAB_BAR_INNER_PADDING_VP)
      }
      .width('100%')
      .height(TAB_BAR_FLOAT_HEIGHT_VP)
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.contentWidth = newValue.width as number
      })
    }
    .width('100%')
    .height(TAB_BAR_FLOAT_TOP_INSET_VP)
    .padding({
      left: TAB_BAR_SIDE_MARGIN_VP,
      right: TAB_BAR_SIDE_MARGIN_VP,
      bottom: TAB_BAR_FLOAT_BOTTOM_MARGIN_VP,
    })
  }
}
