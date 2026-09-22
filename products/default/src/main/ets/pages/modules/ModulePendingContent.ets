import { ResUtil } from '@pura/harmony-utils'
import { TAB_BAR_FLOAT_TOP_INSET_VP } from '../../constants/TabBarMetrics'
import { appViewModel } from '../../viewmodel/AppViewModel'

/**
 * 未开放模块的占位内容，由对应模块页签直接复用。
 */
@ComponentV2
export struct ModulePendingContent {
  @Computed
  get bottomInset(): number {
    const gapPx: number = ResUtil.getNumber($r('sys.float.padding_level8').id)
    const gapVp: number = this.getUIContext().px2vp(gapPx)
    return TAB_BAR_FLOAT_TOP_INSET_VP + gapVp
  }

  build() {
    Column({ space: 8 }) {
      Text($r('app.string.module_pending'))
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .justifyContent(FlexAlign.Center)
    .padding({
      top: $r('sys.float.padding_level12'),
      right: $r('sys.float.padding_level12'),
      bottom: this.bottomInset,
      left: $r('sys.float.padding_level12'),
    })
    .onTouch(() => appViewModel.recordActivity())
  }
}
