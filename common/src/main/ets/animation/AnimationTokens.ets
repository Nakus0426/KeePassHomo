/**
 * 应用级动画 Token：统一状态过渡动画的时长与曲线。
 * 供属性动画（.animation()）等状态过渡场景复用，保证全局过渡体验一致。
 */
export class AnimationTokens {
  /** 状态过渡时长（毫秒） */
  static readonly STATE_TRANSITION_DURATION: number = 300
  /** 状态过渡曲线 */
  static readonly STATE_TRANSITION_CURVE: Curve = Curve.EaseInOut
}
