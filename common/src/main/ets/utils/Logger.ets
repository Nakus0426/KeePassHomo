import { hilog } from '@kit.PerformanceAnalysisKit';

export class Logger {
  private readonly prefix: string = 'KeePassHomo'
  private readonly domain: number = 0xD001

  public debug(message: string): void {
    hilog.debug(this.domain, this.prefix, '%{public}s', message)
  }

  public info(message: string): void {
    hilog.info(this.domain, this.prefix, '%{public}s', message)
  }

  public warn(message: string): void {
    hilog.warn(this.domain, this.prefix, '%{public}s', message)
  }

  public error(message: string): void {
    hilog.error(this.domain, this.prefix, '%{public}s', message)
  }
}
