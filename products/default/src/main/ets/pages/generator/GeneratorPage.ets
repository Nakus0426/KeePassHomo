import { ResUtil } from '@pura/harmony-utils'
import { TAB_BAR_FLOAT_TOP_INSET_VP } from '../../constants/TabBarMetrics'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { GeneratorContent, generatorContentController } from './GeneratorComponents'
import { appViewModel } from '../../viewmodel/AppViewModel'

@ComponentV2
export struct GeneratorPage {
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState

  @Computed
  get topAvoidAreaHeight(): number {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const gapPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
    return this.getUIContext()
      .px2vp(this.immersiveLayout.topAvoidAreaHeightPx + titlebarHeightPx + gapPx)
  }

  @Computed
  get bottomOffset(): number {
    const gapPx: number = ResUtil.getNumber($r('sys.float.padding_level8').id)
    const gapVp: number = this.getUIContext().px2vp(gapPx)
    return TAB_BAR_FLOAT_TOP_INSET_VP + gapVp
  }

  build() {
    GeneratorContent({
      viewModel: appViewModel.generator,
      controller: generatorContentController,
      topOffset: this.topAvoidAreaHeight,
      bottomOffset: this.bottomOffset,
      onActivity: () => appViewModel.recordActivity(),
    })
  }
}
