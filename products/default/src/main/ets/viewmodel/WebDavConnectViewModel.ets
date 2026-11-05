import {
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
  Confirm = 2
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
  // 「下一步」触发的连接尝试，测试连接为可选操作，不经测试也可直接下一步。
  @Trace advancing: boolean = false
  // 面包屑层级名称：与 urlStack 一一对应（不含根层），供路径导航展示。
  @Trace pathNames: string[] = []
  private readonly client: WebDavClient = new WebDavClient()
  private urlStack: string[] = []

  @Computed
  get canTest(): boolean {
    return this.host.trim().length > 0 && this.username.trim().length > 0 && this.password.length > 0
      && this.connectStatus !== WebDavConnectStatus.Testing && !this.advancing
  }

  // 必填项填完即可下一步，无需先测试连接；实际连接在下一步时进行，失败就地报错。
  @Computed
  get canGoNextFromServer(): boolean {
    return this.host.trim().length > 0 && this.username.trim().length > 0 && this.password.length > 0
      && this.connectStatus !== WebDavConnectStatus.Testing && !this.advancing
  }

  @Computed
  get canGoNextFromFile(): boolean {
    return this.selected !== undefined
  }

  @Computed
  get canGoUp(): boolean {
    // urlStack 非响应式；pathNames 与层级一一对应，用它驱动按钮可用态。
    return this.pathNames.length > 0
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

  // 只做连接探测，失败当场写 connectFailure；成功后由页面先播反馈再调用 enterFiles。
  async probeServer(): Promise<boolean> {
    if (!this.canGoNextFromServer) {
      return false
    }
    this.advancing = true
    this.connectStatus = WebDavConnectStatus.Idle
    this.connectFailure = undefined
    try {
      await this.client.probe(this.baseUrl(), this.username.trim(), this.password)
    } catch (error) {
      this.connectFailure = this.categoryOf(error)
      this.connectStatus = WebDavConnectStatus.Failed
      this.logFailure('WebDAV 连接失败', error)
      this.advancing = false
      return false
    }
    this.advancing = false
    return true
  }

  async enterFiles(): Promise<void> {
    const base: string = this.baseUrl()
    this.urlStack = [base]
    this.pathNames = []
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
    this.pathNames = this.pathNames.concat([entry.name])
    this.currentUrl = next
    this.selected = undefined
  }

  // 面包屑跳转：depth 为保留的层数，0 回根层，与 urlStack 下标一致。
  async goToDepth(depth: number): Promise<void> {
    if (this.listStatus === WebDavListStatus.Loading || depth < 0 || depth >= this.urlStack.length) {
      return
    }
    if (depth === this.urlStack.length - 1) {
      return
    }
    const target: string = this.urlStack[depth]
    if (!await this.loadDirectory(target)) {
      return
    }
    this.urlStack = this.urlStack.slice(0, depth + 1)
    this.pathNames = this.pathNames.slice(0, depth)
    this.currentUrl = target
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
    this.pathNames = this.pathNames.slice(0, this.pathNames.length - 1)
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
      this.step = WebDavStep.Confirm
    }
  }

  // 步骤条只允许回退到已完成步骤，前进必须走「下一步」。
  goToStep(index: number): void {
    if (index >= this.step) {
      return
    }
    this.step = index
    if (index === WebDavStep.Server) {
      this.resetServerStepState()
    }
  }

  backStep(): boolean {
    if (this.step === WebDavStep.Server) {
      return false
    }
    this.step--
    if (this.step === WebDavStep.Server) {
      this.resetServerStepState()
    }
    return true
  }

  // 确认保险库后进入通用解锁页：仅登记远端目标，密码/密钥文件与失败提示都在解锁页完成。
  goToUnlock(): void {
    if (this.selected === undefined) {
      return
    }
    const target: WebDavVaultTarget = {
      username: this.username.trim(),
      webDavPassword: this.password,
      fileUrl: this.selected.url,
      fileName: this.selected.name,
      modifiedAt: this.selected.modifiedAt,
    }
    appViewModel.openWebDavUnlock(target)
  }

  fileMeta(entry: WebDavEntry): string {
    const size: string = FileUtil.getFormatFileSize(entry.size, 1)
    return `${size} · ${this.relativeTime(entry.modifiedAt)}`
  }

  clearSensitive(): void {
    this.password = ''
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
    this.pathNames = []
  }

  // 返回「连接服务器」时隐藏连接结果，保留已填写的表单，按钮恢复可点击。
  private resetServerStepState(): void {
    this.connectStatus = WebDavConnectStatus.Idle
    this.connectFailure = undefined
    this.entries = []
    this.listStatus = WebDavListStatus.Idle
    this.listFailure = undefined
    this.selected = undefined
    this.urlStack = []
    this.pathNames = []
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

  private logFailure(operation: string, error: Object): void {
    const message: string = error instanceof Error ? error.message : String(error)
    LogUtil.error(`${operation}：${message}`)
  }
}
