import { common } from '@kit.AbilityKit'
import {
  AppErrorFactory,
  AppErrorModel,
  VaultEngineError,
  VaultEngineErrorCategory,
  VaultEntry,
  VaultEntryInput,
  VaultFormat,
  VaultGroup,
  VaultRepositoryError,
  VaultRepositoryErrorCategory,
  VaultSource,
} from '@ohos/common'
import { formatISO9075 } from '@wolfx/date-fns'
import { FileUtil, LogUtil } from '@pura/harmony-utils'
import {
  ROUTE_CREATE_VAULT,
  ROUTE_ENTRY_DETAIL,
  ROUTE_FILE_SUMMARY,
  ROUTE_GENERATOR,
  ROUTE_UNLOCK,
  ROUTE_VAULT,
  ROUTE_WELCOME,
} from '../constants/RouteConstants'
import { stageOneVaultStore, UserCancelledError, VaultFileSummary } from '../model/StageOneVaultStore'
import { appSessionState } from '../state/AppSessionState'
import { appRouter } from '../navigation/AppRouter'
import { EntryDetailParam } from '../navigation/RouteParams'
import { EntryEditorViewModel } from './EntryEditorViewModel'
import { vaultHomeViewModel } from './VaultHomeViewModel'
import { GeneratorViewModel } from './GeneratorViewModel'
import { VaultSessionViewModel } from './VaultSessionViewModel'

/**
 * 应用级会话 ViewModel：持有应用生命周期、锁定流程、解锁封禁策略、
 * 文件来源流程与剪贴板/错误管道。表单与编辑状态归属各自页面域 ViewModel，
 * 浏览状态归属 VaultHomeViewModel。
 */
@ObservedV2
export class AppViewModel {
  @Trace busy: boolean = false
  @Trace status: string = ''
  @Trace lastError: AppErrorModel | undefined = undefined
  @Trace splashTimedOut: boolean = false
  @Trace fileSummary: VaultFileSummary | undefined = undefined
  @Trace unlockFailures: number = 0
  @Trace unlockBlocked: boolean = false
  @Trace revision: number = 0
  readonly generator: GeneratorViewModel = new GeneratorViewModel()
  readonly session: VaultSessionViewModel = new VaultSessionViewModel()

  private splashTimer: number = -1

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.setStatus('')
    this.splashTimedOut = false
    this.splashTimer = setTimeout(() => this.splashTimedOut = true, 8000)
    try {
      await stageOneVaultStore.initialize(context)
      this.refreshVault()
      const initialRoute: string = stageOneVaultStore.hasRecentVault ? ROUTE_UNLOCK : ROUTE_WELCOME
      setTimeout(() => appRouter.resetTo(initialRoute), 0)
    } catch (error) {
      this.reportBoundaryError('应用初始化失败，请重新启动应用', error)
      this.splashTimedOut = true
    } finally {
      clearTimeout(this.splashTimer)
      appSessionState.privacyCovered = false
    }
  }

  dispose(): void {
    clearTimeout(this.splashTimer)
    this.session.dispose()
  }

  switchModule(route: string): void {
    if (appRouter.currentRoute === route && appRouter.stack.size() > 0) {
      return
    }
    if (appRouter.currentRoute === ROUTE_GENERATOR) {
      this.generator.clearSensitiveState()
    }
    appSessionState.setCurrentModule(route)
    appRouter.resetTo(route)
    if (route === ROUTE_GENERATOR) {
      this.generator.regenerate()
    }
    this.recordActivity()
  }

  async chooseLocalVault(): Promise<void> {
    this.busy = true
    try {
      this.fileSummary = await stageOneVaultStore.chooseLocalVault()
      this.refreshVault()
      // 已在摘要页（重选文件场景）不重复入栈，fileSummary 更新即刷新当前页
      const pathNames: Array<string> = appRouter.stack.getAllPathName()
      const stackTop: string | undefined = pathNames[pathNames.length - 1]
      if (stackTop !== ROUTE_FILE_SUMMARY) {
        appRouter.push(ROUTE_FILE_SUMMARY)
      }
      this.setStatus('')
    } catch (error) {
      this.reportBoundaryError('打开本地 KDBX 失败', error)
    } finally {
      this.busy = false
    }
  }

  async chooseKeyFile(): Promise<void> {
    try {
      await stageOneVaultStore.chooseKeyFile()
      this.refreshVault()
      this.setStatus('')
    } catch (error) {
      this.reportBoundaryError('选择密钥文件失败', error)
    }
  }

  openCreateVault(): void {
    stageOneVaultStore.clearKeyFile()
    this.refreshVault()
    appRouter.push(ROUTE_CREATE_VAULT)
    this.setStatus('')
  }

  openUnlock(): void {
    appRouter.push(ROUTE_UNLOCK)
    this.setStatus('')
  }

  showWebDavPending(): void {
    this.setStatus('此来源将在 WebDAV 阶段开放')
  }

  chooseAnotherVault(): void {
    stageOneVaultStore.clearKeyFile()
    this.refreshVault()
    appRouter.push(ROUTE_WELCOME)
    this.setStatus('')
  }

  async createVault(vaultName: string, masterPassword: string): Promise<void> {
    this.busy = true
    try {
      await stageOneVaultStore.createVault(vaultName.trim(), masterPassword)
      this.refreshVault()
      this.session.markUnlocked()
      appSessionState.setCurrentModule(ROUTE_VAULT)
      appRouter.resetTo(ROUTE_VAULT)
      this.setStatus('')
    } catch (error) {
      if (error instanceof UserCancelledError) {
        this.setStatus('')
        return
      }
      this.reportBoundaryError('创建保险库失败', error)
    } finally {
      this.busy = false
    }
  }

  async unlockVault(password: string): Promise<void> {
    if (password.length === 0 || this.unlockBlocked) {
      return
    }
    this.busy = true
    try {
      await stageOneVaultStore.unlock(password)
      this.unlockFailures = 0
      this.refreshVault()
      this.session.markUnlocked()
      appSessionState.setCurrentModule(ROUTE_VAULT)
      appRouter.resetTo(ROUTE_VAULT)
      this.setStatus('')
    } catch (error) {
      LogUtil.error('保险库解锁失败')
      const repositoryError: VaultRepositoryError = error as VaultRepositoryError
      if (repositoryError.category === VaultRepositoryErrorCategory.NotFound ||
        repositoryError.category === VaultRepositoryErrorCategory.PermissionDenied) {
        this.reportBoundaryError('保险库解锁失败，请重试', error)
        return
      }
      const engineError: VaultEngineError = error as VaultEngineError
      if (engineError.category === VaultEngineErrorCategory.InvalidCredential) {
        this.unlockFailures++
        this.reportBoundaryError('保险库解锁失败，请重试', error)
        this.applyUnlockDelay()
        return
      }
      this.reportBoundaryError('保险库解锁失败，请重试', error)
    } finally {
      this.busy = false
    }
  }

  prepareGenerator(): void {
    this.generator.status = ''
    this.generator.regenerate()
    this.recordActivity()
  }

  async upgradeLegacyVault(): Promise<void> {
    this.busy = true
    try {
      const backupName: string = await stageOneVaultStore.backupAndUpgrade()
      this.fileSummary = {
        name: stageOneVaultStore.currentSource.displayName,
        format: VaultFormat.Kdbx4,
        size: this.fileSummary?.size ?? 0,
        modifiedAt: Date.now() / 1000,
        readOnly: false,
      }
      this.refreshVault()
      this.setStatus(`已升级为 KDBX 4，备份文件：${backupName}`)
      this.recordActivity()
    } catch (error) {
      this.reportBoundaryError('KDBX 3.1 升级失败', error)
    } finally {
      this.busy = false
    }
  }

  loadNewEntry(editor: EntryEditorViewModel): void {
    editor.reset()
    editor.groupUuid = stageOneVaultStore.defaultGroupUuid()
    editor.initialValue = editor.currentValue()
    this.recordActivity()
  }

  loadEntryForEdit(editor: EntryEditorViewModel, entryUuid: string): void {
    const entry: VaultEntry = stageOneVaultStore.entry(entryUuid)
    editor.reset()
    editor.entryUuid = entry.uuid
    editor.title = entry.title
    editor.groupUuid = entry.groupUuid
    editor.username = stageOneVaultStore.field(entry, 'UserName')
    editor.password = stageOneVaultStore.field(entry, 'Password')
    editor.url = stageOneVaultStore.field(entry, 'URL')
    editor.notes = stageOneVaultStore.field(entry, 'Notes')
    editor.tags = entry.tags.join(', ')
    editor.initialValue = editor.currentValue()
    this.recordActivity()
  }

  async saveEntry(editor: EntryEditorViewModel): Promise<void> {
    if (editor.title.trim().length === 0 || editor.password.length === 0) {
      this.setStatus('请填写标题和密码')
      return
    }
    this.busy = true
    const input: VaultEntryInput = {
      groupUuid: editor.groupUuid,
      title: editor.title.trim(),
      username: editor.username,
      password: editor.password,
      url: editor.url.trim(),
      notes: editor.notes,
      tags: editor.tags.split(',').map((tag: string) => tag.trim())
        .filter((tag: string) => tag.length > 0),
    }
    try {
      const saved: VaultEntry = await stageOneVaultStore.saveEntry(editor.entryUuid, input)
      editor.markSaved()
      this.refreshVault()
      appRouter.resetTo(ROUTE_VAULT)
      const detailParam: EntryDetailParam = { entryUuid: saved.uuid }
      appRouter.push(ROUTE_ENTRY_DETAIL, detailParam)
      this.setStatus('')
      this.recordActivity()
    } catch (error) {
      this.reportBoundaryError('保存条目失败', error)
    } finally {
      this.busy = false
    }
  }

  async toggleFavorite(entryUuid: string): Promise<void> {
    this.busy = true
    try {
      const entry: VaultEntry = stageOneVaultStore.entry(entryUuid)
      await stageOneVaultStore.setFavorite(entry.uuid, !entry.favorite)
      this.refreshVault()
      this.setStatus('')
      this.recordActivity()
    } catch (error) {
      this.reportBoundaryError('更新收藏状态失败', error)
    } finally {
      this.busy = false
    }
  }

  async toggleArchived(entryUuid: string): Promise<void> {
    this.busy = true
    try {
      const entry: VaultEntry = stageOneVaultStore.entry(entryUuid)
      await stageOneVaultStore.setArchived(entry.uuid, !entry.archived)
      this.refreshVault()
      this.setStatus('')
      appRouter.resetTo(ROUTE_VAULT)
      this.recordActivity()
    } catch (error) {
      this.reportBoundaryError('更新归档状态失败', error)
    } finally {
      this.busy = false
    }
  }

  async copyValue(value: string): Promise<void> {
    if (value.length === 0) {
      return
    }
    try {
      await this.session.copyValue(value)
    } catch (error) {
      this.reportBoundaryError('复制失败', error)
    }
  }

  async lockVault(): Promise<void> {
    this.generator.clearSensitiveState()
    try {
      await this.session.lockVault()
    } catch (error) {
      this.reportBoundaryError('锁定时清除剪贴板失败', error)
    }
  }

  recordActivity(): void {
    this.session.recordActivity()
  }

  onVaultLockChanged(): void {
    if (appSessionState.vaultLocked && this.isUnlockedRoute()) {
      vaultHomeViewModel.clear()
      this.generator.clearSensitiveState()
      this.session.onVaultLocked()
      appRouter.resetTo(ROUTE_UNLOCK)
    }
  }

  onSensitiveEpochChanged(): void {
    this.generator.clearSensitiveState()
  }

  onForegroundEpochChanged(): void {
    const locked: boolean = this.session.onForeground()
    this.refreshVault()
    if (locked && this.isUnlockedRoute()) {
      appRouter.resetTo(ROUTE_UNLOCK)
    }
    appSessionState.privacyCovered = false
  }

  @Computed
  get clipboardSeconds(): number {
    return this.session.clipboardSeconds
  }

  formatSize(size: number): string {
    return FileUtil.getFormatFileSize(size, 1)
  }

  formatName(format: VaultFormat): string {
    return format === VaultFormat.Kdbx31 ? 'KDBX 3.1' : 'KDBX 4.x'
  }

  formatTime(time: number): string {
    return formatISO9075(new Date(time))
  }

  hasRecentVault(): boolean {
    this.revision
    return stageOneVaultStore.hasRecentVault
  }

  currentSource(): VaultSource {
    this.revision
    return stageOneVaultStore.currentSource
  }

  currentKeyFileName(): string {
    this.revision
    return stageOneVaultStore.currentKeyFileName
  }

  currentKeyFileUri(): string {
    this.revision
    return stageOneVaultStore.currentKeyFileUri
  }

  currentFormat(): VaultFormat {
    this.revision
    return stageOneVaultStore.currentFormat
  }

  groups(): VaultGroup[] {
    this.revision
    return stageOneVaultStore.groups()
  }

  entry(entryUuid: string): VaultEntry {
    this.revision
    return stageOneVaultStore.entry(entryUuid)
  }

  field(entry: VaultEntry, key: string): string {
    this.revision
    return stageOneVaultStore.field(entry, key)
  }

  private setStatus(message: string): void {
    this.status = message
    this.lastError = undefined
  }

  private applyUnlockDelay(): void {
    const delay: number = Math.min(this.unlockFailures, 5) * 1000
    this.unlockBlocked = true
    setTimeout(() => this.unlockBlocked = false, delay)
  }

  private isUnlockedRoute(): boolean {
    return appRouter.currentRoute !== '' && appRouter.currentRoute !== ROUTE_WELCOME &&
      appRouter.currentRoute !== ROUTE_CREATE_VAULT && appRouter.currentRoute !== ROUTE_FILE_SUMMARY &&
      appRouter.currentRoute !== ROUTE_UNLOCK
  }

  private refreshVault(): void {
    this.revision++
    vaultHomeViewModel.invalidate()
  }

  private reportBoundaryError(operation: string, error: Object): void {
    const appError: AppErrorModel = AppErrorFactory.from(error, operation)
    this.lastError = appError
    this.status = appError.message
    LogUtil.error(`${operation}，错误分类=${appError.category}，错误码=${appError.logCode}`)
  }
}

/**
 * 应用级单例：与 AppShell 同生命周期的全局会话 ViewModel。
 */
export const appViewModel: AppViewModel = new AppViewModel()
