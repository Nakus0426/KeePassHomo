import { ConfigurationConstant, UIAbility } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { Logger } from '@ohos/common'
import { appSessionState } from '../state/AppSessionState'
import { immersiveLayoutState } from '../state/ImmersiveLayoutState'

const logger: Logger = new Logger()

export default class DefaultAbility extends UIAbility {
  private mainWindow: window.Window | undefined = undefined
  private readonly avoidAreaChangeCallback: Callback<window.AvoidAreaOptions> =
    (data: window.AvoidAreaOptions): void => {
      if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
        immersiveLayoutState.setTopAvoidAreaHeight(data.area.topRect.height)
      } else if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
        immersiveLayoutState.setBottomAvoidAreaHeight(data.area.bottomRect.height)
      }
    }

  onCreate(): void {
    appSessionState.onCreate()
    logger.info('应用创建')
  }

  onDestroy(): void {
    logger.info('应用销毁')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    immersiveLayoutState.reset()
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        logger.error(`页面加载失败，错误码：${err.code}`)
        return
      }
      const mainWindow: window.Window = windowStage.getMainWindowSync()
      this.mainWindow = mainWindow
      mainWindow.setWindowPrivacyMode(true).catch((privacyError: BusinessError) => {
        logger.error(`隐私模式启用失败，错误码：${privacyError.code}`)
      })
      mainWindow.setWindowLayoutFullScreen(true).then(() => {
        this.initializeAvoidAreas(mainWindow)
        mainWindow.on('avoidAreaChange', this.avoidAreaChangeCallback)
      }).catch((layoutError: BusinessError) => {
        logger.error(`全屏扩展布局启用失败，错误码：${layoutError.code}`)
      })
    })

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    } catch (err) {
      logger.error('跟随系统颜色模式失败')
    }
  }

  onWindowStageDestroy(): void {
    if (this.mainWindow !== undefined) {
      try {
        this.mainWindow.off('avoidAreaChange', this.avoidAreaChangeCallback)
      } catch (error) {
        const businessError: BusinessError = error as BusinessError
        logger.error(`避让区监听注销失败，错误码：${businessError.code}`)
      }
      this.mainWindow = undefined
    }
    immersiveLayoutState.reset()
    logger.info('窗口销毁')
  }

  onForeground(): void {
    appSessionState.onForeground()
  }

  onBackground(): void {
    appSessionState.onBackground()
  }

  private initializeAvoidAreas(mainWindow: window.Window): void {
    try {
      const systemArea: window.AvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      immersiveLayoutState.setTopAvoidAreaHeight(systemArea.topRect.height)
      const navigationArea: window.AvoidArea = mainWindow.getWindowAvoidArea(
        window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR,
      )
      immersiveLayoutState.setBottomAvoidAreaHeight(navigationArea.bottomRect.height)
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      logger.error(`避让区初始化失败，错误码：${businessError.code}`)
    }
  }
}
