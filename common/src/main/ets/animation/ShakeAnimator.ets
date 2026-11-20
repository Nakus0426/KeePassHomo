import { AnimationTokens } from './AnimationTokens'

const SHAKE_OFFSETS: number[] = [
  -AnimationTokens.SHAKE_OFFSET,
  AnimationTokens.SHAKE_OFFSET,
  -AnimationTokens.SHAKE_OFFSET / 2,
  0,
]

// 校验失败抖动：播放中重复触发被忽略，连续提交不会叠加位移。
@ObservedV2
export class ShakeAnimator {
  @Trace offsetX: number = 0
  private animating: boolean = false

  play(context: UIContext): void {
    if (this.animating) {
      return
    }
    this.animating = true
    this.step(context, 0)
  }

  private step(context: UIContext, index: number): void {
    if (index === SHAKE_OFFSETS.length) {
      this.animating = false
      return
    }
    context.animateTo({
      duration: AnimationTokens.SHAKE_SEGMENT_DURATION,
      curve: AnimationTokens.EASE_STATE,
      onFinish: () => this.step(context, index + 1),
    }, () => {
      this.offsetX = SHAKE_OFFSETS[index]
    })
  }
}
