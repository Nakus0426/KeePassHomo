import { displaySync } from '@kit.ArkGraphics2D'
import { AnimationTokens, ColorUtil } from '@ohos/common'
import { ColorModeState, colorModeState } from '../state/ColorModeState'
import { findMorphShape } from './morph/MorphRegistry'
import { MorphShape } from './morph/MorphShape'

// 两个图标之间切换：已登记形变几何的图标对走 Canvas 形变，其余直接换图标
@ComponentV2
export struct MorphIcon {
  @Require @Param iconOff: Resource
  @Require @Param iconOn: Resource
  @Param checked: boolean = false
  @Param iconSize: number = 20
  @Param color: ResourceColor = $r('app.color.ds_text_secondary')
  @Local private colorMode: ColorModeState = colorModeState
  // 0 = iconOff，1 = iconOn；改这个值由 @Monitor 触发重绘
  @Local private progress: number = 0
  // 解析结果缓存，避免 build/draw/play 反复 findMorphShape
  @Local private shape: MorphShape | undefined = undefined

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private frameSync: displaySync.DisplaySync | undefined = undefined
  private frameCallback: ((info: displaySync.IntervalInfo) => void) | undefined = undefined
  private ready: boolean = false

  aboutToAppear(): void {
    this.resolveShape()
  }

  aboutToDisappear(): void {
    this.stopFrameLoop()
  }

  @Monitor('iconOff', 'iconOn')
  private onIconChanged(): void {
    this.resolveShape()
  }

  private resolveShape(): void {
    this.shape = findMorphShape(this.iconOff, this.iconOn)
  }

  @Monitor('checked')
  private onCheckedChange(): void {
    this.play(this.checked ? 1 : 0)
  }

  // Canvas 绘制内容必须由状态刷新驱动，帧回调只改进度
  @Monitor('progress')
  private onProgressChange(): void {
    this.draw()
  }

  // Canvas 不会跟随色调重绘，资源色需重新解析
  @Monitor('colorMode.isDark')
  private onColorModeChange(): void {
    this.draw()
  }

  // color 由调用方随状态切换（如步骤未开始→进行中），Canvas 不会自动跟随，需重绘
  @Monitor('color')
  private onColorChanged(): void {
    this.draw()
  }

  private draw(): void {
    if (this.shape === undefined) {
      return
    }
    this.shape.draw(this.canvas, this.iconSize, ColorUtil.withAlpha(this.color, 1), this.progress)
  }

  private play(target: number): void {
    this.stopFrameLoop()
    if (this.shape === undefined) {
      return
    }
    const from: number = this.progress
    if (from === target) {
      return
    }
    let startTimestamp: number = 0
    const sync: displaySync.DisplaySync = displaySync.create()
    sync.setExpectedFrameRateRange({ min: 30, max: 120, expected: 60 })
    const onFrame: (info: displaySync.IntervalInfo) => void = (info: displaySync.IntervalInfo): void => {
      if (startTimestamp === 0) {
        startTimestamp = info.timestamp
      }
      const elapsed: number = (info.timestamp - startTimestamp) / 1000000
      const fraction: number = Math.min(elapsed / AnimationTokens.STATE_TRANSITION_DURATION, 1)
      this.progress = fraction >= 1 ? target
        : from + (target - from) * AnimationTokens.STATE_TRANSITION_CURVE.interpolate(fraction)
      if (fraction >= 1) {
        this.stopFrameLoop()
      }
    }
    this.frameSync = sync
    this.frameCallback = onFrame
    sync.on('frame', onFrame)
    sync.start()
  }

  private stopFrameLoop(): void {
    if (this.frameSync === undefined) {
      return
    }
    this.frameSync.stop()
    this.frameSync.off('frame', this.frameCallback)
    this.frameSync = undefined
    this.frameCallback = undefined
  }

  build() {
    if (this.shape === undefined) {
      SymbolGlyph(this.checked ? this.iconOn : this.iconOff)
        .fontSize(this.iconSize)
        .fontColor([this.color])
        .foregroundColor(this.color)
    } else {
      Canvas(this.canvas)
        .width(this.iconSize)
        .height(this.iconSize)
        .onReady(() => {
          // onReady 也会在尺寸变化时重入，重入时不能把进行中的动画打回终态
          if (!this.ready) {
            this.ready = true
            this.progress = this.checked ? 1 : 0
          }
          this.draw()
        })
    }
  }
}
