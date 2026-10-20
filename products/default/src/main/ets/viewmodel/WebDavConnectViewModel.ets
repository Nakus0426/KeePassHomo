import { WebDavProbe, WebDavProbeError, WebDavProbeErrorCategory } from '@ohos/common'
import { LogUtil } from '@pura/harmony-utils'

export enum WebDavConnectStatus {
  Idle = 'idle',
  Testing = 'testing',
  Success = 'success',
  Failure = 'failure',
}

@ObservedV2
export class WebDavConnectViewModel {
  @Trace host: string = ''
  @Trace username: string = ''
  @Trace password: string = ''
  @Trace status: WebDavConnectStatus = WebDavConnectStatus.Idle
  @Trace failure: WebDavProbeErrorCategory | undefined = undefined
  private readonly probe: WebDavProbe = new WebDavProbe()

  @Computed
  get canTest(): boolean {
    return this.host.trim().length > 0 && this.status !== WebDavConnectStatus.Testing
  }

  setHost(value: string): void {
    this.host = value
    this.resetStatus()
  }

  setUsername(value: string): void {
    this.username = value
    this.resetStatus()
  }

  setPassword(value: string): void {
    this.password = value
    this.resetStatus()
  }

  async test(): Promise<void> {
    this.status = WebDavConnectStatus.Testing
    this.failure = undefined
    try {
      await this.probe.verify(`https://${this.host.trim()}`, this.username, this.password)
      this.status = WebDavConnectStatus.Success
    } catch (error) {
      if (error instanceof WebDavProbeError) {
        LogUtil.warn(`WebDAV 连接校验失败：${error.category} ${error.message}`)
        this.failure = error.category
        this.status = WebDavConnectStatus.Failure
        return
      }
      throw error as Error
    }
  }

  clearSensitive(): void {
    this.password = ''
    this.resetStatus()
  }

  private resetStatus(): void {
    if (this.status !== WebDavConnectStatus.Testing) {
      this.status = WebDavConnectStatus.Idle
      this.failure = undefined
    }
  }
}
