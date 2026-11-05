import { AnimationTokens } from '../animation/AnimationTokens'

// 瞬态加载的延时显示门：持续超过 400ms 才显示，显示后至少保留 300ms，短暂加载不显示。
@ObservedV2
export class DelayedVisibility {
  @Trace visible: boolean = false
  private showTimer: number = -1
  private hideTimer: number = -1
  private shownAt: number = 0
  private readonly delayMs: number
  private readonly minVisibleMs: number

  constructor(delayMs: number = AnimationTokens.DURATION_LOADING_DELAY,
    minVisibleMs: number = AnimationTokens.DURATION_FEEDBACK) {
    this.delayMs = delayMs
    this.minVisibleMs = minVisibleMs
  }

  setActive(active: boolean): void {
    if (active) {
      this.cancelHide()
      if (this.visible || this.showTimer >= 0) {
        return
      }
      this.showTimer = setTimeout(() => {
        this.showTimer = -1
        this.visible = true
        this.shownAt = Date.now()
      }, this.delayMs)
      return
    }
    if (this.showTimer >= 0) {
      clearTimeout(this.showTimer)
      this.showTimer = -1
      return
    }
    if (!this.visible || this.hideTimer >= 0) {
      return
    }
    const remaining: number = this.minVisibleMs - (Date.now() - this.shownAt)
    if (remaining <= 0) {
      this.visible = false
      return
    }
    this.hideTimer = setTimeout(() => {
      this.hideTimer = -1
      this.visible = false
    }, remaining)
  }

  hideImmediately(): void {
    this.cancelTimers()
    this.visible = false
  }

  dispose(): void {
    this.cancelTimers()
  }

  private cancelHide(): void {
    if (this.hideTimer >= 0) {
      clearTimeout(this.hideTimer)
      this.hideTimer = -1
    }
  }

  private cancelTimers(): void {
    if (this.showTimer >= 0) {
      clearTimeout(this.showTimer)
      this.showTimer = -1
    }
    this.cancelHide()
  }
}
