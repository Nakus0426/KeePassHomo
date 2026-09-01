import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { ResUtil } from '@pura/harmony-utils'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { GeneratorContent, GeneratorContentController } from './GeneratorComponents'
import { GeneratorViewModel } from '../../viewmodel/GeneratorViewModel'
import { appViewModel } from '../../viewmodel/AppViewModel'

@ComponentV2
export struct GeneratorPage {
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  private readonly generator: GeneratorViewModel = appViewModel.generator
  private readonly generatorController: GeneratorContentController = new GeneratorContentController()

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
    HdsNavDestination() {
      GeneratorContent({
        viewModel: this.generator,
        controller: this.generatorController,
        bottomOffset: this.bottomOffset,
        onActivity: () => appViewModel.recordActivity(),
      })
    }
    .hideBackButton(true)
    .titleBar({
      avoidLayoutSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      content: {
        title: {
          mainTitle: $r('app.string.password_generator'),
        },
        menu: {
          value: [{
            content: {
              icon: $r('sys.symbol.doc_text_on_doc_text'),
              label: $r('app.string.copy'),
              action: () => this.generatorController.copyPassword(),
            },
          }],
        },
      },
    })
    .backgroundColor($r('sys.color.background_secondary'))
    .onHidden(() => this.generator.clearSensitiveState())
  }
}

@Builder
export function generatorPageBuilder() {
  GeneratorPage()
}
