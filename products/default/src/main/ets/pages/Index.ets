import { common } from '@kit.AbilityKit'
import { uiMaterial } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import {
  ClipboardWriteToken,
  Logger,
  MemorableCase,
  MemorablePasswordOptions,
  PasswordGenerator,
  PasswordStrength,
  PinOptions,
  RandomPasswordOptions,
  SecureClipboard,
  VaultEngineError,
  VaultEngineErrorCategory,
  VaultEntry,
  VaultEntryInput,
  VaultFormat,
  VaultRepositoryError,
  VaultGroup,
  VaultRepositoryErrorCategory,
} from '@ohos/common'
import {
  ROUTE_CREATE_VAULT,
  ROUTE_ENTRY_DETAIL,
  ROUTE_ENTRY_EDIT,
  ROUTE_FILE_SUMMARY,
  ROUTE_GENERATOR,
  ROUTE_SECURITY,
  ROUTE_SETTINGS,
  ROUTE_TEMPLATE,
  ROUTE_UNLOCK,
  ROUTE_VAULT,
  ROUTE_WELCOME,
} from '../constants/RouteConstants'
import { stageOneVaultStore, VaultBrowseMode, VaultFileSummary } from '../model/StageOneVaultStore'

enum GeneratorMode {
  Random,
  Memorable,
  Pin,
}

const AUTO_LOCK_MS: number = 5 * 60 * 1000
const PASSWORD_REVEAL_SECONDS: number = 10
const CLIPBOARD_SECONDS: number = 30

@Entry
@Component
struct Index {
  @StorageLink('privacyCovered') private privacyCovered: boolean = true
  @StorageLink('vaultLocked') @Watch('onVaultLockChanged') private vaultLocked: boolean = true
  @StorageLink('sensitiveEpoch') @Watch('onSensitiveEpochChanged') private sensitiveEpoch: number = 0
  @StorageLink('foregroundEpoch') @Watch('onForegroundEpochChanged') private foregroundEpoch: number = 0
  @State private currentRoute: string = ''
  @State private busy: boolean = false
  @State private status: string = ''
  @State private splashTimedOut: boolean = false
  @State private fileSummary: VaultFileSummary | undefined = undefined
  @State private vaultName: string = '个人保险库'
  @State private createFileName: string = ''
  @State private masterPassword: string = ''
  @State private confirmPassword: string = ''
  @State private generatedMasterPassword: boolean = false
  @State private generatedPasswordSaved: boolean = false
  @State private unlockPassword: string = ''
  @State private showUnlockPassword: boolean = false
  @State private unlockFailures: number = 0
  @State private unlockBlocked: boolean = false
  @State private selectedEntryUuid: string = ''
  @State private editorTitle: string = ''
  @State private editorUsername: string = ''
  @State private editorPassword: string = ''
  @State private editorUrl: string = ''
  @State private editorNotes: string = ''
  @State private editorTags: string = ''
  @State private editorGroupUuid: string = ''
  @State private editorInitialValue: string = ''
  @State private showEditorPassword: boolean = false
  @State private showEntryPassword: boolean = false
  @State private unsavedDialogVisible: boolean = false
  @State private clipboardSeconds: number = 0
  @State private searchQuery: string = ''
  @State private browseMode: VaultBrowseMode = VaultBrowseMode.All
  @State private selectedGroupUuid: string = ''
  @State private generatorMode: GeneratorMode = GeneratorMode.Random
  @State private generatorValue: string = ''
  @State private generatorStatus: string = ''
  @State private generatorReturnToEditor: boolean = false
  @State private randomLength: number = 20
  @State private randomUppercase: boolean = true
  @State private randomLowercase: boolean = true
  @State private randomDigits: boolean = true
  @State private randomSymbols: boolean = true
  @State private randomExcludeSimilar: boolean = true
  @State private randomMinimumDigits: number = 1
  @State private randomMinimumSymbols: number = 1
  @State private memorableWordCount: number = 4
  @State private memorableSeparator: string = '-'
  @State private memorableCase: MemorableCase = MemorableCase.Lower
  @State private memorableAppendNumber: boolean = true
  @State private pinLength: number = 6
  @State private pinAvoidPatterns: boolean = true
  private readonly logger: Logger = new Logger()
  private readonly passwordGenerator: PasswordGenerator = new PasswordGenerator()
  private readonly clipboard: SecureClipboard = new SecureClipboard()
  private readonly navPathStack: NavPathStack = new NavPathStack()
  private readonly navigationMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
    applyShadow: true,
  })
  private readonly navigationItemMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
    interactive: true,
    lightEffect: { color: undefined },
  })
  private clipboardToken: ClipboardWriteToken | undefined
  private splashTimer: number = -1
  private revealTimer: number = -1
  private clipboardTimer: number = -1
  private autoLockTimer: number = -1

  aboutToAppear(): void {
    this.initialize()
  }

  aboutToDisappear(): void {
    this.clearTimers()
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private resetRoute(route: string, animated: boolean = false): void {
    this.navPathStack.clear()
    this.currentRoute = route
    this.navPathStack.pushPathByName(route, undefined, animated)
  }

  private pushRoute(route: string): void {
    this.currentRoute = route
    this.navPathStack.pushPathByName(route, undefined)
  }

  private popRoute(): void {
    this.navPathStack.pop()
  }

  private switchModule(route: string): void {
    if (this.currentRoute === route) {
      return
    }
    if (this.currentRoute === ROUTE_GENERATOR) {
      this.clearGeneratorSensitiveState()
    }
    this.generatorReturnToEditor = false
    this.resetRoute(route, false)
    if (route === ROUTE_GENERATOR) {
      this.regeneratePassword()
    }
    this.recordActivity()
  }

  private isModuleRoute(): boolean {
    return this.currentRoute === ROUTE_VAULT || this.currentRoute === ROUTE_SECURITY ||
      (this.currentRoute === ROUTE_GENERATOR && !this.generatorReturnToEditor) ||
      this.currentRoute === ROUTE_SETTINGS
  }

  private isUnlockedRoute(): boolean {
    return this.currentRoute !== '' && this.currentRoute !== ROUTE_WELCOME &&
      this.currentRoute !== ROUTE_CREATE_VAULT && this.currentRoute !== ROUTE_FILE_SUMMARY &&
      this.currentRoute !== ROUTE_UNLOCK
  }

  private async initialize(): Promise<void> {
    this.currentRoute = ''
    this.status = ''
    this.splashTimedOut = false
    this.splashTimer = setTimeout(() => this.splashTimedOut = true, 8000)
    try {
      await stageOneVaultStore.initialize(this.context())
      const initialRoute: string = stageOneVaultStore.hasRecentVault ? ROUTE_UNLOCK : ROUTE_WELCOME
      setTimeout(() => this.resetRoute(initialRoute), 0)
    } catch (error) {
      this.status = (error as Error).message
      this.splashTimedOut = true
      this.logger.error('阶段 1 初始化失败')
    } finally {
      clearTimeout(this.splashTimer)
      this.privacyCovered = false
    }
  }

  private async chooseCreateLocation(): Promise<void> {
    const name: string = this.vaultName.trim().length === 0 ? '个人保险库' : this.vaultName.trim()
    try {
      this.createFileName = await stageOneVaultStore.chooseCreateLocation(name)
      this.status = ''
    } catch (error) {
      this.reportBoundaryError('选择保存位置失败', error)
    }
  }

  private async chooseLocalVault(): Promise<void> {
    this.busy = true
    try {
      this.fileSummary = await stageOneVaultStore.chooseLocalVault()
      this.pushRoute(ROUTE_FILE_SUMMARY)
      this.status = ''
    } catch (error) {
      this.reportBoundaryError('打开本地 KDBX 失败', error)
    } finally {
      this.busy = false
    }
  }

  private async chooseKeyFile(): Promise<void> {
    try {
      await stageOneVaultStore.chooseKeyFile()
      this.status = ''
    } catch (error) {
      this.reportBoundaryError('选择密钥文件失败', error)
    }
  }

  private async createVault(): Promise<void> {
    if (this.vaultName.trim().length === 0 || this.createFileName.length === 0 || this.masterPassword.length === 0) {
      this.status = '请填写库名、选择保存位置并输入主密码'
      return
    }
    if (this.masterPassword !== this.confirmPassword) {
      this.status = '两次输入的主密码不一致'
      return
    }
    if (this.generatedMasterPassword && !this.generatedPasswordSaved) {
      this.status = '请确认已妥善保存生成的主密码'
      return
    }
    this.busy = true
    try {
      await stageOneVaultStore.createVault(this.vaultName.trim(), this.masterPassword)
      this.clearCredentialInputs()
      this.vaultLocked = false
      this.resetRoute(ROUTE_VAULT)
      this.scheduleAutoLock()
      this.status = ''
    } catch (error) {
      this.reportBoundaryError('创建保险库失败', error)
    } finally {
      this.busy = false
    }
  }

  private async unlockVault(): Promise<void> {
    if (this.unlockPassword.length === 0 || this.unlockBlocked) {
      return
    }
    this.busy = true
    try {
      await stageOneVaultStore.unlock(this.unlockPassword)
      this.unlockPassword = ''
      this.unlockFailures = 0
      this.vaultLocked = false
      this.resetRoute(ROUTE_VAULT)
      this.scheduleAutoLock()
      this.status = ''
    } catch (error) {
      this.logger.error('保险库解锁失败')
      const repositoryError: VaultRepositoryError = error as VaultRepositoryError
      if (repositoryError.category === VaultRepositoryErrorCategory.NotFound
        || repositoryError.category === VaultRepositoryErrorCategory.PermissionDenied) {
        this.status = '保险库文件不存在或授权失效，请重新定位'
        return
      }
      const engineError: VaultEngineError = error as VaultEngineError
      if (engineError.category === VaultEngineErrorCategory.InvalidCredential) {
        this.unlockFailures++
        this.status = '凭据不正确或文件无法解密'
        this.applyUnlockDelay()
        return
      }
      this.status = (error as Error).message
    } finally {
      this.busy = false
    }
  }

  private applyUnlockDelay(): void {
    const delay: number = Math.min(this.unlockFailures, 5) * 1000
    this.unlockBlocked = true
    setTimeout(() => this.unlockBlocked = false, delay)
  }

  private generateMasterPassword(): void {
    try {
      const password: string = this.passwordGenerator.generate()
      this.masterPassword = password
      this.confirmPassword = password
      this.generatedMasterPassword = true
      this.generatedPasswordSaved = false
    } catch (error) {
      this.reportBoundaryError('生成主密码失败', error)
    }
  }

  private randomOptions(): RandomPasswordOptions {
    return {
      length: this.randomLength,
      uppercase: this.randomUppercase,
      lowercase: this.randomLowercase,
      digits: this.randomDigits,
      symbols: this.randomSymbols,
      excludeSimilar: this.randomExcludeSimilar,
      minimumDigits: this.randomMinimumDigits,
      minimumSymbols: this.randomMinimumSymbols,
    }
  }

  private memorableOptions(): MemorablePasswordOptions {
    return {
      wordCount: this.memorableWordCount,
      separator: this.memorableSeparator,
      letterCase: this.memorableCase,
      appendNumber: this.memorableAppendNumber,
    }
  }

  private pinOptions(): PinOptions {
    return {
      length: this.pinLength,
      avoidPatterns: this.pinAvoidPatterns,
    }
  }

  private randomRuleError(): string {
    if (!this.randomUppercase && !this.randomLowercase && !this.randomDigits && !this.randomSymbols) {
      return '请至少启用一种字符类型'
    }
    if (!this.randomDigits && this.randomMinimumDigits > 0) {
      return '最少数字数量大于 0 时必须启用数字'
    }
    if (!this.randomSymbols && this.randomMinimumSymbols > 0) {
      return '最少符号数量大于 0 时必须启用符号'
    }
    let required = this.randomUppercase ? 1 : 0
    required += this.randomLowercase ? 1 : 0
    required += this.randomDigits ? Math.max(1, this.randomMinimumDigits) : 0
    required += this.randomSymbols ? Math.max(1, this.randomMinimumSymbols) : 0
    return required > this.randomLength ? '密码长度不足以满足当前规则' : ''
  }

  private openGenerator(returnToEditor: boolean): void {
    this.generatorReturnToEditor = returnToEditor
    this.generatorStatus = ''
    this.pushRoute(ROUTE_GENERATOR)
    this.regeneratePassword()
    this.recordActivity()
  }

  private setGeneratorMode(mode: GeneratorMode): void {
    this.generatorMode = mode
    this.regeneratePassword()
  }

  private regeneratePassword(): void {
    const ruleError = this.generatorMode === GeneratorMode.Random ? this.randomRuleError() : ''
    if (ruleError.length > 0) {
      this.generatorValue = ''
      this.generatorStatus = ruleError
      return
    }
    try {
      if (this.generatorMode === GeneratorMode.Random) {
        this.generatorValue = this.passwordGenerator.generateRandom(this.randomOptions())
      } else if (this.generatorMode === GeneratorMode.Memorable) {
        this.generatorValue = this.passwordGenerator.generateMemorable(this.memorableOptions())
      } else {
        this.generatorValue = this.passwordGenerator.generatePin(this.pinOptions())
      }
      this.generatorStatus = ''
      this.recordActivity()
    } catch (error) {
      this.generatorValue = ''
      this.generatorStatus = (error as Error).message
      this.logger.error('生成密码失败')
    }
  }

  private generatorStrength(): PasswordStrength {
    if (this.generatorMode === GeneratorMode.Random) {
      if (this.randomRuleError().length > 0) {
        return { label: '规则无效', estimatedBits: 0 }
      }
      return this.passwordGenerator.estimateRandom(this.randomOptions())
    }
    if (this.generatorMode === GeneratorMode.Memorable) {
      return this.passwordGenerator.estimateMemorable(this.memorableOptions())
    }
    return this.passwordGenerator.estimatePin(this.pinOptions())
  }

  private closeGenerator(): void {
    this.generatorValue = ''
    this.generatorStatus = ''
    if (this.generatorReturnToEditor) {
      this.popRoute()
    } else {
      this.switchModule(ROUTE_VAULT)
    }
    this.generatorReturnToEditor = false
  }

  private fillEditorFromGenerator(): void {
    this.editorPassword = this.generatorValue
    this.generatorValue = ''
    this.generatorStatus = ''
    this.generatorReturnToEditor = false
    this.popRoute()
    this.recordActivity()
  }

  private startEntryFromGenerator(): void {
    const password = this.generatorValue
    this.generatorValue = ''
    this.generatorStatus = ''
    this.generatorReturnToEditor = false
    this.startNewEntry()
    this.editorPassword = password
  }

  private startNewEntry(): void {
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

  private startEditEntry(): void {
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

  private async saveEntry(): Promise<void> {
    if (this.editorTitle.trim().length === 0 || this.editorPassword.length === 0) {
      this.status = '请填写标题和密码'
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
      tags: this.editorTags.split(',').map((tag: string) => tag.trim()).filter((tag: string) => tag.length > 0),
    }
    try {
      const saved: VaultEntry = await stageOneVaultStore.saveEntry(this.selectedEntryUuid, input)
      this.selectedEntryUuid = saved.uuid
      this.editorInitialValue = this.editorValue()
      this.clearEditorSensitiveState()
      this.resetRoute(ROUTE_VAULT, false)
      this.pushRoute(ROUTE_ENTRY_DETAIL)
      this.status = ''
      this.recordActivity()
    } catch (error) {
      this.reportBoundaryError('保存条目失败', error)
    } finally {
      this.busy = false
    }
  }

  private async upgradeLegacyVault(): Promise<void> {
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
      this.status = $r('app.string.upgrade_success', backupName).toString()
      this.recordActivity()
    } catch (error) {
      this.reportBoundaryError('KDBX 3.1 升级失败', error)
    } finally {
      this.busy = false
    }
  }

  private visibleEntries(): VaultEntry[] {
    return stageOneVaultStore.browse(this.searchQuery, this.browseMode, this.selectedGroupUuid)
  }

  private async toggleFavorite(): Promise<void> {
    this.busy = true
    try {
      const entry: VaultEntry = stageOneVaultStore.entry(this.selectedEntryUuid)
      await stageOneVaultStore.setFavorite(entry.uuid, !entry.favorite)
      this.status = ''
      this.recordActivity()
    } catch (error) {
      this.reportBoundaryError('更新收藏状态失败', error)
    } finally {
      this.busy = false
    }
  }

  private async toggleArchived(): Promise<void> {
    this.busy = true
    try {
      const entry: VaultEntry = stageOneVaultStore.entry(this.selectedEntryUuid)
      await stageOneVaultStore.setArchived(entry.uuid, !entry.archived)
      this.status = ''
      this.resetRoute(ROUTE_VAULT)
      this.recordActivity()
    } catch (error) {
      this.reportBoundaryError('更新归档状态失败', error)
    } finally {
      this.busy = false
    }
  }

  private openEntry(entryUuid: string): void {
    this.selectedEntryUuid = entryUuid
    this.showEntryPassword = false
    this.pushRoute(ROUTE_ENTRY_DETAIL)
    this.recordActivity()
  }

  private requestEditorExit(): void {
    if (!this.editorChanged()) {
      this.exitEditor()
      return
    }
    this.unsavedDialogVisible = true
  }

  private exitEditor(): void {
    this.unsavedDialogVisible = false
    this.clearEditorSensitiveState()
    if (this.selectedEntryUuid.length === 0) {
      this.resetRoute(ROUTE_VAULT)
    } else {
      this.popRoute()
    }
  }

  private revealPassword(target: string): void {
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

  private hidePasswords(): void {
    this.showUnlockPassword = false
    this.showEditorPassword = false
    this.showEntryPassword = false
    if (this.revealTimer >= 0) {
      clearTimeout(this.revealTimer)
      this.revealTimer = -1
    }
  }

  private async copyValue(value: string): Promise<void> {
    if (value.length === 0) {
      return
    }
    try {
      await this.clearClipboardIfOwned()
      this.clipboardToken = await this.clipboard.write(value)
      this.clipboardSeconds = CLIPBOARD_SECONDS
      this.clipboardTimer = setInterval(() => {
        this.clipboardSeconds--
        if (this.clipboardSeconds === 0) {
          this.clearClipboardIfOwned()
        }
      }, 1000)
      this.recordActivity()
    } catch (error) {
      this.reportBoundaryError('复制失败', error)
    }
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

  private async lockVault(): Promise<void> {
    await this.clearClipboardIfOwned()
    this.hidePasswords()
    this.clearEditorSensitiveState()
    this.clearGeneratorSensitiveState()
    stageOneVaultStore.lock()
    this.resetRoute(ROUTE_UNLOCK)
    this.vaultLocked = true
  }

  private recordActivity(): void {
    if (stageOneVaultStore.locked) {
      return
    }
    stageOneVaultStore.touch()
    this.scheduleAutoLock()
  }

  private scheduleAutoLock(): void {
    if (this.autoLockTimer >= 0) {
      clearTimeout(this.autoLockTimer)
    }
    this.autoLockTimer = setTimeout(() => this.lockVault(), AUTO_LOCK_MS)
  }

  private onVaultLockChanged(): void {
    if (this.vaultLocked && this.isUnlockedRoute()) {
      this.hidePasswords()
      this.clearEditorSensitiveState()
      this.clearGeneratorSensitiveState()
      this.resetRoute(ROUTE_UNLOCK)
    }
  }

  private onSensitiveEpochChanged(): void {
    this.hidePasswords()
    this.clearGeneratorSensitiveState()
  }

  private onForegroundEpochChanged(): void {
    stageOneVaultStore.onForeground()
    if (stageOneVaultStore.locked && this.isUnlockedRoute()) {
      this.resetRoute(ROUTE_UNLOCK)
      this.vaultLocked = true
    }
    this.privacyCovered = false
  }

  private passwordStrength(): Resource {
    if (this.masterPassword.length >= 16) {
      return $r('app.string.password_strong')
    }
    if (this.masterPassword.length >= 10) {
      return $r('app.string.password_medium')
    }
    return $r('app.string.password_weak')
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

  private clearGeneratorSensitiveState(): void {
    this.generatorValue = ''
    this.generatorStatus = ''
  }

  private clearTimers(): void {
    clearTimeout(this.splashTimer)
    clearTimeout(this.revealTimer)
    clearTimeout(this.autoLockTimer)
    clearInterval(this.clipboardTimer)
  }

  private formatSize(size: number): string {
    if (size < 1024) {
      return `${size} B`
    }
    return `${(size / 1024).toFixed(1)} KB`
  }

  private formatName(format: VaultFormat): string {
    return format === VaultFormat.Kdbx31 ? 'KDBX 3.1' : 'KDBX 4.x'
  }

  private reportBoundaryError(operation: string, error: Object): void {
    const failure: Error = error as Error
    this.status = failure.message
    const businessError: BusinessError = error as BusinessError
    const code: string = businessError.code === undefined ? 'unknown' : businessError.code.toString()
    this.logger.error(`${operation}，错误码=${code}`)
  }

  @Builder
  private topBar(title: Resource, showBack: boolean = false) {
    Row({ space: 12 }) {
      if (showBack) {
        Button($r('app.string.back'))
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.brand_primary'))
          .onClick(() => {
            this.popRoute()
          })
      }
      Text(title)
        .fontSize($r('app.float.text_heading'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      if (this.currentRoute === ROUTE_VAULT) {
        Button($r('app.string.lock'))
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.brand_primary'))
          .onClick(() => this.lockVault())
      }
    }
    .width('100%')
    .height($r('app.float.control_height'))
  }

  @Builder
  private statusText() {
    if (this.status.length > 0) {
      Text(this.status)
        .width('100%')
        .fontSize($r('app.float.text_body'))
        .fontColor($r('app.color.status_error'))
    }
  }

  @Builder
  private splashScreen() {
    Column({ space: 16 }) {
      Image($r('app.media.launch_icon'))
        .width($r('app.float.icon_large'))
        .height($r('app.float.icon_large'))
      Text($r('app.string.app_title'))
        .fontSize($r('app.float.text_heading'))
        .fontWeight(FontWeight.Bold)
      LoadingProgress()
        .width($r('app.float.space_24'))
        .height($r('app.float.space_24'))
        .color($r('app.color.brand_primary'))
      Text($r('app.string.preparing_vault'))
        .fontSize($r('app.float.text_body'))
        .fontColor($r('app.color.text_secondary'))
      if (this.splashTimedOut) {
        Button($r('app.string.retry'))
          .backgroundColor($r('app.color.brand_primary'))
          .onClick(() => this.initialize())
        if (this.status.length > 0) {
          Text(this.status).fontSize($r('app.float.text_caption')).fontColor($r('app.color.status_error'))
        }
      }
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.background_primary'))
  }

  @Builder
  private welcomeScreen() {
    Column({ space: 24 }) {
      Blank()
      Image($r('app.media.launch_icon')).width($r('app.float.icon_large')).height($r('app.float.icon_large'))
      Text($r('app.string.welcome_title')).fontSize($r('app.float.text_title')).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text($r('app.string.welcome_description')).fontSize($r('app.float.text_body'))
        .fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center)
      Column({ space: 12 }) {
        Button($r('app.string.create_vault')).width('100%').height($r('app.float.control_height'))
          .backgroundColor($r('app.color.brand_primary')).onClick(() => {
          stageOneVaultStore.clearKeyFile()
          this.pushRoute(ROUTE_CREATE_VAULT)
          this.status = ''
        })
        Button(this.busy ? $r('app.string.preparing_vault') : $r('app.string.open_local_vault'))
          .width('100%')
          .height($r('app.float.control_height'))
          .enabled(!this.busy)
          .backgroundColor($r('app.color.background_secondary'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => this.chooseLocalVault())
        Button($r('app.string.connect_webdav'))
          .width('100%')
          .height($r('app.float.control_height'))
          .backgroundColor($r('app.color.background_secondary'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.status = '此来源将在 WebDAV 阶段开放')
      }.width('100%')

      this.statusText()
      Blank()
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .padding($r('app.float.space_24'))
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private createScreen() {
    Scroll() {
      Column({ space: 16 }) {
        this.topBar($r('app.string.create_vault'), true)
        Text($r('app.string.vault_name')).width('100%').fontColor($r('app.color.text_secondary'))
        TextInput({ placeholder: $r('app.string.personal_vault'), text: this.vaultName })
          .width('100%').height($r('app.float.control_height')).backgroundColor($r('app.color.background_secondary'))
          .onChange((value: string) => this.vaultName = value)
        Text($r('app.string.save_location')).width('100%').fontColor($r('app.color.text_secondary'))
        Button(this.createFileName.length === 0 ? $r('app.string.choose_save_location') : this.createFileName)
          .width('100%')
          .height($r('app.float.control_height'))
          .backgroundColor($r('app.color.background_secondary'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => this.chooseCreateLocation())
        TextInput({ placeholder: $r('app.string.master_password'), text: this.masterPassword })
          .type(InputType.Password)
          .width('100%')
          .height($r('app.float.control_height'))
          .backgroundColor($r('app.color.background_secondary'))
          .onChange((value: string) => {
            this.masterPassword = value
            this.generatedMasterPassword = false
          })
        TextInput({ placeholder: $r('app.string.confirm_password'), text: this.confirmPassword })
          .type(InputType.Password)
          .width('100%')
          .height($r('app.float.control_height'))
          .backgroundColor($r('app.color.background_secondary'))
          .onChange((value: string) => this.confirmPassword = value)
        Text(this.passwordStrength()).width('100%').fontSize($r('app.float.text_caption'))
          .fontColor($r('app.color.text_secondary'))
        if (this.confirmPassword.length > 0 && this.masterPassword !== this.confirmPassword) {
          Text($r('app.string.password_mismatch')).width('100%').fontColor($r('app.color.status_error'))
        }
        Button($r('app.string.generate_password_suggestion'))
          .width('100%')
          .height($r('app.float.control_height'))
          .backgroundColor($r('app.color.surface_brand'))
          .fontColor($r('app.color.brand_primary'))
          .onClick(() => this.generateMasterPassword())
        if (this.generatedMasterPassword) {
          Row({ space: 8 }) {
            Checkbox({ name: 'generated_password_saved', group: 'create_vault' })
              .select(this.generatedPasswordSaved).onChange((value: boolean) => this.generatedPasswordSaved = value)
            Text($r('app.string.password_saved_ack')).fontSize($r('app.float.text_body'))
              .fontColor($r('app.color.text_primary')).layoutWeight(1)
          }.width('100%')
        }
        Button(stageOneVaultStore.currentKeyFileName.length === 0
          ? $r('app.string.select_key_file') : stageOneVaultStore.currentKeyFileName)
          .width('100%')
          .height($r('app.float.control_height'))
          .backgroundColor($r('app.color.background_secondary'))
          .fontColor($r('app.color.text_primary'))
          .onClick(() => this.chooseKeyFile())
        Text($r('app.string.key_file_warning')).width('100%').fontSize($r('app.float.text_caption'))
          .fontColor($r('app.color.status_warning'))
        Column({ space: 8 }) {
          Text($r('app.string.create_summary')).width('100%').fontWeight(FontWeight.Medium)
          Text($r('app.string.format_kdbx4')).width('100%').fontColor($r('app.color.text_secondary'))
          Text(stageOneVaultStore.currentKeyFileName.length === 0
            ? $r('app.string.without_key_file') : $r('app.string.with_key_file'))
            .width('100%').fontColor($r('app.color.text_secondary'))
        }.width('100%').padding($r('app.float.space_16')).backgroundColor($r('app.color.background_secondary'))
        .borderRadius($r('app.float.radius_8'))

        this.statusText()
        Button(this.busy ? $r('app.string.creating') : $r('app.string.create_vault'))
          .width('100%')
          .height($r('app.float.control_height'))
          .enabled(!this.busy)
          .backgroundColor($r('app.color.brand_primary'))
          .onClick(() => this.createVault())
      }.width('100%').constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding($r('app.float.space_24'))
    }.width('100%').height('100%')
  }

  @Builder
  private openSummaryScreen() {
    Column({ space: 16 }) {
      this.topBar($r('app.string.file_summary'), true)
      if (this.fileSummary !== undefined) {
        Column({ space: 12 }) {
          Text(this.fileSummary.name).width('100%').fontSize($r('app.float.text_heading')).fontWeight(FontWeight.Medium)
          Text(`${this.formatName(this.fileSummary.format)} · ${this.formatSize(this.fileSummary.size)}`)
            .width('100%').fontColor($r('app.color.text_secondary'))
          Text(new Date(this.fileSummary.modifiedAt * 1000).toLocaleString())
            .width('100%').fontColor($r('app.color.text_secondary'))
          Text(this.fileSummary.readOnly ? $r('app.string.read_only') : $r('app.string.writable'))
            .width('100%').fontColor(this.fileSummary.readOnly
            ? $r('app.color.status_warning') : $r('app.color.status_success'))
        }.width('100%').padding($r('app.float.space_16')).backgroundColor($r('app.color.background_secondary'))
        .borderRadius($r('app.float.radius_8'))
      }
      if (this.fileSummary?.readOnly) {
        Text($r('app.string.read_only_explanation')).width('100%').fontColor($r('app.color.status_warning'))
      }
      Blank()
      Button($r('app.string.continue_action')).width('100%').height($r('app.float.control_height'))
        .backgroundColor($r('app.color.brand_primary')).onClick(() => this.pushRoute(ROUTE_UNLOCK))
      Button($r('app.string.reselect_file'))
        .width('100%')
        .height($r('app.float.control_height'))
        .backgroundColor($r('app.color.background_secondary'))
        .fontColor($r('app.color.text_primary'))
        .onClick(() => this.chooseLocalVault())
    }.width('100%').height('100%').constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .padding($r('app.float.space_24'))
  }

  @Builder
  private unlockScreen() {
    Column({ space: 20 }) {
      Blank()
      Image($r('app.media.launch_icon')).width($r('app.float.icon_large')).height($r('app.float.icon_large'))
      Text($r('app.string.unlock_vault')).fontSize($r('app.float.text_title')).fontWeight(FontWeight.Bold)
      Text(stageOneVaultStore.hasRecentVault ? stageOneVaultStore.currentSource.displayName : '')
        .fontSize($r('app.float.text_heading')).fontWeight(FontWeight.Medium)
      Text($r('app.string.local_file')).fontColor($r('app.color.text_secondary'))
      Row({ space: 8 }) {
        TextInput({ placeholder: $r('app.string.master_password'), text: this.unlockPassword })
          .type(this.showUnlockPassword ? InputType.Normal : InputType.Password)
          .height($r('app.float.control_height'))
          .layoutWeight(1)
          .backgroundColor($r('app.color.background_secondary'))
          .onChange((value: string) => this.unlockPassword = value)
        Button(this.showUnlockPassword ? $r('app.string.hide') : $r('app.string.show'))
          .height($r('app.float.control_height')).backgroundColor($r('app.color.surface_brand'))
          .fontColor($r('app.color.brand_primary'))
          .onClick(() => this.showUnlockPassword ? this.hidePasswords() : this.revealPassword(ROUTE_UNLOCK))
      }.width('100%')

      Button(stageOneVaultStore.currentKeyFileName.length === 0
        ? $r('app.string.select_key_file') : stageOneVaultStore.currentKeyFileName)
        .width('100%')
        .height($r('app.float.control_height'))
        .backgroundColor($r('app.color.background_secondary'))
        .fontColor($r('app.color.text_primary'))
        .onClick(() => this.chooseKeyFile())
      this.statusText()
      Button(this.busy ? $r('app.string.unlocking') : $r('app.string.unlock_vault'))
        .width('100%')
        .height($r('app.float.control_height'))
        .enabled(!this.busy && !this.unlockBlocked && this.unlockPassword.length > 0)
        .backgroundColor($r('app.color.brand_primary'))
        .onClick(() => this.unlockVault())
      Button($r('app.string.choose_another_vault')).backgroundColor(Color.Transparent)
        .fontColor($r('app.color.brand_primary')).onClick(() => {
        stageOneVaultStore.clearKeyFile()
        this.resetRoute(ROUTE_WELCOME)
        this.status = ''
      })
      Blank()
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .padding($r('app.float.space_24'))
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private homeScreen() {
    Column({ space: 12 }) {
      this.topBar($r('app.string.vault_home'))
      Text(stageOneVaultStore.currentSource.displayName).width('100%').fontSize($r('app.float.text_caption'))
        .fontColor($r('app.color.text_secondary'))
      if (stageOneVaultStore.currentSource.readOnly) {
        Text($r('app.string.read_only_explanation')).width('100%').fontColor($r('app.color.status_warning'))
        if (stageOneVaultStore.currentFormat === VaultFormat.Kdbx31) {
          Column({ space: 8 }) {
            Text($r('app.string.upgrade_required')).width('100%').fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text($r('app.string.upgrade_description')).width('100%').fontSize($r('app.float.text_caption'))
              .fontColor($r('app.color.text_secondary'))
            Button(this.busy ? $r('app.string.upgrading') : $r('app.string.backup_and_upgrade'))
              .width('100%').enabled(!this.busy).backgroundColor($r('app.color.brand_primary'))
              .onClick(() => this.upgradeLegacyVault())
          }.width('100%').padding($r('app.float.space_16'))
          .backgroundColor($r('app.color.background_secondary')).borderRadius($r('app.float.radius_8'))
        }
      }
      this.statusText()
      TextInput({ placeholder: $r('app.string.search_vault'), text: this.searchQuery })
        .width('100%').height($r('app.float.control_height'))
        .backgroundColor($r('app.color.background_secondary'))
        .onChange((value: string) => this.searchQuery = value)
      Row({ space: 8 }) {
        this.browseModeButton($r('app.string.all_entries'), VaultBrowseMode.All)
        this.browseModeButton($r('app.string.favorites'), VaultBrowseMode.Favorites)
        this.browseModeButton($r('app.string.archived'), VaultBrowseMode.Archived)
      }.width('100%')

      Scroll() {
        Row({ space: 8 }) {
          Button($r('app.string.groups'))
            .backgroundColor(this.selectedGroupUuid.length === 0
              ? $r('app.color.brand_primary') : $r('app.color.background_secondary'))
            .fontColor(this.selectedGroupUuid.length === 0
              ? $r('app.color.text_on_brand') : $r('app.color.text_primary'))
            .onClick(() => this.selectedGroupUuid = '')
          ForEach(stageOneVaultStore.groups(), (group: VaultGroup) => {
            Button(group.name)
              .backgroundColor(this.selectedGroupUuid === group.uuid
                ? $r('app.color.brand_primary') : $r('app.color.background_secondary'))
              .fontColor(this.selectedGroupUuid === group.uuid
                ? $r('app.color.text_on_brand') : $r('app.color.text_primary'))
              .onClick(() => this.selectedGroupUuid = group.uuid)
          }, (group: VaultGroup) => group.uuid)
        }
      }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)

      if (stageOneVaultStore.entries().length === 0) {
        Column({ space: 12 }) {
          Text($r('app.string.no_entries')).fontSize($r('app.float.text_heading')).fontWeight(FontWeight.Medium)
          Text($r('app.string.no_entries_description')).fontColor($r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
          if (!stageOneVaultStore.currentSource.readOnly) {
            Button($r('app.string.new_entry')).backgroundColor($r('app.color.brand_primary'))
              .onClick(() => this.pushRoute(ROUTE_TEMPLATE))
          }
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.visibleEntries().length === 0) {
        Column() {
          Text($r('app.string.no_results')).fontSize($r('app.float.text_heading'))
            .fontColor($r('app.color.text_secondary'))
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.visibleEntries(), (entry: VaultEntry) => {
            ListItem() {
              Row({ space: 12 }) {
                Text(entry.title.substring(0, 1).toUpperCase())
                  .width($r('app.float.control_height'))
                  .height($r('app.float.control_height'))
                  .textAlign(TextAlign.Center)
                  .fontColor($r('app.color.text_on_brand'))
                  .backgroundColor($r('app.color.brand_primary'))
                  .borderRadius($r('app.float.radius_8'))
                Column({ space: 4 }) {
                  Text(entry.title).width('100%').fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                  Text(stageOneVaultStore.field(entry, 'UserName')).width('100%')
                    .fontSize($r('app.float.text_caption')).fontColor($r('app.color.text_secondary'))
                }.layoutWeight(1).alignItems(HorizontalAlign.Start)

                if (entry.favorite) {
                  Text($r('app.string.favorites')).fontSize($r('app.float.text_caption'))
                    .fontColor($r('app.color.brand_primary'))
                }
              }
              .width('100%')
              .padding($r('app.float.space_16'))
              .backgroundColor($r('app.color.background_secondary'))
              .borderRadius($r('app.float.radius_8'))
              .onClick(() => this.openEntry(entry.uuid))
            }
          }, (entry: VaultEntry) => entry.uuid)
        }.width('100%').layoutWeight(1)

        if (!stageOneVaultStore.currentSource.readOnly) {
          Button($r('app.string.new_entry')).width('100%').height($r('app.float.control_height'))
            .backgroundColor($r('app.color.brand_primary')).onClick(() => this.pushRoute(ROUTE_TEMPLATE))
        }
      }
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .padding($r('app.float.space_24'))
    .onTouch(() => this.recordActivity())
  }

  @Builder
  private browseModeButton(title: Resource, mode: VaultBrowseMode) {
    Button(title)
      .layoutWeight(1)
      .backgroundColor(this.browseMode === mode
        ? $r('app.color.brand_primary') : $r('app.color.background_secondary'))
      .fontColor(this.browseMode === mode
        ? $r('app.color.text_on_brand') : $r('app.color.text_primary'))
      .onClick(() => this.browseMode = mode)
  }

  @Builder
  private templateScreen() {
    Column({ space: 12 }) {
      this.topBar($r('app.string.choose_template'), true)
      this.templateRow($r('app.string.login_template'), $r('app.string.login_template_description'), true)
      this.templateRow($r('app.string.credit_card_template'), $r('app.string.not_available'), false)
      this.templateRow($r('app.string.secure_note_template'), $r('app.string.not_available'), false)
      this.templateRow($r('app.string.identity_template'), $r('app.string.not_available'), false)
      this.templateRow($r('app.string.wifi_template'), $r('app.string.not_available'), false)
      this.templateRow($r('app.string.license_template'), $r('app.string.not_available'), false)
      Blank()
    }.width('100%').height('100%').constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .padding($r('app.float.space_24'))
  }

  @Builder
  private templateRow(title: Resource, description: Resource, enabled: boolean) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title).width('100%').fontWeight(FontWeight.Medium)
        Text(description).width('100%').fontSize($r('app.float.text_caption'))
          .fontColor($r('app.color.text_secondary'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)

      Button(enabled ? $r('app.string.continue_action') : $r('app.string.not_available'))
        .enabled(enabled).backgroundColor(enabled
        ? $r('app.color.surface_brand') : $r('app.color.background_primary'))
        .fontColor(enabled ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
        .onClick(() => this.startNewEntry())
    }.width('100%').padding($r('app.float.space_16')).backgroundColor($r('app.color.background_secondary'))
    .borderRadius($r('app.float.radius_8'))
  }

  @Builder
  private editScreen() {
    Stack() {
      Scroll() {
        Column({ space: 14 }) {
          Row({ space: 12 }) {
            Button($r('app.string.cancel')).backgroundColor(Color.Transparent)
              .fontColor($r('app.color.brand_primary')).onClick(() => this.requestEditorExit())
            Text(this.selectedEntryUuid.length === 0 ? $r('app.string.new_entry') : $r('app.string.edit'))
              .layoutWeight(1).fontSize($r('app.float.text_heading')).fontWeight(FontWeight.Bold)
            Button(this.busy ? $r('app.string.saving') : $r('app.string.save'))
              .enabled(!this.busy).backgroundColor(Color.Transparent).fontColor($r('app.color.brand_primary'))
              .onClick(() => this.saveEntry())
          }.width('100%').height($r('app.float.control_height'))

          TextInput({ placeholder: $r('app.string.entry_title'), text: this.editorTitle })
            .width('100%').height($r('app.float.control_height')).backgroundColor($r('app.color.background_secondary'))
            .onChange((value: string) => this.editorTitle = value)
          TextInput({ placeholder: $r('app.string.username'), text: this.editorUsername })
            .width('100%').height($r('app.float.control_height')).backgroundColor($r('app.color.background_secondary'))
            .onChange((value: string) => this.editorUsername = value)
          Row({ space: 8 }) {
            TextInput({ placeholder: $r('app.string.password'), text: this.editorPassword })
              .type(this.showEditorPassword ? InputType.Normal : InputType.Password)
              .height($r('app.float.control_height'))
              .layoutWeight(1)
              .backgroundColor($r('app.color.background_secondary'))
              .onChange((value: string) => this.editorPassword = value)
            Button(this.showEditorPassword ? $r('app.string.hide') : $r('app.string.show'))
              .height($r('app.float.control_height')).backgroundColor($r('app.color.surface_brand'))
              .fontColor($r('app.color.brand_primary'))
              .onClick(() => this.showEditorPassword ? this.hidePasswords() : this.revealPassword(ROUTE_ENTRY_EDIT))
            Button($r('app.string.generate')).height($r('app.float.control_height'))
              .backgroundColor($r('app.color.brand_primary'))
              .onClick(() => this.openGenerator(true))
          }.width('100%')

          TextInput({ placeholder: $r('app.string.website'), text: this.editorUrl })
            .width('100%').height($r('app.float.control_height')).backgroundColor($r('app.color.background_secondary'))
            .onChange((value: string) => this.editorUrl = value)
          if (this.editorUrl.length > 0 && !this.editorUrl.startsWith('https://')
            && !this.editorUrl.startsWith('http://')) {
            Text('网址格式异常，但不会阻止保存').width('100%').fontColor($r('app.color.status_warning'))
          }
          TextArea({ placeholder: $r('app.string.notes'), text: this.editorNotes })
            .width('100%').backgroundColor($r('app.color.background_secondary'))
            .onChange((value: string) => this.editorNotes = value)
          TextInput({ placeholder: $r('app.string.tags'), text: this.editorTags })
            .width('100%').height($r('app.float.control_height')).backgroundColor($r('app.color.background_secondary'))
            .onChange((value: string) => this.editorTags = value)
          Text($r('app.string.group')).width('100%').fontColor($r('app.color.text_secondary'))
          Scroll() {
            Row({ space: 8 }) {
              ForEach(stageOneVaultStore.groups(), (group: VaultGroup) => {
                Button(group.path)
                  .backgroundColor(this.editorGroupUuid === group.uuid
                    ? $r('app.color.brand_primary') : $r('app.color.background_secondary'))
                  .fontColor(this.editorGroupUuid === group.uuid
                    ? $r('app.color.text_on_brand') : $r('app.color.text_primary'))
                  .onClick(() => this.editorGroupUuid = group.uuid)
              }, (group: VaultGroup) => group.uuid)
            }
          }.width('100%').scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)

          this.statusText()
        }.width('100%').constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .padding($r('app.float.space_24'))
      }.width('100%').height('100%')

      if (this.unsavedDialogVisible) {
        Column({ space: 12 }) {
          Text($r('app.string.unsaved_title')).fontSize($r('app.float.text_heading')).fontWeight(FontWeight.Bold)
          Text($r('app.string.unsaved_message')).fontColor($r('app.color.text_secondary'))
          Button($r('app.string.save')).width('100%').backgroundColor($r('app.color.brand_primary'))
            .onClick(() => this.saveEntry())
          Button($r('app.string.discard')).width('100%').backgroundColor($r('app.color.background_primary'))
            .fontColor($r('app.color.status_error')).onClick(() => this.exitEditor())
          Button($r('app.string.continue_editing')).width('100%').backgroundColor(Color.Transparent)
            .fontColor($r('app.color.brand_primary')).onClick(() => this.unsavedDialogVisible = false)
        }
        .width($r('app.float.dialog_width'))
        .padding($r('app.float.space_24'))
        .backgroundColor($r('app.color.background_secondary'))
        .borderRadius($r('app.float.radius_16'))
        .shadow({
          radius: 24,
          color: 0x33000000,
          offsetX: 0,
          offsetY: 8,
        })
      }
    }.width('100%').height('100%')
  }

  @Builder
  private generatorModeButton(title: Resource, mode: GeneratorMode) {
    Button(title)
      .layoutWeight(1)
      .backgroundColor(this.generatorMode === mode
        ? $r('app.color.brand_primary') : $r('app.color.background_secondary'))
      .fontColor(this.generatorMode === mode
        ? $r('app.color.text_on_brand') : $r('app.color.text_primary'))
      .onClick(() => this.setGeneratorMode(mode))
  }

  @Builder
  private generatorToggle(title: Resource, value: boolean, change: (value: boolean) => void) {
    Row() {
      Text(title).layoutWeight(1).fontColor($r('app.color.text_primary'))
      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor($r('app.color.brand_primary'))
        .onChange(change)
    }.width('100%').height($r('app.float.control_height'))
  }

  @Builder
  private randomGeneratorOptions() {
    Column({ space: 8 }) {
      Text($r('app.string.password_length_value', this.randomLength)).width('100%')
        .fontColor($r('app.color.text_primary'))
      Slider({
        value: this.randomLength,
        min: 8,
        max: 64,
        step: 1,
      })
        .width('100%').selectedColor($r('app.color.brand_primary')).showTips(true)
        .onChange((value: number) => {
          this.randomLength = value
          this.regeneratePassword()
        })
      this.generatorToggle($r('app.string.include_uppercase'), this.randomUppercase, (value: boolean) => {
        this.randomUppercase = value
        this.regeneratePassword()
      })
      this.generatorToggle($r('app.string.include_lowercase'), this.randomLowercase, (value: boolean) => {
        this.randomLowercase = value
        this.regeneratePassword()
      })
      this.generatorToggle($r('app.string.include_digits'), this.randomDigits, (value: boolean) => {
        this.randomDigits = value
        this.regeneratePassword()
      })
      this.generatorToggle($r('app.string.include_symbols'), this.randomSymbols, (value: boolean) => {
        this.randomSymbols = value
        this.regeneratePassword()
      })
      this.generatorToggle($r('app.string.exclude_similar'), this.randomExcludeSimilar, (value: boolean) => {
        this.randomExcludeSimilar = value
        this.regeneratePassword()
      })
      Text($r('app.string.minimum_digits_value', this.randomMinimumDigits)).width('100%')
      Slider({
        value: this.randomMinimumDigits,
        min: 0,
        max: 8,
        step: 1,
      })
        .width('100%').selectedColor($r('app.color.brand_primary')).showTips(true)
        .onChange((value: number) => {
          this.randomMinimumDigits = value
          this.regeneratePassword()
        })
      Text($r('app.string.minimum_symbols_value', this.randomMinimumSymbols)).width('100%')
      Slider({
        value: this.randomMinimumSymbols,
        min: 0,
        max: 8,
        step: 1,
      })
        .width('100%').selectedColor($r('app.color.brand_primary')).showTips(true)
        .onChange((value: number) => {
          this.randomMinimumSymbols = value
          this.regeneratePassword()
        })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private memorableGeneratorOptions() {
    Column({ space: 12 }) {
      Text($r('app.string.word_count_value', this.memorableWordCount)).width('100%')
      Slider({
        value: this.memorableWordCount,
        min: 3,
        max: 8,
        step: 1,
      })
        .width('100%').selectedColor($r('app.color.brand_primary')).showTips(true)
        .onChange((value: number) => {
          this.memorableWordCount = value
          this.regeneratePassword()
        })
      Text($r('app.string.separator')).width('100%').fontColor($r('app.color.text_secondary'))
      Row({ space: 8 }) {
        this.generatorSeparatorButton('-', '-')
        this.generatorSeparatorButton('.', '.')
        this.generatorSeparatorButton('_', '_')
        this.generatorSeparatorButton($r('app.string.no_separator'), '')
      }.width('100%')

      Text($r('app.string.letter_case')).width('100%').fontColor($r('app.color.text_secondary'))
      Row({ space: 8 }) {
        this.generatorCaseButton($r('app.string.lowercase'), MemorableCase.Lower)
        this.generatorCaseButton($r('app.string.capitalize'), MemorableCase.Capitalized)
        this.generatorCaseButton($r('app.string.uppercase'), MemorableCase.Upper)
      }.width('100%')

      this.generatorToggle($r('app.string.append_number'), this.memorableAppendNumber, (value: boolean) => {
        this.memorableAppendNumber = value
        this.regeneratePassword()
      })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private generatorSeparatorButton(title: ResourceStr, separator: string) {
    Button(title).layoutWeight(1)
      .backgroundColor(this.memorableSeparator === separator
        ? $r('app.color.brand_primary') : $r('app.color.background_secondary'))
      .fontColor(this.memorableSeparator === separator
        ? $r('app.color.text_on_brand') : $r('app.color.text_primary'))
      .onClick(() => {
        this.memorableSeparator = separator
        this.regeneratePassword()
      })
  }

  @Builder
  private generatorCaseButton(title: Resource, letterCase: MemorableCase) {
    Button(title).layoutWeight(1)
      .backgroundColor(this.memorableCase === letterCase
        ? $r('app.color.brand_primary') : $r('app.color.background_secondary'))
      .fontColor(this.memorableCase === letterCase
        ? $r('app.color.text_on_brand') : $r('app.color.text_primary'))
      .onClick(() => {
        this.memorableCase = letterCase
        this.regeneratePassword()
      })
  }

  @Builder
  private pinGeneratorOptions() {
    Column({ space: 12 }) {
      Text($r('app.string.pin_length_value', this.pinLength)).width('100%')
      Slider({
        value: this.pinLength,
        min: 4,
        max: 12,
        step: 1,
      })
        .width('100%').selectedColor($r('app.color.brand_primary')).showTips(true)
        .onChange((value: number) => {
          this.pinLength = value
          this.regeneratePassword()
        })
      this.generatorToggle($r('app.string.avoid_pin_patterns'), this.pinAvoidPatterns, (value: boolean) => {
        this.pinAvoidPatterns = value
        this.regeneratePassword()
      })
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  private generatorScreen() {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        if (this.generatorReturnToEditor) {
          Button($r('app.string.back')).backgroundColor(Color.Transparent)
            .fontColor($r('app.color.brand_primary')).onClick(() => this.closeGenerator())
        }
        Text($r('app.string.password_generator')).layoutWeight(1)
          .fontSize($r('app.float.text_heading')).fontWeight(FontWeight.Bold)
        Button($r('app.string.lock')).backgroundColor(Color.Transparent)
          .fontColor($r('app.color.brand_primary')).onClick(() => this.lockVault())
      }.width('100%').height($r('app.float.control_height'))

      Row({ space: 8 }) {
        this.generatorModeButton($r('app.string.random_password'), GeneratorMode.Random)
        this.generatorModeButton($r('app.string.memorable_password'), GeneratorMode.Memorable)
        this.generatorModeButton($r('app.string.pin_code'), GeneratorMode.Pin)
      }.width('100%').padding(4).borderRadius($r('app.float.radius_24'))
      .systemMaterial(this.navigationMaterial)

      Column({ space: 8 }) {
        Text(this.generatorValue.length > 0 ? this.generatorValue : $r('app.string.no_candidate'))
          .width('100%')
          .fontSize($r('app.float.text_heading'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.generatorValue.length > 0
            ? $r('app.color.text_primary') : $r('app.color.text_secondary'))
          .textAlign(TextAlign.Center)
        Text($r('app.string.generator_strength', this.generatorStrength().label,
          this.generatorStrength().estimatedBits)).width('100%').fontSize($r('app.float.text_caption'))
          .fontColor($r('app.color.text_secondary')).textAlign(TextAlign.Center)
        if (this.clipboardSeconds > 0) {
          Text($r('app.string.copied_countdown', this.clipboardSeconds)).width('100%')
            .fontColor($r('app.color.status_success')).textAlign(TextAlign.Center)
        }
      }.width('100%').padding($r('app.float.space_16'))
      .backgroundColor($r('app.color.background_secondary')).borderRadius($r('app.float.radius_8'))

      Scroll() {
        Column({ space: 12 }) {
          if (this.generatorMode === GeneratorMode.Random) {
            this.randomGeneratorOptions()
          } else if (this.generatorMode === GeneratorMode.Memorable) {
            this.memorableGeneratorOptions()
          } else {
            this.pinGeneratorOptions()
          }
          if (this.generatorStatus.length > 0) {
            Text(this.generatorStatus).width('100%').fontColor($r('app.color.status_error'))
          }
        }.width('100%')
      }.width('100%').layoutWeight(1)

      Row({ space: 8 }) {
        Button($r('app.string.regenerate'))
          .layoutWeight(1)
          .height($r('app.float.control_height'))
          .backgroundColor($r('app.color.surface_brand'))
          .fontColor($r('app.color.brand_primary'))
          .onClick(() => this.regeneratePassword())
        Button($r('app.string.copy'))
          .layoutWeight(1)
          .height($r('app.float.control_height'))
          .enabled(this.generatorValue.length > 0)
          .backgroundColor($r('app.color.brand_primary'))
          .onClick(() => this.copyValue(this.generatorValue))
      }.width('100%').padding(8).borderRadius($r('app.float.radius_16'))
      .systemMaterial(this.navigationMaterial)

      if (this.generatorReturnToEditor) {
        Button($r('app.string.fill_current_entry'))
          .width('100%')
          .height($r('app.float.control_height'))
          .enabled(this.generatorValue.length > 0)
          .backgroundColor($r('app.color.brand_primary'))
          .onClick(() => this.fillEditorFromGenerator())
      } else if (!stageOneVaultStore.currentSource.readOnly) {
        Button($r('app.string.save_as_login'))
          .width('100%')
          .height($r('app.float.control_height'))
          .enabled(this.generatorValue.length > 0)
          .backgroundColor($r('app.color.brand_primary'))
          .onClick(() => this.startEntryFromGenerator())
      }
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .padding($r('app.float.space_24'))
    .onTouch(() => this.recordActivity())
  }

  @Builder
  private pendingModuleScreen(title: Resource) {
    Column({ space: 16 }) {
      Row({ space: 12 }) {
        Text(title)
          .layoutWeight(1)
          .fontSize($r('app.float.text_heading'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Button($r('app.string.lock'))
          .backgroundColor(Color.Transparent)
          .fontColor($r('app.color.brand_primary'))
          .onClick(() => this.lockVault())
      }
      .width('100%')
      .height($r('app.float.control_height'))

      Column({ space: 8 }) {
        Text($r('app.string.module_pending'))
          .fontSize($r('app.float.text_body'))
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .padding($r('app.float.space_24'))
    .onTouch(() => this.recordActivity())
  }

  @Builder
  private moduleNavigationItem(label: Resource, symbol: Resource, route: string) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Column({ space: 2 }) {
        SymbolGlyph(symbol)
          .fontSize(22)
          .fontColor([this.currentRoute === route
            ? $r('app.color.brand_primary') : $r('app.color.text_secondary')])
        Text(label)
          .fontSize(11)
          .fontWeight(this.currentRoute === route ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.currentRoute === route
            ? $r('app.color.brand_primary') : $r('app.color.text_secondary'))
          .maxLines(1)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.currentRoute === route ? $r('app.color.surface_brand') : Color.Transparent)
      .borderRadius(28)
    }
    .layoutWeight(1)
    .height(56)
    .backgroundColor(Color.Transparent)
    .systemMaterial(this.navigationItemMaterial)
    .onClick(() => this.switchModule(route))
  }

  @Builder
  private moduleNavigationBar() {
    Row({ space: 4 }) {
      this.moduleNavigationItem($r('app.string.vault_home'), $r('sys.symbol.folder_fill'), ROUTE_VAULT)
      this.moduleNavigationItem($r('app.string.security_center'), $r('sys.symbol.shield_checkered'), ROUTE_SECURITY)
      this.moduleNavigationItem($r('app.string.password_generator'), $r('sys.symbol.wand_and_stars_fill'),
        ROUTE_GENERATOR)
      this.moduleNavigationItem($r('app.string.settings'), $r('sys.symbol.gearshape_fill'), ROUTE_SETTINGS)
    }
    .width('calc(100% - 32vp)')
    .height(68)
    .padding(6)
    .margin({ left: 16, right: 16, bottom: 12 })
    .borderRadius(34)
    .systemMaterial(this.navigationMaterial)
  }

  @Builder
  private detailScreen() {
    Column({ space: 16 }) {
      this.topBar($r('app.string.login_template'), true)
      Text(stageOneVaultStore.entry(this.selectedEntryUuid).title).width('100%')
        .fontSize($r('app.float.text_title')).fontWeight(FontWeight.Bold)
      Text(stageOneVaultStore.entry(this.selectedEntryUuid).groupPath).width('100%')
        .fontColor($r('app.color.text_secondary'))
      Row({ space: 8 }) {
        Button(stageOneVaultStore.entry(this.selectedEntryUuid).favorite
          ? $r('app.string.remove_favorite') : $r('app.string.add_favorite'))
          .enabled(!this.busy && !stageOneVaultStore.currentSource.readOnly)
          .backgroundColor($r('app.color.surface_brand')).fontColor($r('app.color.brand_primary'))
          .onClick(() => this.toggleFavorite())
        Button(stageOneVaultStore.entry(this.selectedEntryUuid).archived
          ? $r('app.string.restore_entry') : $r('app.string.archive_entry'))
          .enabled(!this.busy && !stageOneVaultStore.currentSource.readOnly)
          .backgroundColor($r('app.color.background_secondary')).fontColor($r('app.color.text_primary'))
          .onClick(() => this.toggleArchived())
      }.width('100%')

      this.detailField($r('app.string.username'),
        stageOneVaultStore.field(stageOneVaultStore.entry(this.selectedEntryUuid), 'UserName'))
      this.passwordDetailField(stageOneVaultStore.field(stageOneVaultStore.entry(this.selectedEntryUuid), 'Password'))
      this.detailField($r('app.string.website'),
        stageOneVaultStore.field(stageOneVaultStore.entry(this.selectedEntryUuid), 'URL'))
      this.detailField($r('app.string.notes'),
        stageOneVaultStore.field(stageOneVaultStore.entry(this.selectedEntryUuid), 'Notes'))
      if (stageOneVaultStore.entry(this.selectedEntryUuid).tags.length > 0) {
        this.detailField($r('app.string.tags'), stageOneVaultStore.entry(this.selectedEntryUuid).tags.join(', '))
      }
      if (this.clipboardSeconds > 0) {
        Text($r('app.string.copied_countdown', this.clipboardSeconds)).width('100%')
          .fontColor($r('app.color.status_success')).textAlign(TextAlign.Center)
      }
      Blank()
      if (!stageOneVaultStore.currentSource.readOnly) {
        Button($r('app.string.edit')).width('100%').height($r('app.float.control_height'))
          .backgroundColor($r('app.color.brand_primary')).onClick(() => this.startEditEntry())
      }
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .padding($r('app.float.space_24'))
    .onTouch(() => this.recordActivity())
  }

  @Builder
  private detailField(label: Resource, value: string) {
    Column({ space: 8 }) {
      Text(label).width('100%').fontSize($r('app.float.text_caption')).fontColor($r('app.color.text_secondary'))
      Row({ space: 8 }) {
        Text(value).layoutWeight(1).fontSize($r('app.float.text_body')).fontColor($r('app.color.text_primary'))
        if (value.length > 0) {
          Button($r('app.string.copy')).backgroundColor(Color.Transparent).fontColor($r('app.color.brand_primary'))
            .onClick(() => this.copyValue(value))
        }
      }.width('100%')
    }.width('100%').padding($r('app.float.space_16')).backgroundColor($r('app.color.background_secondary'))
    .borderRadius($r('app.float.radius_8'))
  }

  @Builder
  private passwordDetailField(value: string) {
    Column({ space: 8 }) {
      Text($r('app.string.password')).width('100%').fontSize($r('app.float.text_caption'))
        .fontColor($r('app.color.text_secondary'))
      Row({ space: 8 }) {
        Text(this.showEntryPassword ? value : $r('app.string.password_hidden'))
          .layoutWeight(1).fontSize($r('app.float.text_body')).fontColor($r('app.color.text_primary'))
        Button(this.showEntryPassword ? $r('app.string.hide') : $r('app.string.show'))
          .backgroundColor(Color.Transparent).fontColor($r('app.color.brand_primary'))
          .onClick(() => this.showEntryPassword ? this.hidePasswords() : this.revealPassword(ROUTE_ENTRY_DETAIL))
        Button($r('app.string.copy')).backgroundColor(Color.Transparent).fontColor($r('app.color.brand_primary'))
          .onClick(() => this.copyValue(value))
      }.width('100%')
    }.width('100%').padding($r('app.float.space_16')).backgroundColor($r('app.color.background_secondary'))
    .borderRadius($r('app.float.radius_8'))
  }

  @Builder
  private routeDestination(name: string, param: Object) {
    if (name === ROUTE_WELCOME) {
      NavDestination() {
        this.welcomeScreen()
      }
      .hideTitleBar(true)
      .onShown(() => this.currentRoute = ROUTE_WELCOME)
    } else if (name === ROUTE_CREATE_VAULT) {
      NavDestination() {
        this.createScreen()
      }
      .hideTitleBar(true)
      .onShown(() => this.currentRoute = ROUTE_CREATE_VAULT)
    } else if (name === ROUTE_FILE_SUMMARY) {
      NavDestination() {
        this.openSummaryScreen()
      }
      .hideTitleBar(true)
      .onShown(() => this.currentRoute = ROUTE_FILE_SUMMARY)
    } else if (name === ROUTE_UNLOCK) {
      NavDestination() {
        this.unlockScreen()
      }
      .hideTitleBar(true)
      .onShown(() => this.currentRoute = ROUTE_UNLOCK)
    } else if (name === ROUTE_VAULT) {
      NavDestination() {
        this.homeScreen()
      }
      .hideTitleBar(true)
      .onShown(() => this.currentRoute = ROUTE_VAULT)
    } else if (name === ROUTE_SECURITY) {
      NavDestination() {
        this.pendingModuleScreen($r('app.string.security_center'))
      }
      .hideTitleBar(true)
      .onShown(() => this.currentRoute = ROUTE_SECURITY)
    } else if (name === ROUTE_GENERATOR) {
      NavDestination() {
        this.generatorScreen()
      }
      .hideTitleBar(true)
      .onShown(() => this.currentRoute = ROUTE_GENERATOR)
      .onHidden(() => this.clearGeneratorSensitiveState())
      .onBackPressed(() => {
        this.closeGenerator()
        return true
      })
    } else if (name === ROUTE_SETTINGS) {
      NavDestination() {
        this.pendingModuleScreen($r('app.string.settings'))
      }
      .hideTitleBar(true)
      .onShown(() => this.currentRoute = ROUTE_SETTINGS)
    } else if (name === ROUTE_TEMPLATE) {
      NavDestination() {
        this.templateScreen()
      }
      .hideTitleBar(true)
      .onShown(() => this.currentRoute = ROUTE_TEMPLATE)
    } else if (name === ROUTE_ENTRY_EDIT) {
      NavDestination() {
        this.editScreen()
      }
      .hideTitleBar(true)
      .onShown(() => this.currentRoute = ROUTE_ENTRY_EDIT)
      .onBackPressed(() => {
        if (this.unsavedDialogVisible) {
          this.unsavedDialogVisible = false
        } else {
          this.requestEditorExit()
        }
        return true
      })
    } else if (name === ROUTE_ENTRY_DETAIL) {
      NavDestination() {
        this.detailScreen()
      }
      .hideTitleBar(true)
      .onShown(() => this.currentRoute = ROUTE_ENTRY_DETAIL)
    } else {
      NavDestination() {
        Text($r('app.string.route_not_found'))
          .fontColor($r('app.color.status_error'))
      }
      .hideTitleBar(true)
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Navigation(this.navPathStack) {
        this.splashScreen()
      }
      .width('100%')
      .height('100%')
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .navDestination(this.routeDestination)
      .padding({ bottom: this.isModuleRoute() ? 88 : 0 })
      .backgroundColor($r('app.color.background_primary'))

      if (this.isModuleRoute()) {
        this.moduleNavigationBar()
      }
      if (this.privacyCovered) {
        this.splashScreen()
      }
    }.width('100%').height('100%')
  }
}
