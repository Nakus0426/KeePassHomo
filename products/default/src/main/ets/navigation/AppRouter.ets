import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { UIContext } from '@kit.ArkUI'
import { AppUtil, LogUtil } from '@pura/harmony-utils'
import { ROUTE_HOME, ROUTE_UNLOCK } from '../constants/RouteConstants'
import { DsToastHost } from '../components/DsToast'

const ROOT_BACK_CONFIRM_INTERVAL_MS: number = 2000

// 应用内唯一持有 NavPathStack；当前页面一律从栈顶推导，页面无需回写。
export class AppRouter {
  readonly stack: NavPathStack = new NavPathStack()
  private lastBackPressedAt: number = 0
  private lastBackRoute: string = ''
  private homeTransitionPending: boolean = false
  private restoreFadeRoute: string = ''
  private lockEnterPending: boolean = false
  private lockedStack: Array<NavPathInfo> = []

  push(route: string, param?: Object, options?: NavigationOptions): void {
    this.stack.pushPath(new NavPathInfo(route, param), options)
  }

  pop(): void {
    this.stack.pop()
  }

  // 仅供不播动画的整栈重建；同帧清栈+入栈会被系统折叠成净结果（栈变浅），用于跳转必然得到反向动画
  resetTo(route: string, param?: Object, animated: boolean = false): void {
    this.stack.clear(false)
    this.stack.pushPathByName(route, param, animated)
  }

  clearToHome(): void {
    this.lockedStack = []
    this.stack.clear()
    this.homeTransitionPending = true
  }

  // clearToHome 的回首页转场需零时长，否则会露出系统默认的横向滑入残影
  consumeHomeTransition(): boolean {
    if (this.homeTransitionPending) {
      this.homeTransitionPending = false
      return true
    }
    return false
  }

  lockToUnlock(): void {
    // 快照必须早于清栈：解锁成功后要还原到锁定前的页面，而不是回首页
    this.lockedStack = this.stack.getPathStack()
    this.lockEnterPending = true
    this.resetTo(ROUTE_UNLOCK)
  }

  // 解锁成功后还原锁定前的栈。这是还原而非返回，用户不能靠返回键回到锁定前的页面
  restoreAfterUnlock(): void {
    const snapshot: Array<NavPathInfo> = this.lockedStack
    this.lockedStack = []
    if (snapshot.length === 0) {
      this.clearToHome()
      return
    }
    const restored: Array<NavPathInfo> = []
    for (const info of snapshot) {
      restored.push(new NavPathInfo(info.name, info.param))
    }
    this.restoreFadeRoute = restored[restored.length - 1].name
    this.stack.setPathStack(restored, false)
  }

  // 原子页恢复时首页已在分屏外移中露出，栈顶页面自己淡入接上，避免整页瞬切。
  consumeRestoreFade(route: string): boolean {
    if (this.restoreFadeRoute !== route) {
      return false
    }
    this.restoreFadeRoute = ''
    return true
  }

  consumeLockEnter(): boolean {
    if (this.lockEnterPending) {
      this.lockEnterPending = false
      return true
    }
    return false
  }

  isHomePage(): boolean {
    return this.stack.size() === 0
  }

  // 栈顶即当前页面：不依赖导航事件回传，弹窗型子页与 pop 都不会滞留旧值。
  currentRouteName(): string {
    const paths: Array<NavPathInfo> = this.stack.getPathStack()
    return paths.length === 0 ? ROUTE_HOME : paths[paths.length - 1].name
  }

  // 供新压入的页面在 aboutToAppear 中读取栈顶入参
  topParam(): Object | undefined {
    const size: number = this.stack.size()
    if (size === 0) {
      return undefined
    }
    return this.stack.getParamByIndex(size - 1) as Object | undefined
  }

  handleRootBack(route: string): void {
    const now: number = Date.now()
    if (route !== this.lastBackRoute || now - this.lastBackPressedAt > ROOT_BACK_CONFIRM_INTERVAL_MS) {
      this.lastBackPressedAt = now
      this.lastBackRoute = route
      DsToastHost.show(UIContext.resolveUIContext(), $r('app.string.press_back_again_to_background'))
      return
    }
    this.lastBackPressedAt = 0
    this.lastBackRoute = ''
    try {
      const context: common.UIAbilityContext = AppUtil.getContext() as common.UIAbilityContext
      context.moveAbilityToBackground().catch((error: BusinessError) => {
        LogUtil.error(`返回桌面失败，错误码=${error.code}`)
      })
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      LogUtil.error(`返回桌面失败，错误码=${businessError.code}`)
    }
  }
}

export const appRouter: AppRouter = new AppRouter()
