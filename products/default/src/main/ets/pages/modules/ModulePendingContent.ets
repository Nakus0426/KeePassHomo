import { UIContext } from '@kit.ArkUI'
import { ResUtil } from '@pura/harmony-utils'
import { TAB_BAR_FLOAT_TOP_INSET_VP } from '../../constants/TabBarMetrics'
import { appViewModel } from '../../viewmodel/AppViewModel'

// 无状态占位内容，按性能规则用全局 @Builder 承载，不引入自定义组件。
@Builder
export function ModulePendingContent() {
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
    bottom: pendingBottomInset(),
    left: $r('sys.float.padding_level12'),
  })
  .onTouch(() => appViewModel.recordActivity())
}

// 全局 @Builder 没有 this，底栏避让所需的 vp 换算走当前 UI 实例。
function pendingBottomInset(): number {
  const gapPx: number = ResUtil.getNumber($r('sys.float.padding_level8').id)
  return TAB_BAR_FLOAT_TOP_INSET_VP + UIContext.resolveUIContext().px2vp(gapPx)
}
