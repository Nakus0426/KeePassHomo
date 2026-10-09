import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { UIContext, UIObserver, uiObserver } from '@kit.ArkUI'
import { AppUtil, LogUtil } from '@pura/harmony-utils'
import { AppToast } from '@ohos/common'
import { ROUTE_HOME, ROUTE_UNLOCK } from '../constants/RouteConstants'

const ROOT_BACK_CONFIRM_INTERVAL_MS: number = 2000
const ROOT_BACK_TOAST_DURATION_MS: number = 2000

// 应用内唯一持有 NavPathStack；currentRoute 由 uiObserver 自动同步，页面无需回写
@ObservedV2
export class AppRouter {
  @Trace currentRoute: string = ''
  readonly stack: NavPathStack = new NavPathStack()
  private readonly onNavDestinationUpdate: (info: uiObserver.NavDestinationInfo) => void =
    (info: uiObserver.NavDestinationInfo): void => {
      if (info.state === uiObserver.NavDestinationState.ON_SHOWN) {
        this.currentRoute = info.name as string
      }
    }
  private lastBackPressedAt: number = 0
  private lastBackRoute: string = ''
  private homeTransitionPending: boolean = false
  private lockEnterPending: boolean = false

  attach(observer: UIObserver): void {
    observer.on('navDestinationUpdate', this.onNavDestinationUpdate)
  }

  detach(observer: UIObserver): void {
    observer.off('navDestinationUpdate', this.onNavDestinationUpdate)
  }

  push(route: string, param?: Object): void {
    this.stack.pushPathByName(route, param)
  }

  pop(): void {
    this.stack.pop()
  }

  resetTo(route: string, param?: Object, animated: boolean = false): void {
    this.stack.clear()
    this.stack.pushPathByName(route, param, animated)
  }

  // 首页不是 NavDestination，uiObserver 收不到事件，需手动标记 currentRoute
  clearToHome(): void {
    this.stack.clear()
    this.currentRoute = ROUTE_HOME
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
    this.lockEnterPending = true
    this.resetTo(ROUTE_UNLOCK)
  }

  consumeLockEnter(): boolean {
    if (this.lockEnterPending) {
      this.lockEnterPending = false
      return true
    }
    return false
  }

  // 以栈深判定：pop 回首页时 currentRoute 会滞留旧值
  isHomePage(): boolean {
    return this.stack.size() === 0
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
      AppToast.show(UIContext.resolveUIContext(), $r('app.string.press_back_again_to_background'),
        ROOT_BACK_TOAST_DURATION_MS)
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
