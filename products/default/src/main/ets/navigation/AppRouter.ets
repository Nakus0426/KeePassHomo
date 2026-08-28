import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { UIObserver, uiObserver } from '@kit.ArkUI'
import { AppUtil, LogUtil, ToastUtil } from '@pura/harmony-utils'
import {
  ROUTE_CREATE_VAULT,
  ROUTE_FILE_SUMMARY,
  ROUTE_GENERATOR,
  ROUTE_SECURITY,
  ROUTE_SETTINGS,
  ROUTE_UNLOCK,
  ROUTE_VAULT,
  ROUTE_WELCOME,
} from '../constants/RouteConstants'

const ROOT_BACK_CONFIRM_INTERVAL_MS: number = 2000
const ROOT_BACK_TOAST_DURATION_MS: number = 2000

/**
 * setStack 使用的路由目标描述。
 */
export interface RouteTarget {
  name: string
  param?: Object
}

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
   * 清空路由栈并压入新的根页面，用于模块切换、登录态切换等整栈重建场景。
   */
  resetTo(route: string, param?: Object, animated: boolean = false): void {
    this.stack.clear()
    this.stack.pushPathByName(route, param, animated)
  }

  /**
   * 清空路由栈并按序重建多层页面，同帧完成避免中间转场闪烁。
   */
  setStack(targets: RouteTarget[]): void {
    this.stack.clear()
    for (const target of targets) {
      this.stack.pushPathByName(target.name, target.param)
    }
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

  isModuleRoute(): boolean {
    return this.currentRoute === ROUTE_VAULT || this.currentRoute === ROUTE_SECURITY ||
      this.currentRoute === ROUTE_GENERATOR || this.currentRoute === ROUTE_SETTINGS
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
        ToastUtil.showToast($r('app.string.press_back_again_to_background'), {
          duration: ROOT_BACK_TOAST_DURATION_MS,
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
