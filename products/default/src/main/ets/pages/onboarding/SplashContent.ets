import { common } from '@kit.AbilityKit'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { AppViewModel } from '../../viewmodel/AppViewModel'

@ComponentV2
export struct SplashContent {
  @Param viewModel: AppViewModel = new AppViewModel()
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  build() {
    Column({ space: 16 }) {
      Image($r('app.media.launch_icon'))
        .width($r('app.float.icon_large'))
        .height($r('app.float.icon_large'))
      Text($r('app.string.app_title'))
        .fontSize($r('app.float.text_heading'))
        .fontWeight(FontWeight.Bold)
      LoadingProgress()
        .width($r('sys.float.padding_level12'))
        .height($r('sys.float.padding_level12'))
        .color($r('sys.color.brand'))
      Text($r('app.string.preparing_vault'))
        .fontSize($r('sys.float.Body_L'))
        .fontColor($r('sys.color.font_secondary'))
      if (this.viewModel.splashTimedOut) {
        Button($r('app.string.retry'))
          .backgroundColor($r('sys.color.brand'))
          .onClick(() => this.viewModel.initialize(this.context()))
        if (this.viewModel.status.length > 0) {
          Text(this.viewModel.status)
            .fontSize($r('app.float.text_caption'))
            .fontColor($r('sys.color.warning'))
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      top: this.getUIContext().px2vp(this.immersiveLayout.topAvoidAreaHeightPx),
      bottom: this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx),
    })
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}