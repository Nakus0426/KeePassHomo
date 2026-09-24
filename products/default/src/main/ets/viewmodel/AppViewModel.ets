import { common, Want } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import {
  AppErrorFactory,
  AppErrorModel,
  RESERVED_FIELD_NAMES,
  VaultEngineError,
  VaultEngineErrorCategory,
  VaultEntry,
  VaultEntryInput,
  VaultField,
  VaultFieldInput,
  VaultFieldType,
  VaultFormat,
  VaultGroup,
  VaultRepositoryError,
  VaultRepositoryErrorCategory,
  VaultSource,
} from '@ohos/common'
import { formatISO9075 } from '@wolfx/date-fns'
import { AppUtil, FileUtil, LogUtil } from '@pura/harmony-utils'
import {
  ROUTE_CREATE_VAULT,
  ROUTE_FILE_SUMMARY,
  ROUTE_GENERATOR,
  ROUTE_UNLOCK,
  ROUTE_VAULT,
  ROUTE_WELCOME,
} from '../constants/RouteConstants'
import { stageOneVaultStore, UserCancelledError, VaultFileSummary } from '../model/StageOneVaultStore'
import { appSessionState } from '../state/AppSessionState'
import { appRouter } from '../navigation/AppRouter'
import { WelcomeParam } from '../navigation/RouteParams'
import { EntryEditorViewModel, EntryFieldEditor } from './EntryEditorViewModel'
import { vaultHomeViewModel } from './VaultHomeViewModel'
import { GeneratorViewModel } from './GeneratorViewModel'
import { VaultSessionViewModel } from './VaultSessionViewModel'

const ACTION_VIEW_DATA: string = 'ohos.want.action.viewData'
const ACTION_DIAL: string = 'ohos.want.action.dial'
const ACTION_SEND_TO_DATA: string = 'ohos.want.action.sendToData'

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
    if (appSessionState.currentModule === route && appRouter.isHomePage()) {
      return
    }
    if (appSessionState.currentModule === ROUTE_GENERATOR) {
      this.generator.clearSensitiveState()
    }
    appSessionState.setCurrentModule(route)
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
    if (appRouter.stack.getParamByName(ROUTE_UNLOCK).length > 0) {
      appRouter.stack.popToName(ROUTE_UNLOCK)
      return
    }
    appRouter.push(ROUTE_UNLOCK)
    this.setStatus('')
  }

  showWebDavPending(): void {
    this.setStatus('此来源将在 WebDAV 阶段开放')
  }

  chooseAnotherVault(): void {
    const param: WelcomeParam = { showBack: true }
    appRouter.push(ROUTE_WELCOME, param)
    this.setStatus('')
  }

  async createVault(vaultName: string, masterPassword: string): Promise<void> {
    this.busy = true
    try {
      await stageOneVaultStore.createVault(vaultName.trim(), masterPassword)
      this.refreshVault()
      this.session.markUnlocked()
      appSessionState.setCurrentModule(ROUTE_VAULT)
      appRouter.clearToHome()
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

  /**
   * 解锁保险库。成功返回 true（由解锁页播放离场动画后自行跳转首页），
   * 失败返回 false 并通过 lastError 通知页面。
   */
  async unlockVault(password: string): Promise<boolean> {
    if (password.length === 0 || this.unlockBlocked) {
      return false
    }
    this.busy = true
    try {
      await stageOneVaultStore.unlock(password)
      this.unlockFailures = 0
      this.refreshVault()
      this.session.markUnlocked()
      appSessionState.setCurrentModule(ROUTE_VAULT)
      this.setStatus('')
      return true
    } catch (error) {
      LogUtil.error('保险库解锁失败')
      const repositoryError: VaultRepositoryError = error as VaultRepositoryError
      if (repositoryError.category === VaultRepositoryErrorCategory.NotFound ||
        repositoryError.category === VaultRepositoryErrorCategory.PermissionDenied) {
        this.reportBoundaryError('保险库解锁失败，请重试', error)
        return false
      }
      const engineError: VaultEngineError = error as VaultEngineError
      if (engineError.category === VaultEngineErrorCategory.InvalidCredential) {
        this.unlockFailures++
        this.reportBoundaryError('保险库解锁失败，请重试', error)
        this.applyUnlockDelay()
        return false
      }
      this.reportBoundaryError('保险库解锁失败，请重试', error)
      return false
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
    // 复制一份：entry.tags 是 KDBX 内存模型的数组，直接改会让取消编辑也生效。
    editor.tags = entry.tags.slice()
    editor.fields = entry.fields
      .filter((field: VaultField) => !RESERVED_FIELD_NAMES.includes(field.name))
      .map((field: VaultField): EntryFieldEditor => {
        const edited: EntryFieldEditor = new EntryFieldEditor()
        edited.name = field.name
        edited.value = field.value
        edited.type = field.type
        edited.protected = field.protected
        return edited
      })
    editor.avatarData = stageOneVaultStore.loadEntryAvatar(entryUuid)
    editor.initialValue = editor.currentValue()
    this.recordActivity()
  }

  /**
   * 保存条目。是否成功由调用方决定后续（关闭编辑器或留在当前页面），
   * 本方法只落盘并刷新派生数据。
   */
  async saveEntry(editor: EntryEditorViewModel): Promise<boolean> {
    const fields: VaultFieldInput[] = editor.fieldInputs()
    const invalidFieldMessage: string = this.validateCustomFields(fields)
    if (invalidFieldMessage.length > 0) {
      this.setStatus(invalidFieldMessage)
      return false
    }
    this.busy = true
    const input: VaultEntryInput = {
      groupUuid: editor.groupUuid,
      title: editor.title.trim(),
      username: editor.username,
      password: editor.password,
      url: editor.url.trim(),
      notes: editor.notes,
      fields,
      tags: editor.tags,
      avatar: editor.avatarInput(),
    }
    try {
      const saved: VaultEntry = await stageOneVaultStore.saveEntry(editor.entryUuid, input)
      // 采纳落盘后的条目标识：同一次编辑会话内再次保存走更新，不会重复创建条目。
      editor.entryUuid = saved.uuid
      editor.markSaved()
      // 首页快照由 EntryEditSheet 在 sheet 收起完成后重建：列表变更放在动画上下文里才可见。
      this.revision++
      this.setStatus('')
      this.recordActivity()
      return true
    } catch (error) {
      this.reportBoundaryError('保存条目失败', error)
      return false
    } finally {
      this.busy = false
    }
  }

  /**
   * 自定义字段名不能为空，也不能与保留字段名冲突（否则会覆盖固定字段）。
   */
  private validateCustomFields(fields: VaultFieldInput[]): string {
    for (const field of fields) {
      const name: string = field.name.trim()
      if (name.length === 0) {
        return '自定义字段名不能为空'
      }
      if (RESERVED_FIELD_NAMES.includes(name)) {
        return `自定义字段名不能使用固定字段名：${name}`
      }
    }
    return ''
  }

  /**
   * 按字段类型交给系统应用处理：网址走浏览器、电话走拨号、邮箱走邮件、地址走地图；
   * 其余类型没有外部动作。值缺少协议前缀时补齐，否则系统无法解析目标。
   */
  openFieldAction(value: string, type: VaultFieldType): void {
    const trimmed: string = value.trim()
    if (trimmed.length === 0) {
      return
    }
    let action: string = ''
    let uri: string = ''
    if (type === VaultFieldType.Url) {
      action = ACTION_VIEW_DATA
      uri = /^[a-z][a-z0-9+.-]*:/i.test(trimmed) ? trimmed : `https://${trimmed}`
    } else if (type === VaultFieldType.Address) {
      action = ACTION_VIEW_DATA
      uri = `geo:0,0?q=${encodeURIComponent(trimmed)}`
    } else if (type === VaultFieldType.Phone) {
      action = ACTION_DIAL
      uri = `tel:${trimmed}`
    } else if (type === VaultFieldType.Email) {
      action = ACTION_SEND_TO_DATA
      uri = `mailto:${trimmed}`
    } else {
      return
    }
    const context: common.UIAbilityContext = AppUtil.getContext() as common.UIAbilityContext
    const want: Want = { action, uri }
    context.startAbility(want).catch((error: BusinessError) => {
      this.setStatus('未找到可处理该内容的应用')
      LogUtil.error(`外部动作打开失败，类型=${type}，错误码=${error.code}`)
    })
    this.recordActivity()
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

  async deleteEntry(entryUuid: string): Promise<boolean> {
    this.busy = true
    try {
      await stageOneVaultStore.deleteEntry(entryUuid)
      // 首页快照由调用方在动画上下文里重建：卡片出场与其余卡片上移才有转场动画。
      this.revision++
      this.setStatus('')
      this.recordActivity()
      return true
    } catch (error) {
      this.reportBoundaryError('删除条目失败', error)
      return false
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
      appSessionState.setCurrentModule(ROUTE_VAULT)
      appRouter.clearToHome()
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
      appRouter.lockToUnlock()
    }
  }

  onSensitiveEpochChanged(): void {
    this.generator.clearSensitiveState()
  }

  onForegroundEpochChanged(): void {
    const locked: boolean = this.session.onForeground()
    this.refreshVault()
    if (locked && this.isUnlockedRoute()) {
      appRouter.lockToUnlock()
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

  topLevelGroups(): VaultGroup[] {
    this.revision
    return stageOneVaultStore.topLevelGroups()
  }

  entry(entryUuid: string): VaultEntry {
    this.revision
    return stageOneVaultStore.entry(entryUuid)
  }

  field(entry: VaultEntry, key: string): string {
    this.revision
    return stageOneVaultStore.field(entry, key)
  }

  loadEntryAvatar(entryUuid: string): ArrayBuffer | undefined {
    this.revision
    return stageOneVaultStore.loadEntryAvatar(entryUuid)
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
    if (appRouter.isHomePage()) {
      return true
    }
    return appRouter.currentRoute !== '' && appRouter.currentRoute !== ROUTE_WELCOME &&
      appRouter.currentRoute !== ROUTE_CREATE_VAULT && appRouter.currentRoute !== ROUTE_FILE_SUMMARY &&
      appRouter.currentRoute !== ROUTE_UNLOCK
  }

  private refreshVault(): void {
    this.revision++
    this.refreshHomeSnapshot()
  }

  /**
   * 只重建首页列表快照，不推进 revision。条目增删保存后快照的刷新时机由调用方决定：
   * 首页在动画上下文里调用，让列表增删、重排在可见时播出转场动画。
   */
  refreshHomeSnapshot(): void {
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
