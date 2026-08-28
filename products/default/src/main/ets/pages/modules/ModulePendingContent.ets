import { PageTopBar } from '../../components/PageChrome'
import { vaultAppViewModel } from '../../viewmodel/VaultAppViewModel'

/**
 * 未开放模块的占位内容，由 SecurityPage / SettingsPage 等模块首页复用。
 */
@ComponentV2
export struct ModulePendingContent {
  @Param title: Resource = $r('app.string.app_title')

  build() {
    Column({ space: 16 }) {
      PageTopBar({
        title: this.title,
        showLock: true,
        onLock: () => vaultAppViewModel.lockVault(),
      })
      Column({ space: 8 }) {
        Text($r('app.string.module_pending'))
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
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
    .onTouch(() => vaultAppViewModel.recordActivity())
  }
}
