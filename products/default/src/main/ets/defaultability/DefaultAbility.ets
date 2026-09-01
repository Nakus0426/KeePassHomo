import { Configuration, UIAbility } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { text } from '@kit.ArkGraphics2D'
import { BusinessError } from '@kit.BasicServicesKit'
import { AppUtil, LogUtil } from '@pura/harmony-utils'
import { appSessionState } from '../state/AppSessionState'
import { colorModeState } from '../state/ColorModeState'
import { immersiveLayoutState } from '../state/ImmersiveLayoutState'
import { PASSWORD_FONT_FAMILY } from '../constants/FontConstants'

const LOG_DOMAIN: number = 0xD001
const LOG_TAG: string = 'KeePassHomo'

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
    AppUtil.init(this.context)
    LogUtil.init(LOG_DOMAIN, LOG_TAG)
    appSessionState.onCreate()
    colorModeState.update(this.context.resourceManager.getConfigurationSync().colorMode)
    LogUtil.info('应用创建')
  }

  onDestroy(): void {
    LogUtil.info('应用销毁')
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    colorModeState.update(newConfig.colorMode)
    LogUtil.info(`系统配置变化，深浅色模式：${newConfig.colorMode}`)
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    immersiveLayoutState.reset()
    this.registerPasswordFont()
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        LogUtil.error(`页面加载失败，错误码：${err.code}`)
        return
      }
      const mainWindow: window.Window = windowStage.getMainWindowSync()
      this.mainWindow = mainWindow
      mainWindow.setWindowPrivacyMode(false).catch((privacyError: BusinessError) => {
        LogUtil.error(`隐私模式启用失败，错误码：${privacyError.code}`)
      })
      mainWindow.setWindowLayoutFullScreen(true).then(() => {
        this.initializeAvoidAreas(mainWindow)
        mainWindow.on('avoidAreaChange', this.avoidAreaChangeCallback)
      }).catch((layoutError: BusinessError) => {
        LogUtil.error(`全屏扩展布局启用失败，错误码：${layoutError.code}`)
      })
    })
  }

  onWindowStageDestroy(): void {
    if (this.mainWindow !== undefined) {
      try {
        this.mainWindow.off('avoidAreaChange', this.avoidAreaChangeCallback)
      } catch (error) {
        const businessError: BusinessError = error as BusinessError
        LogUtil.error(`避让区监听注销失败，错误码：${businessError.code}`)
      }
      this.mainWindow = undefined
    }
    immersiveLayoutState.reset()
    LogUtil.info('窗口销毁')
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
      LogUtil.error(`避让区初始化失败，错误码：${businessError.code}`)
    }
  }

  private registerPasswordFont(): void {
    try {
      text.FontCollection.getGlobalInstance().loadFontSyncWithCheck(
        PASSWORD_FONT_FAMILY,
        $rawfile('font/maple_mono_nf_cn_medium.ttf'),
      )
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      LogUtil.error(`密码生成器字体注册失败，错误码=${businessError.code}，错误信息=${businessError.message}`)
    }
  }
}
