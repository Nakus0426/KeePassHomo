import { curves } from '@kit.ArkUI'

const SHRINK_SCALE: number = 0.78
const SHRINK_DURATION: number = 90

/**
 * 弹跳动画控制器。
 * 两段式缩放反馈：先收缩至 SHRINK_SCALE，再以弹簧曲线回弹至 1，
 * 配合组件 scale 属性使用，用于图标按钮点击反馈。
 */
@ObservedV2
export class BounceAnimator {
  @Trace scale: number = 1
  private animating: boolean = false

  /**
   * 播放弹跳动画，动画进行中重复调用会被忽略。
   * onShrunk 在收缩到最小点时回调，业务状态切换放在此处。
   */
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
