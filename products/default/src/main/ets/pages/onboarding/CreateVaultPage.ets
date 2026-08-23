import { common } from '@kit.AbilityKit'
import { uiMaterial } from '@kit.ArkUI'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { ROUTE_CREATE_VAULT, ROUTE_FILE_SUMMARY, ROUTE_UNLOCK, ROUTE_WELCOME } from '../../constants/RouteConstants'
import { PageTopBar, StatusText } from '../../components/PageChrome'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { VaultAppViewModel } from '../../viewmodel/VaultAppViewModel'

@ComponentV2
export struct CreateVaultPage {
  @Param viewModel: VaultAppViewModel = new VaultAppViewModel()
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState

  build() {
    HdsNavDestination() {
      Scroll() {
        Column({ space: 20 }) {
          PageTopBar({
            title: $r('app.string.create_vault'),
            showBack: true,
            onBack: () => this.viewModel.popRoute(),
          })
          Column({ space: 12 }) {
            Image($r('app.media.launch_icon'))
              .width($r('app.float.icon_large'))
              .height($r('app.float.icon_large'))
            Text($r('app.string.create_vault'))
              .fontSize($r('sys.float.Title_L'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Text($r('app.string.create_vault_description'))
              .fontSize($r('sys.float.Body_L'))
              .fontColor($r('sys.color.font_secondary'))
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: $r('sys.float.padding_level8'), bottom: $r('sys.float.padding_level8') })

          Text($r('app.string.vault_details'))
            .width('100%')
            .fontSize($r('app.float.text_heading'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Column({ space: 12 }) {
            Text($r('app.string.vault_name'))
              .width('100%')
              .fontColor($r('sys.color.font_secondary'))
            TextInput({ placeholder: $r('app.string.personal_vault'), text: this.viewModel.vaultName })
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.background_secondary'))
              .onChange((value: string) => this.viewModel.setVaultName(value))
            Text($r('app.string.save_location'))
              .width('100%')
              .fontColor($r('sys.color.font_secondary'))
            Button(this.viewModel.createFileName.length === 0
              ? $r('app.string.choose_save_location') : this.viewModel.createFileName)
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.background_secondary'))
              .fontColor($r('sys.color.font_primary'))
              .onClick(() => this.viewModel.chooseCreateLocation())
          }
          .width('100%')
          .padding($r('sys.float.padding_level8'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius($r('sys.float.corner_radius_level8'))

          Text($r('app.string.vault_credentials'))
            .width('100%')
            .fontSize($r('app.float.text_heading'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Column({ space: 12 }) {
            TextInput({ placeholder: $r('app.string.master_password'), text: this.viewModel.masterPassword })
              .type(InputType.Password)
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.background_secondary'))
              .onChange((value: string) => this.viewModel.setMasterPassword(value))
            TextInput({ placeholder: $r('app.string.confirm_password'), text: this.viewModel.confirmPassword })
              .type(InputType.Password)
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.background_secondary'))
              .onChange((value: string) => this.viewModel.setConfirmPassword(value))
            Text(this.viewModel.passwordStrength())
              .width('100%')
              .fontSize($r('app.float.text_caption'))
              .fontColor($r('sys.color.font_secondary'))
            if (this.viewModel.confirmPassword.length > 0 &&
              this.viewModel.masterPassword !== this.viewModel.confirmPassword) {
              Text($r('app.string.password_mismatch'))
                .width('100%')
                .fontColor($r('sys.color.warning'))
            }
            Button($r('app.string.generate_password_suggestion'))
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.comp_emphasize_secondary'))
              .fontColor($r('sys.color.brand'))
              .onClick(() => this.viewModel.generateMasterPassword())
            if (this.viewModel.generatedMasterPassword) {
              Row({ space: 8 }) {
                Checkbox({ name: 'generated_password_saved', group: 'create_vault' })
                  .select(this.viewModel.generatedPasswordSaved)
                  .onChange((value: boolean) => this.viewModel.setGeneratedPasswordSaved(value))
                Text($r('app.string.password_saved_ack'))
                  .fontSize($r('sys.float.Body_L'))
                  .fontColor($r('sys.color.font_primary'))
                  .layoutWeight(1)
              }
              .width('100%')
            }
            Button(this.viewModel.currentKeyFileName().length === 0
              ? $r('app.string.select_key_file') : this.viewModel.currentKeyFileName())
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.background_secondary'))
              .fontColor($r('sys.color.font_primary'))
              .onClick(() => this.viewModel.chooseKeyFile())
            Text($r('app.string.key_file_warning'))
              .width('100%')
              .fontSize($r('app.float.text_caption'))
              .fontColor($r('sys.color.alert'))
          }
          .width('100%')
          .padding($r('sys.float.padding_level8'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius($r('sys.float.corner_radius_level8'))

          Text($r('app.string.create_summary'))
            .width('100%')
            .fontSize($r('app.float.text_heading'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Column({ space: 8 }) {
            Text($r('app.string.format_kdbx4'))
              .width('100%')
              .fontColor($r('sys.color.font_secondary'))
            Text(this.viewModel.currentKeyFileName().length === 0
              ? $r('app.string.without_key_file') : $r('app.string.with_key_file'))
              .width('100%')
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .padding($r('sys.float.padding_level8'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius($r('sys.float.corner_radius_level8'))

          StatusText({ status: this.viewModel.status })
          Button(this.viewModel.busy ? $r('app.string.creating') : $r('app.string.create_vault'))
            .width('100%')
            .height($r('app.float.control_height'))
            .enabled(!this.viewModel.busy)
            .backgroundColor($r('sys.color.brand'))
            .onClick(() => this.viewModel.createVault())
        }
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .padding({
          top: $r('sys.float.padding_level12'),
          right: $r('sys.float.padding_level12'),
          bottom: $r('sys.float.padding_level16'),
          left: $r('sys.float.padding_level12'),
        })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .padding({
      top: this.getUIContext().px2vp(this.immersiveLayout.topAvoidAreaHeightPx),
      bottom: this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx),
    })
    .onShown(() => this.viewModel.showRoute(ROUTE_CREATE_VAULT))
  }
}

