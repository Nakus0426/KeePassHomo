import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { promptAction, uiMaterial, UIObserver, uiObserver } from '@kit.ArkUI'
import { AppUtil, LogUtil } from '@pura/harmony-utils'
import { ROUTE_HOME, ROUTE_UNLOCK } from '../constants/RouteConstants'

const ROOT_BACK_CONFIRM_INTERVAL_MS: number = 2000
const ROOT_BACK_TOAST_DURATION_MS: number = 2000

/**
 * 应用级路由器：唯一持有 NavPathStack，集中提供路由操作；
 * 通过 uiObserver 同步 currentRoute，页面无需手动回写。
 */
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
  private readonly toastMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial(
    { style: uiMaterial.ImmersiveStyle.ULTRA_THICK })

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

  /**
   * 清空路由栈并压入新的根页面，用于登录态切换等整栈重建场景。
   */
  resetTo(route: string, param?: Object, animated: boolean = false): void {
    this.stack.clear()
    this.stack.pushPathByName(route, param, animated)
  }

  /**
   * 清空路由栈回到 Navigation 首页（HdsTabs 所在内容区）；
   * 首页非 NavDestination，需手动标记 currentRoute。
   */
  clearToHome(): void {
    this.stack.clear()
    this.currentRoute = ROUTE_HOME
    this.homeTransitionPending = true
  }

  /**
   * 供 Navigation 转场代理消费：clearToHome 触发的回首页转场需零时长，
   * 否则首页会播系统默认的横向滑入残影；其余转场保持系统默认。
   */
  consumeHomeTransition(): boolean {
    if (this.homeTransitionPending) {
      this.homeTransitionPending = false
      return true
    }
    return false
  }

  /**
   * 锁定保险库后跳转解锁页：标记解锁页播放上下滑入的反向入场动画。
   */
  lockToUnlock(): void {
    this.lockEnterPending = true
    this.resetTo(ROUTE_UNLOCK)
  }

  /**
   * 供解锁页消费：锁定跳转进入时播放入场动画。
   */
  consumeLockEnter(): boolean {
    if (this.lockEnterPending) {
      this.lockEnterPending = false
      return true
    }
    return false
  }

  /**
   * 是否处于 Navigation 首页；以栈深判定，避免 pop 回首页时 currentRoute 滞留旧值。
   */
  isHomePage(): boolean {
    return this.stack.size() === 0
  }

  /**
   * 路由栈存在下层目的地时返回上一页；根级页面据此区分
   * 「返回上一页」与「双击返回桌面」两种行为。
   */
  backToPreviousRoute(): boolean {
    if (this.stack.size() > 1) {
      this.stack.pop()
      return true
    }
    return false
  }

  /**
   * 栈顶路由的入参，供新压入的页面在 aboutToAppear 中读取。
   */
  topParam(): Object | undefined {
    const size: number = this.stack.size()
    if (size === 0) {
      return undefined
    }
    return this.stack.getParamByIndex(size - 1) as Object | undefined
  }

  /**
   * 根级页面系统返回：2 秒内连续两次返回同一根页面时将应用切至后台。
   */
  handleRootBack(route: string): void {
    const now: number = Date.now()
    if (route !== this.lastBackRoute || now - this.lastBackPressedAt > ROOT_BACK_CONFIRM_INTERVAL_MS) {
      this.lastBackPressedAt = now
      this.lastBackRoute = route
      try {
        promptAction.showToast({
          message: $r('app.string.press_back_again_to_background'),
          duration: ROOT_BACK_TOAST_DURATION_MS,
          systemMaterial: this.toastMaterial,
        })
      } catch (error) {
        const businessError: BusinessError = error as BusinessError
        LogUtil.error(`返回桌面提示显示失败，错误码=${businessError.code}`)
      }
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
