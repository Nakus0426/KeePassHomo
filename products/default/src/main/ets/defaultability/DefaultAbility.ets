import { ConfigurationConstant, UIAbility } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { Logger } from '@ohos/common'

const logger: Logger = new Logger()

export default class DefaultAbility extends UIAbility {
  onCreate(): void {
    AppStorage.setOrCreate<boolean>('privacyCovered', true)
    AppStorage.setOrCreate<boolean>('vaultLocked', true)
    AppStorage.setOrCreate<number>('sensitiveEpoch', 0)
    AppStorage.setOrCreate<number>('foregroundEpoch', 0)
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
    AppStorage.set<boolean>('privacyCovered', true)
    AppStorage.set<number>('foregroundEpoch', (AppStorage.get<number>('foregroundEpoch') as number) + 1)
  }

  onBackground(): void {
    AppStorage.set<boolean>('privacyCovered', true)
    AppStorage.set<number>('sensitiveEpoch', (AppStorage.get<number>('sensitiveEpoch') as number) + 1)
  }
}
