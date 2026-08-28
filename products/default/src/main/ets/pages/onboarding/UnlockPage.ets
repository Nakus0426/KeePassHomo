import { HdsNavDestination } from '@kit.UIDesignKit'
import { ROUTE_UNLOCK } from '../../constants/RouteConstants'
import { PASSWORD_REVEAL_SECONDS } from '../../constants/SecurityConstants'
import { StatusText } from '../../components/PageChrome'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { appRouter } from '../../navigation/AppRouter'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'

@ComponentV2
export struct UnlockPage {
  private readonly viewModel: AppViewModel = appViewModel
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private unlockPassword: string = ''
  @Local private showUnlockPassword: boolean = false
  private revealTimer: number = -1

  private revealPassword(): void {
    this.showUnlockPassword = true
    this.revealTimer = setTimeout(() => this.showUnlockPassword = false, PASSWORD_REVEAL_SECONDS * 1000)
  }

  private hidePassword(): void {
    this.showUnlockPassword = false
    if (this.revealTimer >= 0) {
      clearTimeout(this.revealTimer)
      this.revealTimer = -1
    }
  }

  build() {
    HdsNavDestination() {
      Column({ space: 20 }) {
        Blank()
        Image($r('app.media.launch_icon'))
          .width($r('app.float.icon_large'))
          .height($r('app.float.icon_large'))
        Text($r('app.string.unlock_vault'))
          .fontSize($r('sys.float.Title_L'))
          .fontWeight(FontWeight.Bold)
        Text(this.viewModel.hasRecentVault() ? this.viewModel.currentSource().displayName : '')
          .fontSize($r('app.float.text_heading'))
          .fontWeight(FontWeight.Medium)
        Text($r('app.string.local_file'))
          .fontColor($r('sys.color.font_secondary'))
        Row({ space: 8 }) {
          TextInput({ placeholder: $r('app.string.master_password'), text: this.unlockPassword })
            .type(this.showUnlockPassword ? InputType.Normal : InputType.Password)
            .height($r('app.float.control_height'))
            .layoutWeight(1)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .onChange((value: string) => this.unlockPassword = value)
          Button(this.showUnlockPassword ? $r('app.string.hide') : $r('app.string.show'))
            .height($r('app.float.control_height'))
            .backgroundColor($r('sys.color.comp_emphasize_secondary'))
            .fontColor($r('sys.color.brand'))
            .onClick(() => this.showUnlockPassword ? this.hidePassword() : this.revealPassword())
        }
        .width('100%')

        Button(this.viewModel.currentKeyFileName().length === 0
          ? $r('app.string.key_file_label') : this.viewModel.currentKeyFileName())
          .width('100%')
          .height($r('app.float.control_height'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => this.viewModel.chooseKeyFile())
        StatusText({ status: this.viewModel.status })
        Button(this.viewModel.busy ? $r('app.string.unlocking') : $r('app.string.unlock_vault'))
          .width('100%')
          .height($r('app.float.control_height'))
          .enabled(!this.viewModel.busy && !this.viewModel.unlockBlocked && this.unlockPassword.length > 0)
          .backgroundColor($r('sys.color.brand'))
          .onClick(() => this.viewModel.unlockVault(this.unlockPassword))
        Button($r('app.string.choose_another_vault'))
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.brand'))
          .onClick(() => this.viewModel.chooseAnotherVault())
        Blank()
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding($r('sys.float.padding_level12'))
      .alignItems(HorizontalAlign.Center)
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .padding({
      top: this.getUIContext().px2vp(this.immersiveLayout.topAvoidAreaHeightPx),
      bottom: this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx),
    })
    .onHidden(() => this.hidePassword())
    .onBackPressed(() => {
      appRouter.handleRootBack(ROUTE_UNLOCK)
      return true
    })
  }
}

@Builder
export function unlockPageBuilder() {
  UnlockPage()
}
