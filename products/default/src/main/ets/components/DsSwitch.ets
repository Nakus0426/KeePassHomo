import { AnimationTokens, measureVp } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { DsControlSize } from './DsControlSize'
import { DsColorLadder } from './DsColorLadder'


interface SwitchMetrics {
  trackWidth: number
  trackHeight: number
  knobSize: number
  pressExtra: number
  ringWidth: number
}

const EMPTY_METRICS: SwitchMetrics = { trackWidth: 0, trackHeight: 0, knobSize: 0, pressExtra: 0, ringWidth: 0 }

// 0 圆角轨道 + 方形旋钮，轨道内边距恒定 3，旋钮贴边滑动。
@ComponentV2
export struct DsSwitch {
  @Param checked: boolean = false
  @Param disabled: boolean = false
  // 不能命名为 size：与 CustomComponent.size() 冲突。
  @Param switchSize: DsControlSize = DsControlSize.Medium
  @Param accessibilityLabel: ResourceStr = ''
  @Event onChange: (value: boolean) => void = () => {
  }

  @Local private hovered: boolean = false
  @Local private pressed: boolean = false
  // 尺寸集中一次赋值，避免 measure 连续写多个 @Local 触发多次刷新。
  @Local private metrics: SwitchMetrics = EMPTY_METRICS

  aboutToAppear(): void {
    this.measure()
  }

  @Monitor('switchSize')
  onSwitchSizeChanged(): void {
    this.measure()
  }

  @Monitor('disabled')
  onDisabledChanged(): void {
    if (this.disabled) {
      this.hovered = false
      this.pressed = false
    }
  }

  @Computed
  get effectiveAccessibilityLabel(): string {
    return typeof this.accessibilityLabel === 'string'
      ? this.accessibilityLabel : ResUtil.getStringSync(this.accessibilityLabel)
  }

  private measure(): void {
    const uiContext: UIContext = this.getUIContext()
    let width: Resource
    let height: Resource
    let knob: Resource
    switch (this.switchSize) {
      case DsControlSize.Small:
        width = $r('app.float.ds_switch_width_sm')
        height = $r('app.float.ds_switch_height_sm')
        knob = $r('app.float.ds_switch_knob_sm')
        break
      case DsControlSize.Large:
        width = $r('app.float.ds_switch_width_lg')
        height = $r('app.float.ds_switch_height_lg')
        knob = $r('app.float.ds_switch_knob_lg')
        break
      default:
        width = $r('app.float.ds_switch_width_md')
        height = $r('app.float.ds_switch_height_md')
        knob = $r('app.float.ds_switch_knob_md')
        break
    }
    this.metrics = {
      trackWidth: measureVp(uiContext, width),
      trackHeight: measureVp(uiContext, height),
      knobSize: measureVp(uiContext, knob),
      pressExtra: measureVp(uiContext, $r('app.float.ds_switch_knob_press_extra')),
      ringWidth: measureVp(uiContext, $r('app.float.ds_switch_ring_width')),
    }
  }

  @Computed
  get trackColor(): ResourceColor {
    if (this.disabled) {
      return this.checked ? $r('app.color.ds_outline_variant') : $r('app.color.ds_surface_highest')
    }
    if (this.checked) {
      if (this.pressed) {
        return $r('app.color.ds_primary_press')
      }
      return this.hovered ? $r('app.color.ds_primary_hover') : $r('app.color.ds_primary')
    }
    return this.hovered || this.pressed ? $r('app.color.ds_outline_variant') : $r('app.color.ds_surface_highest')
  }

  @Computed
  get knobColor(): ResourceColor {
    if (this.disabled) {
      return this.checked ? $r('app.color.ds_surface_lowest') : $r('app.color.ds_text_disabled')
    }
    return this.checked ? $r('app.color.ds_on_primary') : $r('app.color.ds_outline')
  }

  @Computed
  get ringColor(): ResourceColor {
    return this.pressed ? DsColorLadder.RING_MUTED : DsColorLadder.RING_SUBTLE
  }

  @Computed
  get ringActive(): boolean {
    return this.hovered || this.pressed
  }

  // 按下时旋钮横向拉伸 4，高度不变。
  @Computed
  get knobWidth(): number {
    return this.pressed && !this.disabled ? this.metrics.knobSize + this.metrics.pressExtra : this.metrics.knobSize
  }

  @Computed
  get knobInset(): number {
    return (this.metrics.trackHeight - this.metrics.knobSize) / 2
  }

  // 用 translate 挂位移，开 / 关切换才会随动画平滑滑动。
  @Computed
  get knobSlide(): number {
    return this.checked ? this.metrics.trackWidth - this.knobInset * 2 - this.knobWidth : 0
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width(this.metrics.trackWidth)
        .height(this.metrics.trackHeight)
        .backgroundColor(this.trackColor)
        .borderRadius($r('app.float.ds_radius_none'))
        .position({ x: this.metrics.ringWidth, y: this.metrics.ringWidth })
        .hitTestBehavior(HitTestMode.None)
        .animation(AnimationTokens.FEEDBACK_ANIMATION)

      Column()
        .width(this.knobWidth)
        .height(this.metrics.knobSize)
        .backgroundColor(this.knobColor)
        .borderRadius($r('app.float.ds_radius_none'))
        .position({
          x: this.metrics.ringWidth + this.knobInset,
          y: this.metrics.ringWidth + this.knobInset,
        })
        .translate({ x: this.knobSlide })
        .hitTestBehavior(HitTestMode.None)
        .animation(AnimationTokens.FEEDBACK_ANIMATION)
    }
    .width(this.metrics.trackWidth + this.metrics.ringWidth * 2)
    .height(this.metrics.trackHeight + this.metrics.ringWidth * 2)
    .backgroundColor(this.ringActive ? this.ringColor : Color.Transparent)
    .animation(AnimationTokens.FEEDBACK_ANIMATION)
    .accessibilityText(this.effectiveAccessibilityLabel)
    .enabled(!this.disabled)
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
    .onClick(() => this.onChange(!this.checked))
  }
}
