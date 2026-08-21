import { common } from '@kit.AbilityKit'
import { AppErrorModel, Logger, VaultEntry, VaultFormat, VaultGroup, VaultSource } from '@ohos/common'
import { VaultBrowseMode, VaultFileSummary } from '../model/StageOneVaultStore'
import { GeneratorViewModel } from './GeneratorViewModel'
import { VaultSessionViewModel } from './VaultSessionViewModel'

const PASSWORD_REVEAL_SECONDS: number = 10

@ObservedV2
export class VaultAppViewModel {
  @Trace currentRoute: string = ''
  @Trace busy: boolean = false
  @Trace status: string = ''
  @Trace lastError: AppErrorModel | undefined = undefined
  @Trace splashTimedOut: boolean = false
  @Trace fileSummary: VaultFileSummary | undefined = undefined
  @Trace vaultName: string = '个人保险库'
  @Trace createFileName: string = ''
  @Trace masterPassword: string = ''
  @Trace confirmPassword: string = ''
  @Trace generatedMasterPassword: boolean = false
  @Trace generatedPasswordSaved: boolean = false
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
  readonly navPathStack: NavPathStack = new NavPathStack()
  private readonly logger: Logger = new Logger()
  private splashTimer: number = -1
  private revealTimer: number = -1

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.currentRoute = ''
    this.setStatus('')
    this.splashTimedOut = false
    this.splashTimer = setTimeout(() => this.splashTimedOut = true, 8000)
    try {
      await stageOneVaultStore.initialize(context)
      this.refreshVault()
      const initialRoute: string = stageOneVaultStore.hasRecentVault ? ROUTE_UNLOCK : ROUTE_WELCOME
      setTimeout(() => this.resetRoute(initialRoute), 0)
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

  resetRoute(route: string, animated: boolean = false): void {
    this.navPathStack.clear()
    this.currentRoute = route
    this.navPathStack.pushPathByName(route, undefined, animated)
  }

  pushRoute(route: string): void {
    this.currentRoute = route
    this.navPathStack.pushPathByName(route, undefined)
  }

  popRoute(): void {
    this.navPathStack.pop()
  }

  showRoute(route: string): void {
    this.currentRoute = route
  }

  setVaultName(value: string): void {
    this.vaultName = value
  }

  setMasterPassword(value: string): void {
    this.masterPassword = value
    this.generatedMasterPassword = false
  }

  setConfirmPassword(value: string): void {
    this.confirmPassword = value
  }

  setGeneratedPasswordSaved(value: boolean): void {
    this.generatedPasswordSaved = value
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
    if (this.currentRoute === route && this.navPathStack.size() > 0) {
      return
    }
    if (this.currentRoute === ROUTE_GENERATOR) {
      this.generator.clearSensitiveState()
    }
    appSessionState.setCurrentModule(route)
    this.resetRoute(route, false)
    if (route === ROUTE_GENERATOR) {
      this.generator.regenerate()
    }
    this.recordActivity()
  }

  isModuleRoute(): boolean {
    return this.currentRoute === ROUTE_VAULT || this.currentRoute === ROUTE_SECURITY ||
      this.currentRoute === ROUTE_GENERATOR || this.currentRoute === ROUTE_SETTINGS
  }

  async chooseCreateLocation(): Promise<void> {
    const name: string = this.vaultName.trim().length === 0 ? '个人保险库' : this.vaultName.trim()
    try {
      this.createFileName = await stageOneVaultStore.chooseCreateLocation(name)
      this.setStatus('')
    } catch (error) {
      this.reportBoundaryError('选择保存位置失败', error)
    }
  }

  async chooseLocalVault(): Promise<void> {
    this.busy = true
    try {
      this.fileSummary = await stageOneVaultStore.chooseLocalVault()
      this.refreshVault()
      this.pushRoute(ROUTE_FILE_SUMMARY)
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
    this.pushRoute(ROUTE_CREATE_VAULT)
    this.setStatus('')
  }

  showWebDavPending(): void {
    this.setStatus('此来源将在 WebDAV 阶段开放')
  }

  chooseAnotherVault(): void {
    stageOneVaultStore.clearKeyFile()
    this.refreshVault()
    this.resetRoute(ROUTE_WELCOME)
    this.setStatus('')
  }

  async createVault(): Promise<void> {
    if (this.vaultName.trim().length === 0 || this.createFileName.length === 0 || this.masterPassword.length === 0) {
      this.setStatus('请填写库名、选择保存位置并输入主密码')
      return
    }
    if (this.masterPassword !== this.confirmPassword) {
      this.setStatus('两次输入的主密码不一致')
      return
    }
    if (this.generatedMasterPassword && !this.generatedPasswordSaved) {
      this.setStatus('请确认已妥善保存生成的主密码')
      return
    }
    this.busy = true
    try {
      await stageOneVaultStore.createVault(this.vaultName.trim(), this.masterPassword)
      this.clearCredentialInputs()
      this.refreshVault()
      this.session.markUnlocked()
      appSessionState.setCurrentModule(ROUTE_VAULT)
      this.resetRoute(ROUTE_VAULT)
      this.setStatus('')
    } catch (error) {
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
      this.resetRoute(ROUTE_VAULT)
      this.setStatus('')
    } catch (error) {
      this.logger.error('保险库解锁失败')
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

  generateMasterPassword(): void {
    try {
      const password: string = this.generator.generateMasterPassword()
      this.masterPassword = password
      this.confirmPassword = password
      this.generatedMasterPassword = true
      this.generatedPasswordSaved = false
    } catch (error) {
      this.reportBoundaryError('生成主密码失败', error)
    }
  }

  prepareEditorGenerator(): void {
    this.generator.status = ''
    this.generator.regenerate()
    this.recordActivity()
  }

  fillEditorFromGenerator(): void {
    this.editorPassword = this.generator.value
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
    this.pushRoute(ROUTE_ENTRY_EDIT)
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
    this.pushRoute(ROUTE_ENTRY_EDIT)
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
      this.resetRoute(ROUTE_VAULT, false)
      this.pushRoute(ROUTE_ENTRY_DETAIL)
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
      this.resetRoute(ROUTE_VAULT)
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
    this.pushRoute(ROUTE_ENTRY_DETAIL)
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
      this.resetRoute(ROUTE_VAULT)
    } else {
      this.popRoute()
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
      this.resetRoute(ROUTE_UNLOCK)
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
      this.resetRoute(ROUTE_UNLOCK)
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
    if (size < 1024) {
      return `${size} B`
    }
    return `${(size / 1024).toFixed(1)} KB`
  }

  formatName(format: VaultFormat): string {
    return format === VaultFormat.Kdbx31 ? 'KDBX 3.1' : 'KDBX 4.x'
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
    this.generatedPasswordSaved = false
    this.generatedMasterPassword = false
  }

  private clearEditorSensitiveState(): void {
    this.editorPassword = ''
    this.editorInitialValue = ''
    this.showEditorPassword = false
    this.unsavedDialogVisible = false
  }

  private isUnlockedRoute(): boolean {
    return this.currentRoute !== '' && this.currentRoute !== ROUTE_WELCOME &&
      this.currentRoute !== ROUTE_CREATE_VAULT && this.currentRoute !== ROUTE_FILE_SUMMARY &&
      this.currentRoute !== ROUTE_UNLOCK
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
    this.logger.error(`${operation}，错误分类=${appError.category}，错误码=${appError.logCode}`)
  }
}
