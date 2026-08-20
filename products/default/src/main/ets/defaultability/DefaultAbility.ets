import { ConfigurationConstant, UIAbility } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { Logger } from '@ohos/common'

const logger: Logger = new Logger()

export default class DefaultAbility extends UIAbility {
  onCreate(): void {
    AppStorage.setOrCreate<boolean>('privacyCovered', true)
    logger.info('应用创建')
  }

  onDestroy(): void {
    logger.info('应用销毁')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        logger.error(`页面加载失败，错误码：${err.code}`)
        return
      }
      const mainWindow: window.Window = windowStage.getMainWindowSync()
      mainWindow.setWindowPrivacyMode(true).catch((privacyError: BusinessError) => {
        logger.error(`隐私模式启用失败，错误码：${privacyError.code}`)
      })
    })

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    } catch (err) {
      logger.error('跟随系统颜色模式失败')
    }
  }

  onWindowStageDestroy(): void {
    logger.info('窗口销毁')
  }

  onForeground(): void {
    AppStorage.setOrCreate<boolean>('privacyCovered', false)
  }

  onBackground(): void {
    AppStorage.setOrCreate<boolean>('privacyCovered', true)
  }
}
