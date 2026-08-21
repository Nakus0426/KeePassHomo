import { AppStorageV2 } from '@kit.ArkUI'
import { ROUTE_VAULT } from '../constants/RouteConstants'

@ObservedV2
export class AppSessionState {
  @Trace privacyCovered: boolean = true
  @Trace vaultLocked: boolean = true
  @Trace sensitiveEpoch: number = 0
  @Trace foregroundEpoch: number = 0
  @Trace currentModule: string = ROUTE_VAULT

  onCreate(): void {
    this.privacyCovered = true
    this.vaultLocked = true
    this.sensitiveEpoch = 0
    this.foregroundEpoch = 0
    this.currentModule = ROUTE_VAULT
  }

  onForeground(): void {
    this.privacyCovered = true
    this.foregroundEpoch++
  }

  onBackground(): void {
    this.privacyCovered = true
    this.sensitiveEpoch++
  }

  setCurrentModule(route: string): void {
    this.currentModule = route
  }
}

export const appSessionState: AppSessionState = AppStorageV2.connect(
  AppSessionState,
  'appSession',
  () => new AppSessionState(),
) as AppSessionState
