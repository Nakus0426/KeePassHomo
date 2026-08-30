import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { ResUtil } from '@pura/harmony-utils'
import { ROUTE_GENERATOR } from '../../constants/RouteConstants'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { GeneratorContent } from './GeneratorComponents'
import { appRouter } from '../../navigation/AppRouter'
import { GeneratorViewModel } from '../../viewmodel/GeneratorViewModel'
import { appViewModel } from '../../viewmodel/AppViewModel'

@ComponentV2
export struct GeneratorPage {
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  private readonly generator: GeneratorViewModel = appViewModel.generator

  // 内容顶部避让 = 底部安全区之上：顶部安全区 + 标题栏高度 + padding_level8（资源数值为 px，统一换算 vp）
  @Computed
  get topAvoidAreaHeight(): number {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const gapPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
    return this.getUIContext()
      .px2vp(this.immersiveLayout.topAvoidAreaHeightPx + titlebarHeightPx + gapPx)
  }

  // 底部操作区偏移 = 底部安全区 + 模块导航栏高度 + padding_level8（资源数值为 px，统一换算 vp）
  @Computed
  get bottomOffset(): number {
    const barHeightPx = ResUtil.getNumber($r('app.float.module_navigation_bar_height').id)
    const gapPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
    return this.getUIContext()
      .px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx + barHeightPx + gapPx)
  }

  build() {
    HdsNavDestination() {
      Column() {
        GeneratorContent({
          viewModel: this.generator,
          clipboardSeconds: appViewModel.clipboardSeconds,
          bottomOffset: this.bottomOffset,
          onCopy: (value: string) => appViewModel.copyValue(value),
          onActivity: () => appViewModel.recordActivity(),
        })
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding({
        top: this.topAvoidAreaHeight,
        right: $r('sys.float.padding_level12'),
        left: $r('sys.float.padding_level12'),
      })
    }
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
      },
    })
    .backgroundColor($r('sys.color.background_secondary'))
    .onHidden(() => this.generator.clearSensitiveState())
    .onBackPressed(() => {
      appRouter.handleRootBack(ROUTE_GENERATOR)
      return true
    })
  }
}

@Builder
export function generatorPageBuilder() {
  GeneratorPage()
}
