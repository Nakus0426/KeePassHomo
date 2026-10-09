import { curves } from '@kit.ArkUI'

const SHRINK_SCALE: number = 0.78
const SHRINK_DURATION: number = 90

@ObservedV2
export class BounceAnimator {
  @Trace scale: number = 1
  private animating: boolean = false

  // 收缩到最小点时回调 onShrunk；动画进行中重复调用被忽略。
  play(context: UIContext, onShrunk?: () => void): void {
    if (this.animating) {
      return
    }
    this.animating = true
    context.animateTo({
      duration: SHRINK_DURATION,
      curve: Curve.EaseIn,
      onFinish: () => {
        onShrunk?.()
        context.animateTo({
          curve: curves.springMotion(0.22, 0.82, 0),
          onFinish: () => {
            this.animating = false
          },
        }, () => {
          this.scale = 1
        })
      },
    }, () => {
      this.scale = SHRINK_SCALE
    })
  }
}
