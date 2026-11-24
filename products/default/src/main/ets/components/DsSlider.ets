import { DsControlSize } from './DsControlSize'

// 滑块只有圆/图/自定义形状三档，方角与三档尺寸都靠 SHAPE 的自定义路径实现。
const SQUARE_BLOCK_PATH: string = 'M0 0 L100 0 L100 100 L0 100 Z'
// 视觉高度取滑块直径，触摸高度仍保证 44。
const TOUCH_HEIGHT: number = 44

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
  get activeColor(): ResourceColor {
    return this.disabled ? $r('app.color.ds_text_disabled') : $r('app.color.ds_primary')
  }

  build() {
    Slider({
      value: this.value,
      min: this.min,
      max: this.max,
      step: this.step,
      style: SliderStyle.InSet,
    })
      .width('100%')
      .height(TOUCH_HEIGHT)
      .blockSize({ width: this.thumbSize, height: this.thumbSize })
      .blockStyle({ type: SliderBlockType.SHAPE, shape: new Path({ commands: SQUARE_BLOCK_PATH }) })
      .blockColor(this.activeColor)
      .selectedColor(this.activeColor)
      .trackColor($r('app.color.ds_surface_high'))
      .trackThickness(this.trackHeight)
      .trackBorderRadius($r('app.float.ds_radius_none'))
      .selectedBorderRadius($r('app.float.ds_radius_none'))
      .showSteps(false)
      .stepSize(0)
      .enabled(!this.disabled)
      .onChange((value: number) => this.onChange(value))
  }
}
