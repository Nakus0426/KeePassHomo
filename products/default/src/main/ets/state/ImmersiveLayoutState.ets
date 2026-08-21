import { AppStorageV2 } from '@kit.ArkUI'

@ObservedV2
export class ImmersiveLayoutState {
  @Trace topAvoidAreaHeightPx: number = 0
  @Trace bottomAvoidAreaHeightPx: number = 0

  setTopAvoidAreaHeight(heightPx: number): void {
    this.topAvoidAreaHeightPx = heightPx
  }

  setBottomAvoidAreaHeight(heightPx: number): void {
    this.bottomAvoidAreaHeightPx = heightPx
  }

  reset(): void {
    this.topAvoidAreaHeightPx = 0
    this.bottomAvoidAreaHeightPx = 0
  }
}

export const immersiveLayoutState: ImmersiveLayoutState = AppStorageV2.connect(
  ImmersiveLayoutState,
  'immersiveLayout',
  () => new ImmersiveLayoutState(),
) as ImmersiveLayoutState
