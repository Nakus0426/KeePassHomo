import { ResUtil } from '@pura/harmony-utils'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { GeneratorContent, GeneratorContentController } from './GeneratorComponents'
import { appViewModel } from '../../viewmodel/AppViewModel'

@ComponentV2
export struct GeneratorPage {
  @Param controller: GeneratorContentController = new GeneratorContentController()
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
    const barHeightPx = ResUtil.getNumber($r('app.float.module_navigation_bar_height').id)
    return this.getUIContext()
      .px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx + barHeightPx)
  }

  build() {
    GeneratorContent({
      viewModel: appViewModel.generator,
      controller: this.controller,
      topOffset: this.topAvoidAreaHeight,
      bottomOffset: this.bottomOffset,
      onActivity: () => appViewModel.recordActivity(),
    })
  }
}
