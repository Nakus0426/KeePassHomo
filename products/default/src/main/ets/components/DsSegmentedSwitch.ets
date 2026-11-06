import { AnimationTokens } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'

export interface DsSegmentedSwitchItem {
  label: ResourceStr
  enabled: boolean
}

// 自定义槽位拿到的状态：covered 表示滑块当前压在槽位上，调用方据此选可读的前景色。
export interface DsSegmentedSwitchSlot {
  index: number
  covered: boolean
}

const LABEL_LETTER_SPACING: number = 0.2
// 手指位移小于该值视为点击，避免按下时的手抖被当成拖动。
const DRAG_THRESHOLD: number = 2
// 滑块覆盖超过半格时该格文字取反色，与「实际压在滑块上」一致。
const COVER_RATIO: number = 0.5

// 互斥单选：凹槽内的独立实色滑块标记当前值，点击槽位或拖动滑块切换。
@ComponentV2
export struct DsSegmentedSwitch {
  @Param items: DsSegmentedSwitchItem[] = []
  @Param selectedIndex: number = 0
  @Event onSelect: (index: number) => void = () => {
  }
  // 提供后替代默认文本标签，槽位可放图标、图标 + 文本或任意节点；等分宽度不变。
  @BuilderParam slotBuilder?: (slot: DsSegmentedSwitchSlot) => void
  // 无底色模式：只画滑块与文字，不画凹槽底色，供内联筛选条复用。
  @Param transparentBackground: boolean = false

  @Local private thumbX: number = 0
  @Local private hoveredIndex: number = -1
  @Local private pressedIndex: number = -1
  @Local private contentWidth: number = 0
  @Local private slotHeight: number = 0
  @Local private shellPad: number = 0
  @Local private shellGap: number = 0

  private dragStartX: number = 0
  private dragStartThumbX: number = 0
  private dragMoved: boolean = false
  // 拖动结束后紧随的 onClick 需要吞掉，否则松手会再触发一次槽位点击。
  private suppressClick: boolean = false

  aboutToAppear(): void {
    const uiContext: UIContext = this.getUIContext()
    this.slotHeight = uiContext.px2vp(ResUtil.getNumber($r('app.float.ds_seg_height').id))
    this.shellPad = uiContext.px2vp(ResUtil.getNumber($r('app.float.ds_seg_shell_pad').id))
    this.shellGap = uiContext.px2vp(ResUtil.getNumber($r('app.float.ds_seg_shell_gap').id))
  }

  @Monitor('selectedIndex')
  onSelectedIndexChanged(): void {
    this.moveThumbTo(this.selectedIndex, true)
  }

  @Monitor('items')
  onItemsChanged(): void {
    this.moveThumbTo(this.selectedIndex, false)
  }

  @Computed
  get slotWidth(): number {
    const count: number = this.items.length
    if (count === 0 || this.contentWidth <= 0) {
      return 0
    }
    return (this.contentWidth - (count - 1) * this.shellGap) / count
  }

  @Computed
  get grooveHeight(): number {
    return this.slotHeight + this.shellPad * 2
  }

  private slotLeft(index: number): number {
    return this.shellPad + index * (this.slotWidth + this.shellGap)
  }

  private clampThumbX(value: number): number {
    return Math.max(this.shellPad, Math.min(this.slotLeft(Math.max(0, this.items.length - 1)), value))
  }

  private isEnabled(index: number): boolean {
    const item: DsSegmentedSwitchItem | undefined = this.items[index]
    return item !== undefined && item.enabled
  }

  // 落点只接受启用槽位：从期望下标向两侧找最近的可用项。
  private nearestEnabled(index: number): number {
    const count: number = this.items.length
    if (count === 0) {
      return 0
    }
    const clamped: number = Math.max(0, Math.min(count - 1, index))
    for (let offset: number = 0; offset < count; offset++) {
      const right: number = clamped + offset
      if (right < count && this.isEnabled(right)) {
        return right
      }
      const left: number = clamped - offset
      if (left >= 0 && this.isEnabled(left)) {
        return left
      }
    }
    return clamped
  }

  // 跟手期间直接赋值不加过渡；落位与点击切换走 300ms 反馈曲线。
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

  private settle(): void {
    if (this.slotWidth <= 0) {
      return
    }
    this.pressedIndex = -1
    const step: number = this.slotWidth + this.shellGap
    const index: number = this.nearestEnabled(Math.round((this.thumbX - this.shellPad) / step))
    this.moveThumbTo(index, true)
    if (index !== this.selectedIndex) {
      this.onSelect(index)
    }
  }

  private handleSlotClick(index: number): void {
    if (this.suppressClick) {
      this.suppressClick = false
      return
    }
    // onClick 可能早于触摸 Up 回调，先清掉按下态，避免按下底色压住新滑块。
    this.pressedIndex = -1
    if (!this.isEnabled(index) || index === this.selectedIndex) {
      return
    }
    this.moveThumbTo(index, true)
    this.onSelect(index)
  }

  private handleTouch(event: TouchEvent): void {
    // 松手/取消时 touches 可能为空，收尾不能依赖 touches[0]。
    if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      this.pressedIndex = -1
      if (this.dragMoved) {
        this.dragMoved = false
        this.suppressClick = true
        this.settle()
      }
      return
    }
    const touch: TouchObject | undefined = event.touches[0]
    if (touch === undefined) {
      return
    }
    if (event.type === TouchType.Down) {
      this.dragStartX = touch.x
      this.dragStartThumbX = this.thumbX
      this.dragMoved = false
      this.suppressClick = false
      return
    }
    if (!this.dragMoved && Math.abs(touch.x - this.dragStartX) < DRAG_THRESHOLD) {
      return
    }
    this.dragMoved = true
    this.pressedIndex = -1
    this.hoveredIndex = -1
    this.thumbX = this.clampThumbX(this.dragStartThumbX + touch.x - this.dragStartX)
  }

  // 滑块压在哪个槽上，该槽文字就取反色；其余槽取常规色，禁用槽取禁用色。
  // 覆盖比例按滑块与槽位的真实相交宽度算，滑块停在两槽之间时两侧文字各自可读。
  private isCovered(index: number): boolean {
    if (this.slotWidth <= 0) {
      return index === this.selectedIndex
    }
    const slotLeft: number = this.slotLeft(index)
    const overlap: number = Math.min(this.thumbX + this.slotWidth, slotLeft + this.slotWidth)
      - Math.max(this.thumbX, slotLeft)
    return Math.max(0, overlap) / this.slotWidth > COVER_RATIO
  }

  // 只要滑块与槽位有重叠，就不再画悬停/按下底色，避免反馈层盖住移动中的滑块。
  private isThumbOverSlot(index: number): boolean {
    if (this.slotWidth <= 0) {
      return index === this.selectedIndex
    }
    const slotLeft: number = this.slotLeft(index)
    const overlap: number = Math.min(this.thumbX + this.slotWidth, slotLeft + this.slotWidth)
      - Math.max(this.thumbX, slotLeft)
    return overlap > 0
  }

  private labelColor(index: number): ResourceColor {
    if (!this.isEnabled(index)) {
      return $r('app.color.ds_text_disabled')
    }
    if (this.isCovered(index)) {
      return $r('app.color.ds_on_primary')
    }
    return this.hoveredIndex === index || this.pressedIndex === index
      ? $r('app.color.ds_text_primary') : $r('app.color.ds_on_surface_variant')
  }

  // 选中槽被滑块压住时不叠加反馈底色；按下优先于悬停。
  // 常态必须有实色底：透明色与实色之间的插值会经过灰色，看起来像闪两次。
  private baseFill(): ResourceColor {
    return this.transparentBackground ? Color.Transparent : $r('app.color.ds_surface_low')
  }

  private slotFill(index: number): ResourceColor {
    if (this.isThumbOverSlot(index)) {
      return Color.Transparent
    }
    if (this.isEnabled(index)) {
      if (this.pressedIndex === index) {
        return $r('app.color.ds_surface_highest')
      }
      if (this.hoveredIndex === index) {
        return $r('app.color.ds_surface_high')
      }
    }
    return this.baseFill()
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 反馈底色放在滑块下层：滑块滑入时直接盖住未退完的底色，两段动画不互相遮挡。
      Row({ space: this.shellGap }) {
        ForEach(this.items, (item: DsSegmentedSwitchItem, index: number) => {
          Row()
            .layoutWeight(1)
            .height(this.slotHeight)
            .backgroundColor(this.slotFill(index))
            .animation({
              duration: this.transparentBackground ? 0 : AnimationTokens.DURATION_FEEDBACK,
              curve: AnimationTokens.EASE_STATE,
            })
        }, (item: DsSegmentedSwitchItem, index: number) => `${index}_${item.enabled}_${item.label}`)
      }
      .width('100%')
      .height(this.grooveHeight)
      .padding(this.shellPad)
      .hitTestBehavior(HitTestMode.None)

      if (this.slotWidth > 0) {
        Column()
          .width(this.slotWidth)
          .height(this.slotHeight)
          .backgroundColor($r('app.color.ds_primary'))
          .position({ x: this.thumbX, y: this.shellPad })
          .hitTestBehavior(HitTestMode.Transparent)
      }

      Row({ space: this.shellGap }) {
        ForEach(this.items, (item: DsSegmentedSwitchItem, index: number) => {
          Row() {
            if (this.slotBuilder !== undefined) {
              this.slotBuilder({ index: index, covered: this.isCovered(index) })
            } else {
              Text(item.label)
                .fontSize($r('app.float.ds_seg_font_size'))
                .fontWeight(600)
                .letterSpacing(LABEL_LETTER_SPACING)
                .fontColor(this.labelColor(index))
                .animation({
                  duration: AnimationTokens.DURATION_FEEDBACK,
                  curve: AnimationTokens.EASE_STATE,
                })
                .maxLines(1)
            }
          }
          .layoutWeight(1)
          .height(this.slotHeight)
          .justifyContent(FlexAlign.Center)
          .enabled(this.isEnabled(index))
          .onHover((isHover: boolean) => {
            if (!this.isEnabled(index)) {
              return
            }
            this.hoveredIndex = isHover ? index : -1
          })
          .onTouch((event: TouchEvent) => {
            if (!this.isEnabled(index)) {
              return
            }
            if (event.type === TouchType.Down) {
              this.pressedIndex = index
              return
            }
            if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              if (this.pressedIndex === index) {
                this.pressedIndex = -1
              }
            }
          })
          .onClick(() => this.handleSlotClick(index))
        }, (item: DsSegmentedSwitchItem, index: number) => `${index}_${item.enabled}_${item.label}`)
      }
      .width('100%')
      .height(this.grooveHeight)
      .padding(this.shellPad)
    }
    .width('100%')
    .height(this.grooveHeight)
    .backgroundColor(this.transparentBackground ? Color.Transparent : $r('app.color.ds_surface_low'))
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.contentWidth = Math.max(0, (newValue.width as number) - this.shellPad * 2)
      if (!this.dragMoved) {
        this.moveThumbTo(this.selectedIndex, false)
      }
    })
    .onTouch((event: TouchEvent) => this.handleTouch(event))
  }
}
