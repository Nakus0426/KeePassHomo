import {
  VaultEngineError,
  VaultEngineErrorCategory,
  WebDavClient,
  WebDavEntry,
  WebDavProbeError,
  WebDavProbeErrorCategory,
} from '@ohos/common'
import { FileUtil, LogUtil } from '@pura/harmony-utils'
import { WebDavVaultTarget } from '../model/StageOneVaultStore'
import { appViewModel } from './AppViewModel'

export enum WebDavStep {
  Server = 0,
  File = 1,
  Unlock = 2
}

export enum WebDavConnectStatus {
  Idle = 'idle',
  Testing = 'testing',
  Ready = 'ready',
  Failed = 'failed'
}

export enum WebDavListStatus {
  Idle = 'idle',
  Loading = 'loading',
  Ready = 'ready',
  Failed = 'failed'
}

export enum WebDavUnlockFailure {
  None = 'none',
  InvalidCredential = 'invalidCredential',
  Network = 'network',
  Other = 'other'
}

const DAY_MS: number = 24 * 60 * 60 * 1000

@ObservedV2
export class WebDavConnectViewModel {
  @Trace step: number = WebDavStep.Server
  @Trace host: string = ''
  @Trace username: string = ''
  @Trace password: string = ''
  @Trace connectStatus: WebDavConnectStatus = WebDavConnectStatus.Idle
  @Trace connectFailure: WebDavProbeErrorCategory | undefined = undefined
  @Trace entries: WebDavEntry[] = []
  @Trace currentUrl: string = ''
  @Trace listStatus: WebDavListStatus = WebDavListStatus.Idle
  @Trace listFailure: WebDavProbeErrorCategory | undefined = undefined
  @Trace selected: WebDavEntry | undefined = undefined
  @Trace masterPassword: string = ''
  @Trace opening: boolean = false
  @Trace unlockFailure: WebDavUnlockFailure = WebDavUnlockFailure.None
  private readonly client: WebDavClient = new WebDavClient()
  private urlStack: string[] = []

  @Computed
  get canTest(): boolean {
    return this.host.trim().length > 0 && this.connectStatus !== WebDavConnectStatus.Testing
  }

  @Computed
  get canGoNextFromServer(): boolean {
    return this.connectStatus === WebDavConnectStatus.Ready && this.listStatus !== WebDavListStatus.Loading
  }

  @Computed
  get canGoNextFromFile(): boolean {
    return this.selected !== undefined
  }

  @Computed
  get canGoUp(): boolean {
    return this.urlStack.length > 1
  }

  @Computed
  get displayPath(): string {
    if (this.currentUrl.length === 0) {
      return ''
    }
    return this.pathOf(this.currentUrl)
  }

  @Computed
  get isTesting(): boolean {
    return this.connectStatus === WebDavConnectStatus.Testing
  }

  setHost(value: string): void {
    // 输入框已固定前缀 https://，粘贴完整 URL 时去掉重复协议头。
    this.host = value.trim().replace(/^https?:\/\//i, '')
    this.resetConnection()
  }

  setUsername(value: string): void {
    this.username = value
    this.resetConnection()
  }

  setPassword(value: string): void {
    this.password = value
    this.resetConnection()
  }

  setMasterPassword(value: string): void {
    this.masterPassword = value
    this.unlockFailure = WebDavUnlockFailure.None
  }

  async testConnection(): Promise<void> {
    if (!this.canTest) {
      return
    }
    this.connectStatus = WebDavConnectStatus.Testing
    this.connectFailure = undefined
    try {
      await this.client.probe(this.baseUrl(), this.username.trim(), this.password)
      this.connectStatus = WebDavConnectStatus.Ready
    } catch (error) {
      this.connectFailure = this.categoryOf(error)
      this.connectStatus = WebDavConnectStatus.Failed
      this.logFailure('WebDAV 测试连接失败', error)
    }
  }

  async nextFromServer(): Promise<void> {
    if (!this.canGoNextFromServer) {
      return
    }
    const base: string = this.baseUrl()
    this.urlStack = [base]
    this.currentUrl = base
    this.selected = undefined
    this.step = WebDavStep.File
    await this.loadDirectory(base)
  }

  async refresh(): Promise<void> {
    if (this.currentUrl.length === 0 || this.listStatus === WebDavListStatus.Loading) {
      return
    }
    await this.loadDirectory(this.currentUrl)
  }

  async enterFolder(entry: WebDavEntry): Promise<void> {
    if (!entry.isCollection || this.listStatus === WebDavListStatus.Loading) {
      return
    }
    const next: string = entry.url.endsWith('/') ? entry.url : `${entry.url}/`
    if (!await this.loadDirectory(next)) {
      return
    }
    this.urlStack.push(next)
    this.currentUrl = next
    this.selected = undefined
  }

  async goUp(): Promise<void> {
    if (!this.canGoUp || this.listStatus === WebDavListStatus.Loading) {
      return
    }
    const parent: string = this.urlStack[this.urlStack.length - 2]
    if (!await this.loadDirectory(parent)) {
      return
    }
    this.urlStack.pop()
    this.currentUrl = parent
    this.selected = undefined
  }

  selectFile(entry: WebDavEntry): void {
    if (entry.isCollection || !entry.name.toLowerCase().endsWith('.kdbx')) {
      return
    }
    this.selected = entry
  }

  nextFromFile(): void {
    if (this.selected !== undefined) {
      this.step = WebDavStep.Unlock
    }
  }

  // 步骤条只允许回退到已完成步骤，前进必须走「下一步」。
  goToStep(index: number): void {
    if (index >= this.step) {
      return
    }
    this.step = index
    if (index < WebDavStep.Unlock) {
      this.unlockFailure = WebDavUnlockFailure.None
    }
  }

  backStep(): boolean {
    if (this.step === WebDavStep.Server) {
      return false
    }
    this.step--
    this.unlockFailure = WebDavUnlockFailure.None
    return true
  }

  async openVault(): Promise<void> {
    if (this.opening || this.selected === undefined) {
      return
    }
    this.opening = true
    this.unlockFailure = WebDavUnlockFailure.None
    try {
      const target: WebDavVaultTarget = {
        username: this.username.trim(),
        webDavPassword: this.password,
        fileUrl: this.selected.url,
        fileName: this.selected.name,
        modifiedAt: this.selected.modifiedAt,
      }
      await appViewModel.openWebDavVault(target, this.masterPassword)
    } catch (error) {
      if (error instanceof VaultEngineError && error.category === VaultEngineErrorCategory.InvalidCredential) {
        this.unlockFailure = WebDavUnlockFailure.InvalidCredential
      } else if (error instanceof WebDavProbeError) {
        this.unlockFailure = error.category === WebDavProbeErrorCategory.Authentication
          ? WebDavUnlockFailure.InvalidCredential : WebDavUnlockFailure.Network
      } else {
        this.unlockFailure = WebDavUnlockFailure.Other
      }
      this.logFailure('WebDAV 保险库打开失败', error)
    } finally {
      this.opening = false
    }
  }

  hasKeyFile(): boolean {
    return appViewModel.currentKeyFileName().length > 0
  }

  fileMeta(entry: WebDavEntry): string {
    const size: string = FileUtil.getFormatFileSize(entry.size, 1)
    return `${size} · ${this.relativeTime(entry.modifiedAt)}`
  }

  vaultFileSize(): string {
    return this.selected === undefined ? '' : FileUtil.getFormatFileSize(this.selected.size, 1)
  }

  clearSensitive(): void {
    this.password = ''
    this.masterPassword = ''
    this.unlockFailure = WebDavUnlockFailure.None
    this.opening = false
  }

  private baseUrl(): string {
    const trimmed: string = this.host.trim()
    const withScheme: string = trimmed.startsWith('http://') || trimmed.startsWith('https://')
      ? trimmed : `https://${trimmed}`
    return withScheme.endsWith('/') ? withScheme : `${withScheme}/`
  }

  private async loadDirectory(url: string): Promise<boolean> {
    this.listStatus = WebDavListStatus.Loading
    this.listFailure = undefined
    try {
      this.entries = await this.client.list(url, this.username.trim(), this.password)
      this.listStatus = WebDavListStatus.Ready
      return true
    } catch (error) {
      this.listFailure = this.categoryOf(error)
      this.listStatus = WebDavListStatus.Failed
      this.logFailure('WebDAV 目录读取失败', error)
      return false
    }
  }

  private resetConnection(): void {
    if (this.connectStatus === WebDavConnectStatus.Testing) {
      return
    }
    this.connectStatus = WebDavConnectStatus.Idle
    this.connectFailure = undefined
    this.entries = []
    this.listStatus = WebDavListStatus.Idle
    this.listFailure = undefined
    this.selected = undefined
    this.urlStack = []
  }

  private categoryOf(error: Object): WebDavProbeErrorCategory {
    return error instanceof WebDavProbeError ? error.category : WebDavProbeErrorCategory.Other
  }

  private relativeTime(seconds: number): string {
    if (seconds <= 0) {
      return ''
    }
    const days: number = Math.floor((Date.now() - seconds * 1000) / DAY_MS)
    if (days <= 0) {
      return '今天更新'
    }
    if (days === 1) {
      return '昨天更新'
    }
    if (days < 7) {
      return `${days} 天前更新`
    }
    const weeks: number = Math.floor(days / 7)
    if (weeks < 5) {
      return `${weeks} 周前更新`
    }
    return `${Math.floor(days / 30)} 个月前更新`
  }

  private pathOf(value: string): string {
    let path: string = value
    const scheme: number = value.indexOf('://')
    if (scheme >= 0) {
      const slash: number = value.indexOf('/', scheme + 3)
      path = slash < 0 ? '/' : value.substring(slash)
    }
    try {
      return decodeURIComponent(path)
    } catch (error) {
      return path
    }
  }

  private logFailure(operation: string, error: Object): void {
    const message: string = error instanceof Error ? error.message : String(error)
    LogUtil.error(`${operation}：${message}`)
  }
}
