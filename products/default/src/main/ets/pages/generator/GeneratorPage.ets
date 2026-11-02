import { ResUtil } from '@pura/harmony-utils'
import { DS_PAGE_HEADER_HEIGHT_VP } from '../../components/DsPageHeader'
import { DsBottomActionBar } from '../../components/DsBottomActionBar'
import { DsButton, DsButtonTone } from '../../components/DsButton'
import { TAB_BAR_FLOAT_TOP_INSET_VP } from '../../constants/TabBarMetrics'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { GeneratorContent, generatorContentController } from './GeneratorComponents'
import { appViewModel } from '../../viewmodel/AppViewModel'

@ComponentV2
export struct GeneratorPage {
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private bottomBarHeight: number = 0

  @Computed
  get topAvoidAreaHeight(): number {
    const gapPx = ResUtil.getNumber($r('app.float.ds_space_sm').id)
    return this.getUIContext().px2vp(this.immersiveLayout.topAvoidAreaHeightPx)
      + DS_PAGE_HEADER_HEIGHT_VP + this.getUIContext().px2vp(gapPx)
  }

  @LocalBuilder
  private bottomActions() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      Row() {
        DsButton({
          label: $r('app.string.regenerate_password'),
          tone: DsButtonTone.Default,
          leadingIcon: $r('app.string.symbol_refresh'),
          fullWidth: true,
          onTap: () => appViewModel.generator.regenerate(),
        })
      }
      .layoutWeight(1)

      Row() {
        DsButton({
          label: $r('app.string.copy_password'),
          leadingIcon: $r('app.string.symbol_copy'),
          fullWidth: true,
          onTap: () => generatorContentController.copyPassword(),
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      GeneratorContent({
        viewModel: appViewModel.generator,
        controller: generatorContentController,
        topOffset: this.topAvoidAreaHeight,
        bottomOffset: this.bottomBarHeight + TAB_BAR_FLOAT_TOP_INSET_VP,
        onActivity: () => appViewModel.recordActivity(),
      })

      DsBottomActionBar({
        includeSafeArea: false,
        onHeightChange: (height: number) => {
          this.bottomBarHeight = height
        },
        contentBuilder: this.bottomActions,
      })
        .margin({ bottom: TAB_BAR_FLOAT_TOP_INSET_VP })
    }
    .width('100%')
    .height('100%')
  }
}
