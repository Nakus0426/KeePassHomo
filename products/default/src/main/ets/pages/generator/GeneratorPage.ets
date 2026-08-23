import { uiMaterial } from '@kit.ArkUI'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { MemorableCase } from '@ohos/common'
import { GeneratorMode, GeneratorViewModel } from '../../viewmodel/GeneratorViewModel'
import { PageTopBar } from '../../components/PageChrome'
import { GeneratorContent } from './GeneratorComponents'

@ComponentV2
export struct GeneratorPage {
  @Param viewModel: GeneratorViewModel = new GeneratorViewModel()
  @Param clipboardSeconds: number = 0
  @Event onLock: () => void = () => {
  }
  @Event onCopy: (value: string) => void = () => {
  }
  @Event onActivity: () => void = () => {
  }
  @Event onShown: () => void = () => {
  }
  @Event onRootBack: () => void = () => {
  }

  build() {
    HdsNavDestination() {
      Column({ space: 12 }) {
        PageTopBar({
          title: $r('app.string.password_generator'),
          showLock: true,
          onLock: () => this.onLock(),
        })
        GeneratorContent({
          viewModel: this.viewModel,
          clipboardSeconds: this.clipboardSeconds,
          onCopy: (value: string) => this.onCopy(value),
          onActivity: () => this.onActivity(),
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
    .onShown(() => this.onShown())
    .onHidden(() => this.viewModel.clearSensitiveState())
    .onBackPressed(() => {
      this.onRootBack()
      return true
    })
  }
}
