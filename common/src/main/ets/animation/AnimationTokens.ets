import { curves } from '@kit.ArkUI'

// 全局动效契约：数值对齐 pen motion token，duration 单位为毫秒。
export class AnimationTokens {
  static readonly DURATION_FAST: number = 150
  static readonly DURATION_FEEDBACK: number = 300
  static readonly DURATION_STRUCTURAL: number = 500
  static readonly DURATION_LOADING_BEAT: number = 455
  static readonly DURATION_LOADING_FADE: number = 240

  static readonly EASE_STATE: ICurve = curves.cubicBezierCurve(0.2, 0, 0, 1)
  static readonly EASE_ENTER: ICurve = curves.cubicBezierCurve(0, 0, 0, 1)
  static readonly EASE_EXIT: ICurve = curves.cubicBezierCurve(0.3, 0, 0.8, 0.15)

  static readonly STATE_TRANSITION_DURATION: number = AnimationTokens.DURATION_FEEDBACK
  static readonly STATE_TRANSITION_CURVE: ICurve = AnimationTokens.EASE_STATE
  static readonly CARD_ENTER_SCALE: number = 0.9
  static readonly CARD_EXIT_SCALE: number = 0.8
  // 底部提示条出现上浮 / 消失下沉距离，单位 vp。
  static readonly BANNER_ENTER_OFFSET: number = 12
  static readonly BANNER_EXIT_OFFSET: number = 8
}
