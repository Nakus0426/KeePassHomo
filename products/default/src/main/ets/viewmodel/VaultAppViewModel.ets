import { common } from '@kit.AbilityKit'
import {
  AppErrorFactory,
  AppErrorModel,
  custom,
  required,
  stringSchema,
  ValidationSchema,
  ValidationValue,
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
  ROUTE_ENTRY_EDIT,
  ROUTE_FILE_SUMMARY,
  ROUTE_GENERATOR,
  ROUTE_SECURITY,
  ROUTE_SETTINGS,
  ROUTE_UNLOCK,
  ROUTE_VAULT,
  ROUTE_WELCOME,
} from '../constants/RouteConstants'
import { stageOneVaultStore, UserCancelledError, VaultBrowseMode, VaultFileSummary } from '../model/StageOneVaultStore'
import { appSessionState } from '../state/AppSessionState'
import { appRouter } from '../navigation/AppRouter'
import { FormItemController } from '../components/FormItem'
import { GeneratorViewModel } from './GeneratorViewModel'
import { VaultSessionViewModel } from './VaultSessionViewModel'

const PASSWORD_REVEAL_SECONDS: number = 10

@ObservedV2
export class VaultAppViewModel {
  @Trace busy: boolean = false
  @Trace status: string = ''
  @Trace lastError: AppErrorModel | undefined = undefined
  @Trace splashTimedOut: boolean = false
  @Trace fileSummary: VaultFileSummary | undefined = undefined
  @Trace vaultName: string = '个人保险库'
  @Trace masterPassword: string = ''
  @Trace confirmPassword: string = ''
  @Trace unlockPassword: string = ''
  @Trace showUnlockPassword: boolean = false
  @Trace unlockFailures: number = 0
  @Trace unlockBlocked: boolean = false
  @Trace selectedEntryUuid: string = ''
  @Trace editorTitle: string = ''
  @Trace editorUsername: string = ''
  @Trace editorPassword: string = ''
  @Trace editorUrl: string = ''
  @Trace editorNotes: string = ''
  @Trace editorTags: string = ''
  @Trace editorGroupUuid: string = ''
  @Trace editorInitialValue: string = ''
  @Trace showEditorPassword: boolean = false
  @Trace showEntryPassword: boolean = false
  @Trace unsavedDialogVisible: boolean = false
  @Trace searchQuery: string = ''
  @Trace browseMode: VaultBrowseMode = VaultBrowseMode.All
  @Trace selectedGroupUuid: string = ''
  @Trace revision: number = 0
  readonly generator: GeneratorViewModel = new GeneratorViewModel()
  readonly session: VaultSessionViewModel = new VaultSessionViewModel()
  readonly vaultNameController: FormItemController = new FormItemController()
  readonly masterPasswordController: FormItemController = new FormItemController()
  readonly confirmPasswordController: FormItemController = new FormItemController()
  readonly vaultNameSchema: ValidationSchema = stringSchema([required($r('app.string.vault_name_required'))])
  readonly masterPasswordSchema: ValidationSchema = stringSchema([required($r('app.string.master_password_required'))])
  readonly confirmPasswordSchema: ValidationSchema = stringSchema([
    required($r('app.string.confirm_password_required')),
    custom((value: ValidationValue): ResourceStr | undefined =>
    value === this.masterPassword ? undefined : $r('app.string.password_mismatch'), 'confirmMatch'),
  ])

  private splashTimer: number = -1
  private revealTimer: number = -1

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
    clearTimeout(this.revealTimer)
    this.session.dispose()
  }

  setVaultName(value: string): void {
    this.vaultName = value
  }

  setMasterPassword(value: string): void {
    this.masterPassword = value
    if (this.confirmPassword.length > 0) {
      this.confirmPasswordController.validate(this.confirmPassword)
    }
  }

  setConfirmPassword(value: string): void {
    this.confirmPassword = value
  }

  setUnlockPassword(value: string): void {
    this.unlockPassword = value
  }

  setBrowseMode(mode: VaultBrowseMode): void {
    this.browseMode = mode
    this.recordActivity()
  }

  setSearchQuery(value: string): void {
    this.searchQuery = value
    this.recordActivity()
  }

  selectBrowseGroup(groupUuid: string): void {
    this.selectedGroupUuid = groupUuid
    this.recordActivity()
  }

  setEditorTitle(value: string): void {
    this.editorTitle = value
  }

  setEditorUsername(value: string): void {
    this.editorUsername = value
  }

  setEditorPassword(value: string): void {
    this.editorPassword = value
  }

  setEditorUrl(value: string): void {
    this.editorUrl = value
  }

  setEditorNotes(value: string): void {
    this.editorNotes = value
  }

  setEditorTags(value: string): void {
    this.editorTags = value
  }

  setEditorGroup(groupUuid: string): void {
    this.editorGroupUuid = groupUuid
  }

  dismissUnsavedDialog(): void {
    this.unsavedDialogVisible = false
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

  /**
   * 按表单字段顺序执行创建保险库校验，返回首个未通过字段的 key，
   * 全部通过时返回 undefined。
   */
  validateCreateForm(): string | undefined {
    if (!this.vaultNameController.validate(this.vaultName)) {
      return 'vaultName'
    }
    if (!this.masterPasswordController.validate(this.masterPassword)) {
      return 'masterPassword'
    }
    if (!this.confirmPasswordController.validate(this.confirmPassword)) {
      return 'confirmPassword'
    }
    return undefined
  }

  async createVault(): Promise<void> {
    this.busy = true
    try {
      await stageOneVaultStore.createVault(this.vaultName.trim(), this.masterPassword)
      this.clearCredentialInputs()
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

  async unlockVault(): Promise<void> {
    if (this.unlockPassword.length === 0 || this.unlockBlocked) {
      return
    }
    this.busy = true
    try {
      await stageOneVaultStore.unlock(this.unlockPassword)
      this.unlockPassword = ''
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

  fillEditorFromGenerator(): void {
    this.editorPassword = this.generator.value
    this.generator.clearSensitiveState()
    this.recordActivity()
  }

  fillMasterPasswordFromGenerator(): void {
    this.masterPassword = this.generator.value
    this.confirmPassword = this.generator.value
    this.generator.clearSensitiveState()
    this.recordActivity()
  }

  startNewEntry(): void {
    this.selectedEntryUuid = ''
    this.editorTitle = ''
    this.editorUsername = ''
    this.editorPassword = ''
    this.editorUrl = ''
    this.editorNotes = ''
    this.editorTags = ''
    this.editorGroupUuid = stageOneVaultStore.defaultGroupUuid()
    this.editorInitialValue = this.editorValue()
    appRouter.push(ROUTE_ENTRY_EDIT)
    this.recordActivity()
  }

  startEditEntry(): void {
    const entry: VaultEntry = stageOneVaultStore.entry(this.selectedEntryUuid)
    this.editorTitle = entry.title
    this.editorUsername = stageOneVaultStore.field(entry, 'UserName')
    this.editorPassword = stageOneVaultStore.field(entry, 'Password')
    this.editorUrl = stageOneVaultStore.field(entry, 'URL')
    this.editorNotes = stageOneVaultStore.field(entry, 'Notes')
    this.editorTags = entry.tags.join(', ')
    this.editorGroupUuid = entry.groupUuid
    this.editorInitialValue = this.editorValue()
    appRouter.push(ROUTE_ENTRY_EDIT)
    this.recordActivity()
  }

  async saveEntry(): Promise<void> {
    if (this.editorTitle.trim().length === 0 || this.editorPassword.length === 0) {
      this.setStatus('请填写标题和密码')
      return
    }
    this.busy = true
    const input: VaultEntryInput = {
      groupUuid: this.editorGroupUuid,
      title: this.editorTitle.trim(),
      username: this.editorUsername,
      password: this.editorPassword,
      url: this.editorUrl.trim(),
      notes: this.editorNotes,
      tags: this.editorTags.split(',').map((tag: string) => tag.trim())
        .filter((tag: string) => tag.length > 0),
    }
    try {
      const saved: VaultEntry = await stageOneVaultStore.saveEntry(this.selectedEntryUuid, input)
      this.selectedEntryUuid = saved.uuid
      this.editorInitialValue = this.editorValue()
      this.clearEditorSensitiveState()
      this.refreshVault()
      appRouter.resetTo(ROUTE_VAULT)
      appRouter.push(ROUTE_ENTRY_DETAIL)
      this.setStatus('')
      this.recordActivity()
    } catch (error) {
      this.reportBoundaryError('保存条目失败', error)
    } finally {
      this.busy = false
    }
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

  visibleEntries(): VaultEntry[] {
    this.revision
    return stageOneVaultStore.browse(this.searchQuery, this.browseMode, this.selectedGroupUuid)
  }

  async toggleFavorite(): Promise<void> {
    this.busy = true
    try {
      const entry: VaultEntry = stageOneVaultStore.entry(this.selectedEntryUuid)
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

  async toggleArchived(): Promise<void> {
    this.busy = true
    try {
      const entry: VaultEntry = stageOneVaultStore.entry(this.selectedEntryUuid)
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

  openEntry(entryUuid: string): void {
    this.selectedEntryUuid = entryUuid
    this.showEntryPassword = false
    appRouter.push(ROUTE_ENTRY_DETAIL)
    this.recordActivity()
  }

  requestEditorExit(): void {
    if (!this.editorChanged()) {
      this.exitEditor()
      return
    }
    this.unsavedDialogVisible = true
  }

  exitEditor(): void {
    this.unsavedDialogVisible = false
    this.clearEditorSensitiveState()
    if (this.selectedEntryUuid.length === 0) {
      appRouter.resetTo(ROUTE_VAULT)
    } else {
      appRouter.pop()
    }
  }

  revealPassword(target: string): void {
    this.hidePasswords()
    if (target === ROUTE_UNLOCK) {
      this.showUnlockPassword = true
    } else if (target === ROUTE_ENTRY_EDIT) {
      this.showEditorPassword = true
    } else if (target === ROUTE_ENTRY_DETAIL) {
      this.showEntryPassword = true
    }
    this.revealTimer = setTimeout(() => this.hidePasswords(), PASSWORD_REVEAL_SECONDS * 1000)
    this.recordActivity()
  }

  hidePasswords(): void {
    this.showUnlockPassword = false
    this.showEditorPassword = false
    this.showEntryPassword = false
    if (this.revealTimer >= 0) {
      clearTimeout(this.revealTimer)
      this.revealTimer = -1
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
    this.hidePasswords()
    this.clearEditorSensitiveState()
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
      this.hidePasswords()
      this.searchQuery = ''
      this.selectedGroupUuid = ''
      this.clearEditorSensitiveState()
      this.clearCredentialInputs()
      this.generator.clearSensitiveState()
      this.session.onVaultLocked()
      appRouter.resetTo(ROUTE_UNLOCK)
    }
  }

  onSensitiveEpochChanged(): void {
    this.hidePasswords()
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

  passwordStrength(): Resource {
    if (this.masterPassword.length >= 16) {
      return $r('app.string.password_strong')
    }
    if (this.masterPassword.length >= 10) {
      return $r('app.string.password_medium')
    }
    return $r('app.string.password_weak')
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

  entries(): VaultEntry[] {
    this.revision
    return stageOneVaultStore.entries()
  }

  entry(entryUuid: string): VaultEntry {
    this.revision
    return stageOneVaultStore.entry(entryUuid)
  }

  field(entry: VaultEntry, key: string): string {
    this.revision
    return stageOneVaultStore.field(entry, key)
  }

  private applyUnlockDelay(): void {
    const delay: number = Math.min(this.unlockFailures, 5) * 1000
    this.unlockBlocked = true
    setTimeout(() => this.unlockBlocked = false, delay)
  }

  private editorChanged(): boolean {
    return this.editorInitialValue !== this.editorValue()
  }

  private editorValue(): string {
    return [this.editorTitle, this.editorUsername, this.editorPassword, this.editorUrl,
      this.editorNotes, this.editorTags, this.editorGroupUuid].join('\n')
  }

  private clearCredentialInputs(): void {
    this.masterPassword = ''
    this.confirmPassword = ''
    this.unlockPassword = ''
  }

  private clearEditorSensitiveState(): void {
    this.editorPassword = ''
    this.editorInitialValue = ''
    this.showEditorPassword = false
    this.unsavedDialogVisible = false
  }

  private isUnlockedRoute(): boolean {
    return appRouter.currentRoute !== '' && appRouter.currentRoute !== ROUTE_WELCOME &&
      appRouter.currentRoute !== ROUTE_CREATE_VAULT && appRouter.currentRoute !== ROUTE_FILE_SUMMARY &&
      appRouter.currentRoute !== ROUTE_UNLOCK
  }

  private refreshVault(): void {
    this.revision++
  }

  private setStatus(message: string): void {
    this.status = message
    this.lastError = undefined
  }

  private reportBoundaryError(operation: string, error: Object): void {
    const appError: AppErrorModel = AppErrorFactory.from(error, operation)
    this.lastError = appError
    this.status = appError.message
    LogUtil.error(`${operation}，错误分类=${appError.category}，错误码=${appError.logCode}`)
  }
}

/**
 * 应用级单例：与 AppShell 同生命周期的全局 ViewModel，各页面直接引用。
 */
export const vaultAppViewModel: VaultAppViewModel = new VaultAppViewModel()
