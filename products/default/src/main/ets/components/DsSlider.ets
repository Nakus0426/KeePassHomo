import { AnimationTokens, measureVp } from '@ohos/common'
import { DsColorLadder } from './DsColorLadder'
import { DsControlSize } from './DsControlSize'

// 触摸高度与视觉高度分开：20 高的滑块也要有 44 的手势区域。
const TOUCH_HEIGHT: number = 44
// 设计稿的组件框比滑块高 4，轨道与滑块都在框内垂直居中。
const FRAME_EXTRA_HEIGHT: number = 4
// 状态层比滑块每边宽 6，按下 / 悬停时给出一圈方形反馈。
const HALO_EXTRA_SIZE: number = 12

// 轨道、已选段与滑块三块实色矩形；拖动时位置跟手，只有颜色反馈走过渡。
@ComponentV2
export struct DsSlider {
  @Param value: number = 0
  @Param min: number = 0
  @Param max: number = 100
  @Param step: number = 1
  @Param sliderSize: DsControlSize = DsControlSize.Medium
  // 不能命名为 enabled：与 CustomComponent.enabled 通用属性方法冲突。
  @Param disabled: boolean = false
  @Event onChange: (value: number) => void = () => {
  }

  @Local private trackWidth: number = 0
  @Local private hovered: boolean = false
  @Local private pressed: boolean = false

  @Computed
  get thumbSize(): Resource {
    switch (this.sliderSize) {
      case DsControlSize.Large:
        return $r('app.float.ds_slider_thumb_lg')
      case DsControlSize.Small:
        return $r('app.float.ds_slider_thumb_sm')
      default:
        return $r('app.float.ds_slider_thumb_md')
    }
  }

  @Computed
  get trackHeight(): Resource {
    switch (this.sliderSize) {
      case DsControlSize.Large:
        return $r('app.float.ds_slider_track_h_lg')
      case DsControlSize.Small:
        return $r('app.float.ds_slider_track_h_sm')
      default:
        return $r('app.float.ds_slider_track_h_md')
    }
  }

  @Computed
  get thumbSizeVp(): number {
    return measureVp(this.getUIContext(), this.thumbSize)
  }

  @Computed
  get trackHeightVp(): number {
    return measureVp(this.getUIContext(), this.trackHeight)
  }

  @Computed
  get frameHeight(): number {
    return this.thumbSizeVp + FRAME_EXTRA_HEIGHT
  }

  @Computed
  get haloSize(): number {
    return this.thumbSizeVp + HALO_EXTRA_SIZE
  }

  @Computed
  get active(): boolean {
    return this.hovered || this.pressed
  }

  @Computed
  get ratio(): number {
    if (this.max <= this.min) {
      return 0
    }
    return Math.min(1, Math.max(0, (this.value - this.min) / (this.max - this.min)))
  }

  // 滑块最宽，两端都不越出轨道。
  @Computed
  get thumbLeft(): number {
    return this.ratio * Math.max(0, this.trackWidth - this.thumbSizeVp)
  }

  // 已选段收在滑块中心，设计稿的终点定义。
  @Computed
  get activeWidth(): number {
    return Math.min(this.trackWidth, this.thumbLeft + this.thumbSizeVp / 2)
  }

  @Computed
  get accentColor(): ResourceColor {
    if (this.disabled) {
      return $r('app.color.ds_text_disabled')
    }
    if (this.pressed) {
      return DsColorLadder.PRIMARY.press
    }
    return this.hovered ? DsColorLadder.PRIMARY.hover : DsColorLadder.PRIMARY.base
  }

  private snap(raw: number): number {
    if (this.step <= 0) {
      return Math.min(this.max, Math.max(this.min, Math.round(raw)))
    }
    const steps: number = Math.round((raw - this.min) / this.step)
    return Math.min(this.max, Math.max(this.min, this.min + steps * this.step))
  }

  private updateFromX(x: number): void {
    const span: number = this.trackWidth - this.thumbSizeVp
    if (span <= 0) {
      return
    }
    const ratio: number = Math.min(1, Math.max(0, (x - this.thumbSizeVp / 2) / span))
    const next: number = this.snap(this.min + ratio * (this.max - this.min))
    if (next !== this.value) {
      this.onChange(next)
    }
  }

  // 点击与拖动跨档都走同一段位移过渡；值没跨档时不触发更新，也就没有动画。
  private applyValue(x: number): void {
    this.getUIContext().animateTo({
      duration: AnimationTokens.DURATION_FAST,
      curve: AnimationTokens.EASE_STATE,
    }, () => {
      this.updateFromX(x)
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row()
        .width('100%')
        .height(this.trackHeightVp)
        .backgroundColor($r('app.color.ds_surface_high'))
        .position({ x: 0, y: (this.frameHeight - this.trackHeightVp) / 2 })

      Row()
        .height(this.trackHeightVp)
        .backgroundColor(this.accentColor)
        .animation(AnimationTokens.FEEDBACK_ANIMATION)
        .width(this.activeWidth)
        .position({ x: 0, y: (this.frameHeight - this.trackHeightVp) / 2 })

      // 方形状态层：悬停浅、按下重，滑块本体不变形。
      Row()
        .width(this.haloSize)
        .height(this.haloSize)
        .backgroundColor(this.pressed ? DsColorLadder.RING_MUTED : DsColorLadder.RING_SUBTLE)
        .opacity(this.active ? 1 : 0)
        .scale({ x: this.active ? 1 : 0.8, y: this.active ? 1 : 0.8 })
        .animation(AnimationTokens.FEEDBACK_ANIMATION)
        .hitTestBehavior(HitTestMode.None)
        .position({
          x: this.thumbLeft + (this.thumbSizeVp - this.haloSize) / 2,
          y: (this.frameHeight - this.haloSize) / 2,
        })

      Row()
        .width(this.thumbSizeVp)
        .height(this.thumbSizeVp)
        .backgroundColor(this.accentColor)
        .animation(AnimationTokens.FEEDBACK_ANIMATION)
        .position({ x: this.thumbLeft, y: (this.frameHeight - this.thumbSizeVp) / 2 })
    }
    .width('100%')
    .height(this.frameHeight)
    // 视觉高度只有 20 左右，手势区域上下各扩到 44。
    .responseRegion({
      x: 0,
      y: -(TOUCH_HEIGHT - this.frameHeight) / 2,
      width: '100%',
      height: TOUCH_HEIGHT,
    })
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      const width: number = newValue.width as number
      if (width !== this.trackWidth) {
        this.trackWidth = width
      }
    })
    .onHover((isHover: boolean) => {
      this.hovered = isHover
    })
    .onTouch((event: TouchEvent) => {
      if (this.disabled) {
        return
      }
      if (event.type === TouchType.Down) {
        this.pressed = true
        this.applyValue(event.touches[0].x)
        return
      }
      if (event.type === TouchType.Move) {
        this.applyValue(event.touches[0].x)
        return
      }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false
      }
    })
  }
}
