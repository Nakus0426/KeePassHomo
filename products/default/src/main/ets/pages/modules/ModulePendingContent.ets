import { appViewModel } from '../../viewmodel/AppViewModel'

/**
 * 未开放模块的占位内容，由对应模块页签直接复用。
 */
@ComponentV2
export struct ModulePendingContent {
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
      bottom: $r('app.float.module_content_bottom_padding'),
      left: $r('sys.float.padding_level12'),
    })
    .onTouch(() => appViewModel.recordActivity())
  }
}
