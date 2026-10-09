import { AppStorageV2 } from '@kit.ArkUI'
import { PreferencesUtil } from '@pura/harmony-utils'

const PREFERENCES_NAME: string = 'app_settings'
const AUTO_LOCK_ENABLED: string = 'auto_lock_enabled'

// 全应用共享单例：消费方通过 @Local 持有后读取，或用 @Monitor 监听
@ObservedV2
export class AppSettingsState {
  @Trace autoLockEnabled: boolean = false

  constructor() {
    this.autoLockEnabled = PreferencesUtil.getSync(AUTO_LOCK_ENABLED, false, PREFERENCES_NAME) as boolean
  }

  setAutoLockEnabled(enabled: boolean): void {
    this.autoLockEnabled = enabled
    PreferencesUtil.putSync(AUTO_LOCK_ENABLED, enabled, PREFERENCES_NAME)
  }
}

export const appSettings: AppSettingsState = AppStorageV2.connect(
  AppSettingsState,
  'appSettings',
  () => new AppSettingsState(),
) as AppSettingsState
