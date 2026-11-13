import { displaySync } from '@kit.ArkGraphics2D'
import { AnimationTokens, ColorUtil } from '@ohos/common'
import { ColorModeState, colorModeState } from '../state/ColorModeState'
import { findMorphShape } from './morph/MorphRegistry'
import { MorphShape } from './morph/MorphShape'

function blendArgb(from: number, to: number, progress: number): number {
  const fromA: number = (from >>> 24) & 0xFF
  const fromR: number = (from >>> 16) & 0xFF
  const fromG: number = (from >>> 8) & 0xFF
  const fromB: number = from & 0xFF
  const toA: number = (to >>> 24) & 0xFF
  const toR: number = (to >>> 16) & 0xFF
  const toG: number = (to >>> 8) & 0xFF
  const toB: number = to & 0xFF
  const alpha: number = Math.round(fromA + (toA - fromA) * progress)
  const red: number = Math.round(fromR + (toR - fromR) * progress)
  const green: number = Math.round(fromG + (toG - fromG) * progress)
  const blue: number = Math.round(fromB + (toB - fromB) * progress)
  return ((alpha << 24) | (red << 16) | (green << 8) | blue) >>> 0
}

// 两个图标之间切换：已登记形变几何的图标对走 Canvas 形变，其余直接换图标
@ComponentV2
export struct MorphIcon {
  @Require @Param iconOff: Resource
  @Require @Param iconOn: Resource
  @Param checked: boolean = false
  @Param iconSize: number = 20
  @Param color: ResourceColor = $r('app.color.ds_text_secondary')
  @Param colorOn: ResourceColor | undefined = undefined
  @Local private colorMode: ColorModeState = colorModeState
  // 0 = iconOff，1 = iconOn；改这个值由 @Monitor 触发重绘
  @Local private progress: number = 0
  // 解析结果缓存，避免 build/draw/play 反复 findMorphShape
  @Local private shape: MorphShape | undefined = undefined

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private canvas: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private frameSync: displaySync.DisplaySync | undefined = undefined
  private frameCallback: ((info: displaySync.IntervalInfo) => void) | undefined = undefined

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
    this.syncToChecked(true)
  }

  // 节点复用不会重走 aboutToAppear，Canvas 会保留上一行条目的星标画面；
  // 挂载、重新可见与 checked 变化时都要按 checked 复位静止帧。
  private syncToChecked(animate: boolean): void {
    const target: number = this.checked ? 1 : 0
    if (!animate || this.shape === undefined) {
      this.stopFrameLoop()
      this.progress = target
      this.draw()
      return
    }
    this.play(target)
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
  @Monitor('color', 'colorOn')
  private onColorChanged(): void {
    this.draw()
  }

  @Computed
  private get fallbackColor(): ResourceColor {
    return this.checked ? (this.colorOn ?? this.color) : this.color
  }

  private draw(): void {
    if (this.shape === undefined) {
      return
    }
    const from: number = ColorUtil.withAlpha(this.color, 1)
    const to: number = ColorUtil.withAlpha(this.colorOn ?? this.color, 1)
    this.shape.draw(this.canvas, this.iconSize, blendArgb(from, to, this.progress), this.progress)
  }

  private play(target: number): void {
    this.stopFrameLoop()
    if (this.shape === undefined) {
      return
    }
    const from: number = this.progress
    if (from === target) {
      this.draw()
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
        .fontColor([this.fallbackColor])
        .foregroundColor(this.fallbackColor)
    } else {
      Canvas(this.canvas)
        .width(this.iconSize)
        .height(this.iconSize)
        .onAppear(() => this.syncToChecked(false))
        .onReady(() => {
          // onReady 也会在尺寸变化时重入，重入时不能把进行中的动画打回终态
          if (this.frameSync === undefined) {
            this.syncToChecked(false)
            return
          }
          this.draw()
        })
    }
  }
}
