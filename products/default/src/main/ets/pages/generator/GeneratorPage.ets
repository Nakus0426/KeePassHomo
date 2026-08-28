import { HdsNavDestination } from '@kit.UIDesignKit'
import { ROUTE_GENERATOR } from '../../constants/RouteConstants'
import { PageTopBar } from '../../components/PageChrome'
import { GeneratorContent } from './GeneratorComponents'
import { appRouter } from '../../navigation/AppRouter'
import { GeneratorViewModel } from '../../viewmodel/GeneratorViewModel'
import { vaultAppViewModel } from '../../viewmodel/VaultAppViewModel'

@ComponentV2
export struct GeneratorPage {
  private readonly generator: GeneratorViewModel = vaultAppViewModel.generator

  build() {
    HdsNavDestination() {
      Column({ space: 12 }) {
        PageTopBar({
          title: $r('app.string.password_generator'),
          showLock: true,
          onLock: () => vaultAppViewModel.lockVault(),
        })
        GeneratorContent({
          viewModel: this.generator,
          clipboardSeconds: vaultAppViewModel.clipboardSeconds,
          onCopy: (value: string) => vaultAppViewModel.copyValue(value),
          onActivity: () => vaultAppViewModel.recordActivity(),
        })
          .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding({
        top: $r('sys.float.padding_level12'),
        right: $r('sys.float.padding_level12'),
        bottom: $r('app.float.module_content_bottom_padding'),
        left: $r('sys.float.padding_level12'),
      })
    }
    .hideTitleBar(true)
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
