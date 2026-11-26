import { curves } from '@kit.ArkUI'

// 全局动效契约：数值对齐 pen motion token，duration 单位为毫秒。
export class AnimationTokens {
  static readonly DURATION_FAST: number = 150
  static readonly DURATION_FEEDBACK: number = 300
  static readonly DURATION_STRUCTURAL: number = 500
  static readonly DURATION_LOADING_BEAT: number = 455
  static readonly DURATION_LOADING_FADE: number = 240
  static readonly DURATION_LOADING_DELAY: number = 400

  static readonly EASE_STATE: ICurve = curves.cubicBezierCurve(0.2, 0, 0, 1)
  static readonly EASE_ENTER: ICurve = curves.cubicBezierCurve(0, 0, 0, 1)
  static readonly EASE_EXIT: ICurve = curves.cubicBezierCurve(0.3, 0, 0.8, 0.15)

  static readonly STATE_TRANSITION_DURATION: number = AnimationTokens.DURATION_FEEDBACK
  static readonly STATE_TRANSITION_CURVE: ICurve = AnimationTokens.EASE_STATE
  // 反馈态通用动画参数，供 .animation() 直接引用，避免每处重复构造。
  static readonly FEEDBACK_ANIMATION: AnimateParam = {
    duration: AnimationTokens.DURATION_FEEDBACK,
    curve: AnimationTokens.EASE_STATE,
  }
  // 强度条逐段级联：相邻段错开一档填充，避免五段同时闪变。
  static readonly STRENGTH_CASCADE_DELAY: number = 40
  // 智感握姿悬浮按钮：跨侧绕行与首次出场使用官方推荐的弹簧曲线。
  static readonly FAB_SIDE_MOVE_CURVE: ICurve = curves.interpolatingSpring(0, 1, 170, 17)
  static readonly FAB_FIRST_APPEAR_CURVE: ICurve = curves.interpolatingSpring(0, 1, 200, 17)
  static readonly CARD_ENTER_SCALE: number = 0.9
  static readonly CARD_EXIT_SCALE: number = 0.8
  static readonly FAVORITE_PRESS_SCALE: number = 0.88
  static readonly FAVORITE_BOUNCE_SCALE: number = 1.16
  // 解锁分屏外移时首页的开场缩放，与两片外移同帧并行。
  static readonly UNLOCK_HOME_REVEAL_SCALE: number = 0.98
  // 输入框尾随清除按钮显隐的缩放起点：与复选框勾选同一档，出现像被按下弹出。
  static readonly INPUT_CLEAR_SCALE: number = 0.6
  // 底部提示条出现上浮 / 消失下沉距离，单位 vp。
  static readonly BANNER_ENTER_OFFSET: number = 12
  static readonly BANNER_EXIT_OFFSET: number = 8
  // 校验失败抖动：左右各 6vp，四段往复共 300ms，沿用反馈曲线。
  static readonly SHAKE_OFFSET: number = 6
  static readonly SHAKE_DURATION: number = 300
  static readonly SHAKE_SEGMENT_DURATION: number = AnimationTokens.SHAKE_DURATION / 4
  static readonly SHAKE_SEGMENT: AnimateParam = {
    duration: AnimationTokens.SHAKE_SEGMENT_DURATION,
    curve: AnimationTokens.EASE_STATE,
  }
}
