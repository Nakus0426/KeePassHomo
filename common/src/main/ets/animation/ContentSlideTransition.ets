import { UIContext, UIUtils } from '@kit.ArkUI'
import { AnimationTokens } from './AnimationTokens'

// 起始帧必须独立渲染一帧才能成为动画起点：与 animateTo 写在同一帧时起点会被同步刷新吃掉。
const CONTENT_SLIDE_START_FRAME_DELAY: number = 16
// 位移量取容器实测宽度比例，与 pen「内容横移转场」定义一致。
const CONTENT_SLIDE_OFFSET_RATIO: number = 0.2
// 转场超时须覆盖「起始帧延迟 + 动画时长」，否则 Tabs 会在动画播完前强制结束。
const CONTENT_SLIDE_TIMEOUT_MARGIN: number = 100

// 参与横移的图层状态：位移挂内容层，opacity 与 zIndex 由外层承担。
export interface SlideFrame {
  opacity: number[]
  offsetX: number[]
  zIndex: number[]
}

// 同层内容横移转场：旧内容向反方向滑出并淡出，新内容自切换方向滑入并淡入，两者同程。
// 参数唯一定义处见 pen 公共组件 Band 06；调用方只提供图层状态与容器宽度。
export class ContentSlideTransition {
  // 复位为「activeIndex 可见、其余隐藏且无位移」，供初始渲染与静默替换使用。
  static reset(frame: SlideFrame, activeIndex: number): void {
    for (let index: number = 0; index < frame.opacity.length; index++) {
      const active: boolean = index === activeIndex
      frame.opacity[index] = active ? 1 : 0
      frame.offsetX[index] = 0
      frame.zIndex[index] = active ? 1 : 0
    }
  }

  // Tabs 自定义切换：前进为下标增大。onStartTimer 可选，页面卸载时按需清理起始帧定时器。
  static tabTransition(uiContext: UIContext, frame: SlideFrame, from: number, to: number,
    containerWidth: number, onStartTimer?: (timer: number) => void): TabContentAnimatedTransition {
    if (from === to) {
      return {
        timeout: 0,
        transition: (proxy: TabContentTransitionProxy) => proxy.finishTransition(),
      }
    }
    return {
      timeout: CONTENT_SLIDE_START_FRAME_DELAY + AnimationTokens.STATE_TRANSITION_DURATION + CONTENT_SLIDE_TIMEOUT_MARGIN,
      transition: (proxy: TabContentTransitionProxy) => {
        const timer: number = ContentSlideTransition.play(uiContext, frame, from, to, to > from ? 1 : -1,
          containerWidth, () => proxy.finishTransition())
        if (onStartTimer !== undefined) {
          onStartTimer(timer)
        }
      },
    }
  }

  // 手动播放：进入下级目录等非 Tabs 场景直接调用，direction 为 1 前进、-1 后退。
  static play(uiContext: UIContext, frame: SlideFrame, from: number, to: number, direction: number,
    containerWidth: number, onFinish: () => void): number {
    const offset: number = containerWidth * CONTENT_SLIDE_OFFSET_RATIO
    UIUtils.applySync(() => {
      frame.opacity[from] = 1
      frame.offsetX[from] = 0
      frame.opacity[to] = 0
      frame.offsetX[to] = direction * offset
      frame.zIndex[from] = 0
      frame.zIndex[to] = 1
    })
    return setTimeout(() => {
      uiContext.animateTo({
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
        onFinish: onFinish,
      }, () => {
        frame.opacity[from] = 0
        frame.offsetX[from] = -direction * offset
        frame.opacity[to] = 1
        frame.offsetX[to] = 0
      })
    }, CONTENT_SLIDE_START_FRAME_DELAY)
  }
}
