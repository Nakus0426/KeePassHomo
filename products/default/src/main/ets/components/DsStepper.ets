import { AnimationTokens } from '@ohos/common'
import { MorphIcon } from './MorphIcon'

// 步骤条内部几何常量：正方形标记与 1px 级连接线，纯组件内使用，不作为跨组件令牌。
const MARKER_SIZE: number = 20
const MARKER_ICON_SIZE: number = 12
const NUMBER_FONT_SIZE: number = 11
const ITEM_GAP: number = 4
const CONNECTOR_INSET: number = 8
const CONNECTOR_THICKNESS: number = 1.5
const DASH_WIDTH: number = 3
const DASHES: number[] = [0, 1, 2, 3, 4]
const LABEL_FONT_SIZE: number = 12

// 序号 1..n 直角方框串联的步骤条：完成=实心主色+对勾，进行中=主色描边+序号，未开始=淡色实心+灰序号。
// 连接线完成段实线、未完成段虚线；步骤推进时实线自左向右填充。
@ComponentV2
export struct DsStepper {
  @Param steps: ResourceStr[] = []
  // 每步对应的图标（未完成态）；完成态统一显示对勾。缺省时回退为序号。
  @Param icons: Resource[] = []
  @Param currentIndex: number = 0
  @Param disabled: boolean = false
  @Event onSelect: (index: number) => void = () => {
  }

  // 用于连接线填充动画的浮点进度，随 currentIndex 在 animateTo 内过渡。
  @Local private progress: number = 0

  aboutToAppear(): void {
    this.progress = this.currentIndex
  }

  @Monitor('currentIndex')
  onCurrentIndexChanged(): void {
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    }, () => {
      this.progress = this.currentIndex
    })
  }

  private isDone(index: number): boolean {
    return index < this.currentIndex
  }

  private isCurrent(index: number): boolean {
    return index === this.currentIndex
  }

  private markerFill(index: number): ResourceColor {
    if (this.isDone(index)) {
      return $r('app.color.ds_primary')
    }
    return this.isCurrent(index) ? $r('app.color.ds_surface_canvas') : $r('app.color.ds_surface_low')
  }

  private markerBorderColor(): ResourceColor {
    return $r('app.color.ds_primary')
  }

  private markerBorderWidth(index: number): number {
    return this.isCurrent(index) ? 1.5 : 0
  }

  private numberColor(index: number): ResourceColor {
    return this.isCurrent(index) ? $r('app.color.ds_primary') : $r('app.color.ds_text_tertiary')
  }

  private stepIconColor(index: number): ResourceColor {
    return this.isCurrent(index) ? $r('app.color.ds_primary') : $r('app.color.ds_text_tertiary')
  }

  private labelColor(index: number): ResourceColor {
    if (this.isCurrent(index)) {
      return $r('app.color.ds_text_primary')
    }
    return this.isDone(index) ? $r('app.color.ds_text_secondary') : $r('app.color.ds_text_tertiary')
  }

  private labelWeight(index: number): number {
    if (this.isCurrent(index)) {
      return 600
    }
    return this.isDone(index) ? 500 : 400
  }

  // 第 segmentIndex 段连接线（在 segmentIndex 与 segmentIndex+1 之间）的实线填充比例。
  private segmentRatio(segmentIndex: number): number {
    const value: number = this.progress - segmentIndex
    if (value <= 0) {
      return 0
    }
    return value >= 1 ? 1 : value
  }

  @Builder
  private stepItem(label: ResourceStr, index: number) {
    Row({ space: ITEM_GAP }) {
      Stack() {
        if (index < this.icons.length) {
          MorphIcon({
            iconOff: this.icons[index],
            iconOn: $r('app.string.symbol_check'),
            checked: this.isDone(index),
            iconSize: MARKER_ICON_SIZE,
            color: this.isDone(index) ? $r('app.color.ds_on_primary') : this.stepIconColor(index),
          })
        } else {
          Text(`${index + 1}`)
            .fontSize(NUMBER_FONT_SIZE)
            .fontWeight(600)
            .fontColor(this.numberColor(index))
            .opacity(this.isDone(index) ? 0 : 1)
        }
      }
      .width(MARKER_SIZE)
      .height(MARKER_SIZE)
      .backgroundColor(this.markerFill(index))
      .border({ width: this.markerBorderWidth(index), color: this.markerBorderColor() })
      .borderRadius(0)
      .animation({
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
      })

      Text(label)
        .fontSize(LABEL_FONT_SIZE)
        .fontWeight(this.labelWeight(index))
        .fontColor(this.labelColor(index))
        .maxLines(1)
        .animation({
          duration: AnimationTokens.STATE_TRANSITION_DURATION,
          curve: AnimationTokens.STATE_TRANSITION_CURVE,
        })
    }
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (!this.disabled) {
        this.onSelect(index)
      }
    })
  }

  @Builder
  private connector(segmentIndex: number) {
    Row() {
      Stack({ alignContent: Alignment.Start }) {
        Row() {
          ForEach(DASHES, (k: number) => {
            Row()
              .width(DASH_WIDTH)
              .height(CONNECTOR_THICKNESS)
              .backgroundColor($r('app.color.ds_outline_variant'))
          }, (k: number) => `${segmentIndex}_${k}`)
        }
        .width('100%')
        .height(CONNECTOR_THICKNESS)
        .justifyContent(FlexAlign.SpaceBetween)

        Row()
          .width('100%')
          .height(CONNECTOR_THICKNESS)
          .backgroundColor($r('app.color.ds_outline'))
          .scale({ x: this.segmentRatio(segmentIndex), centerX: 0 })
          .opacity(this.segmentRatio(segmentIndex) <= 0 ? 0 : 1)
      }
      .width('100%')
      .height(CONNECTOR_THICKNESS)
    }
    .layoutWeight(1)
    .height(MARKER_SIZE)
    .padding({ left: CONNECTOR_INSET, right: CONNECTOR_INSET })
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Row() {
      ForEach(this.steps, (label: ResourceStr, index: number) => {
        if (index > 0) {
          this.connector(index - 1)
        }
        this.stepItem(label, index)
      }, (label: ResourceStr, index: number) => `${index}`)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
