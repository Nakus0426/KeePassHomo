import { UIContext, UIUtils } from '@kit.ArkUI'

const FADE_DURATION_MS: number = 300
const FADE_TIMEOUT_MS: number = 400

/**
 * 淡入淡出转场页面回调契约：isEnter 为 true 表示该页进场，false 表示退场。
 */
export interface FadeDestinationCallbacks {
  onFadeStart: (isEnter: boolean) => void
  onFadeFinish: (isEnter: boolean) => void
}

const fadeDestinations: Map<string, FadeDestinationCallbacks> = new Map()

/**
 * 页面在 aboutToAppear 中注册、aboutToDisappear 中注销；以路由名为键。
 */
export function registerFadeDestination(route: string, callbacks: FadeDestinationCallbacks): void {
  fadeDestinations.set(route, callbacks)
}

export function unregisterFadeDestination(route: string): void {
  fadeDestinations.delete(route)
}

/**
 * 供 Navigation 级 customNavContentTransition 代理调用：
 * from 或 to 命中已注册路由时返回透明度转场协议，否则返回 undefined 走系统默认转场。
 */
export function fadeNavTransition(uiContext: UIContext, from: NavContentInfo, to: NavContentInfo):
NavigationAnimatedTransition | undefined {
  const fromCallbacks: FadeDestinationCallbacks | undefined =
    from.name !== undefined ? fadeDestinations.get(from.name) : undefined
  const toCallbacks: FadeDestinationCallbacks | undefined =
    to.name !== undefined ? fadeDestinations.get(to.name) : undefined
  if (fromCallbacks === undefined && toCallbacks === undefined) {
    return undefined
  }
  return {
    timeout: FADE_TIMEOUT_MS,
    transition: (proxy: NavigationTransitionProxy) => {
      // 状态管理 V2 下动画前置状态修改需 applySync 同步刷新，否则起始透明度不生效
      UIUtils.applySync(() => {
        fromCallbacks?.onFadeStart(false)
        toCallbacks?.onFadeStart(true)
      })
      uiContext.animateTo({
        duration: FADE_DURATION_MS,
        curve: Curve.EaseInOut,
        onFinish: () => {
          proxy.finishTransition()
        },
      }, () => {
        fromCallbacks?.onFadeFinish(false)
        toCallbacks?.onFadeFinish(true)
      })
    },
  }
}
