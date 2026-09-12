import { ResUtil } from '@pura/harmony-utils'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'

const TITLE_BAR_FILTER_ROW_HEIGHT_VP: number = 56

@ComponentV2
export struct VaultHomePage {
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState

  @Computed
  get topAvoidAreaHeight(): number {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const gapPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
    // const height = ResUtil.getNumber($r('sys.float.select'))
    return this.getUIContext()
      .px2vp(this.immersiveLayout.topAvoidAreaHeightPx + titlebarHeightPx + gapPx) + TITLE_BAR_FILTER_ROW_HEIGHT_VP
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
        }
        .width('100%')
        .height('100%')
        .padding(
          { top: this.topAvoidAreaHeight, left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
      }
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
  }
}
