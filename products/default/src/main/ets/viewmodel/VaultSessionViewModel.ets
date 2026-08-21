import {
  AppErrorFactory,
  AppErrorModel,
  ClipboardWriteToken,
  Logger,
  ReauthenticationPurpose,
  SecureClipboard,
} from '@ohos/common'
import { stageOneVaultStore } from '../model/StageOneVaultStore'
import { appSessionState } from '../state/AppSessionState'

const AUTO_LOCK_MS: number = 5 * 60 * 1000
const CLIPBOARD_SECONDS: number = 30

@ObservedV2
export class VaultSessionViewModel {
  @Trace clipboardSeconds: number = 0
  private readonly logger: Logger = new Logger()
  private readonly clipboard: SecureClipboard = new SecureClipboard()
  private clipboardToken: ClipboardWriteToken | undefined
  private clipboardTimer: number = -1
  private autoLockTimer: number = -1

  dispose(): void {
    clearTimeout(this.autoLockTimer)
    clearInterval(this.clipboardTimer)
    this.clearClipboardIfOwned().catch((error: Object) => this.logError('退出时清除剪贴板失败', error))
  }

  markUnlocked(): void {
    appSessionState.vaultLocked = false
    this.scheduleAutoLock()
  }

  async copyValue(value: string): Promise<void> {
    await this.clearClipboardIfOwned()
    this.clipboardToken = await this.clipboard.write(value)
    this.clipboardSeconds = CLIPBOARD_SECONDS
    this.clipboardTimer = setInterval(() => {
      this.clipboardSeconds--
      if (this.clipboardSeconds === 0) {
        this.clearClipboardIfOwned()
          .catch((error: Object) => this.logError('到期清除剪贴板失败', error))
      }
    }, 1000)
    this.recordActivity()
  }

  async lockVault(): Promise<void> {
    let clipboardError: Error | undefined
    try {
      await this.clearClipboardIfOwned()
    } catch (error) {
      clipboardError = error as Error
    }
    clearTimeout(this.autoLockTimer)
    stageOneVaultStore.lock()
    appSessionState.vaultLocked = true
    if (clipboardError !== undefined) {
      throw clipboardError
    }
  }

  recordActivity(): void {
    if (stageOneVaultStore.locked) {
      return
    }
    stageOneVaultStore.touch()
    this.scheduleAutoLock()
  }

  onVaultLocked(): void {
    clearTimeout(this.autoLockTimer)
    this.clearClipboardIfOwned()
      .catch((error: Object) => this.logError('锁定时清除剪贴板失败', error))
  }

  onForeground(): boolean {
    stageOneVaultStore.onForeground()
    if (stageOneVaultStore.locked) {
      appSessionState.vaultLocked = true
      return true
    }
    this.scheduleAutoLock()
    return false
  }

  async reauthenticate(_purpose: ReauthenticationPurpose, password: string,
    action: () => Promise<void>): Promise<void> {
    await stageOneVaultStore.reauthenticate(password)
    await action()
    this.recordActivity()
  }

  private async clearClipboardIfOwned(): Promise<void> {
    if (this.clipboardTimer >= 0) {
      clearInterval(this.clipboardTimer)
      this.clipboardTimer = -1
    }
    this.clipboardSeconds = 0
    if (this.clipboardToken === undefined) {
      return
    }
    const token: ClipboardWriteToken = this.clipboardToken
    this.clipboardToken = undefined
    await this.clipboard.clearIfOwned(token)
  }

  private scheduleAutoLock(): void {
    clearTimeout(this.autoLockTimer)
    this.autoLockTimer = setTimeout(() => {
      this.lockVault().catch((error: Object) => this.logError('自动锁定时清除剪贴板失败', error))
    }, AUTO_LOCK_MS)
  }

  private logError(operation: string, error: Object): void {
    const appError: AppErrorModel = AppErrorFactory.from(error, operation)
    this.logger.error(`${operation}，错误分类=${appError.category}，错误码=${appError.logCode}`)
  }
}
