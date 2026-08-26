import { HdsNavDestination } from '@kit.UIDesignKit'
import { ROUTE_UNLOCK } from '../../constants/RouteConstants'
import { StatusText } from '../../components/PageChrome'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { VaultAppViewModel } from '../../viewmodel/VaultAppViewModel'

@ComponentV2
export struct UnlockPage {
  @Param viewModel: VaultAppViewModel = new VaultAppViewModel()
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Event onRootBack: () => void = () => {
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
          TextInput({ placeholder: $r('app.string.master_password'), text: this.viewModel.unlockPassword })
            .type(this.viewModel.showUnlockPassword ? InputType.Normal : InputType.Password)
            .height($r('app.float.control_height'))
            .layoutWeight(1)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .onChange((value: string) => this.viewModel.setUnlockPassword(value))
          Button(this.viewModel.showUnlockPassword ? $r('app.string.hide') : $r('app.string.show'))
            .height($r('app.float.control_height'))
            .backgroundColor($r('sys.color.comp_emphasize_secondary'))
            .fontColor($r('sys.color.brand'))
            .onClick(() => this.viewModel.showUnlockPassword
              ? this.viewModel.hidePasswords() : this.viewModel.revealPassword(ROUTE_UNLOCK))
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
          .enabled(!this.viewModel.busy && !this.viewModel.unlockBlocked && this.viewModel.unlockPassword.length > 0)
          .backgroundColor($r('sys.color.brand'))
          .onClick(() => this.viewModel.unlockVault())
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
    .onShown(() => this.viewModel.showRoute(ROUTE_UNLOCK))
    .onBackPressed(() => {
      this.onRootBack()
      return true
    })
  }
}

