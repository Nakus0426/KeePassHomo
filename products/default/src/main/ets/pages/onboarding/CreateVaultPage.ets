import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { ROUTE_CREATE_VAULT } from '../../constants/RouteConstants'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { ColorModeState, colorModeState } from '../../state/ColorModeState'
import { VaultAppViewModel } from '../../viewmodel/VaultAppViewModel'
import { ColorUtil } from '@ohos/common'
import { LogUtil, ResUtil } from '@pura/harmony-utils'

@ComponentV2
export struct CreateVaultPage {
  @Param viewModel: VaultAppViewModel = new VaultAppViewModel()
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private colorMode: ColorModeState = colorModeState

  @Computed
  get topAvoidAreaHeight() {
    let res: number = 0
    try {
      const titlebarDefaultHeightPx =
        ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
      const paddingTopPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
      res =
        this.getUIContext().px2vp(this.immersiveLayout.topAvoidAreaHeightPx + titlebarDefaultHeightPx + paddingTopPx)
    } catch (error) {
      LogUtil.error(error.message)
    }

    return res
  }

  @Computed
  get bottomAvoidAreaHeight() {
    return this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx)
  }

  @Computed
  get bottomGradientColors(): Array<[ResourceColor, number]> {
    this.colorMode.isDark
    const backgroundColor: ResourceColor = $r('sys.color.background_secondary')
    return [
      [ColorUtil.withAlphaHex(backgroundColor, 0), 0.0],
      [ColorUtil.withAlphaHex(backgroundColor, 1), 1.0],
    ]
  }

  build() {
    HdsNavDestination() {
      Stack() {
        Scroll() {
          Column({ space: $r('sys.float.padding_level6') }) {
            Column({ space: $r('sys.float.padding_level6') }) {
              Image($r('app.media.safe'))
                .width('128vp')
                .height('128vp')
              Text($r('app.string.create_vault'))
                .fontSize($r('sys.float.Title_L'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
              Text($r('app.string.create_vault_description'))
                .fontSize($r('sys.float.Body_M'))
                .fontColor($r('sys.color.font_secondary'))
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
            .margin({ bottom: $r('sys.float.padding_level8') })
            
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
          }
          .width('100%')
          .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .padding(
          { top: this.topAvoidAreaHeight, left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

        Row({ space: $r('sys.float.padding_level6') }) {
          Button(this.viewModel.busy ? $r('app.string.creating') : $r('app.string.create_vault'))
            .enabled(!this.viewModel.busy)
            .backgroundColor($r('sys.color.brand'))
            .layoutWeight(1)
            .zIndex(1)
            .onClick(() => this.viewModel.createVault())
        }
        .position({ bottom: 0 })
        .padding({
          right: $r('sys.float.padding_level8'),
          bottom: this.bottomAvoidAreaHeight,
          left: $r('sys.float.padding_level8'),
          top: $r('sys.float.padding_level8'),
        })
        .linearGradient(
          {
            direction: GradientDirection.Bottom,
            colors: this.bottomGradientColors,
          })
      }
      .width('100%')
      .height('100%')
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      content: {
        title: {
          mainTitle: $r('app.string.create_vault'),
        },
      },
    })
    .backgroundColor($r('sys.color.background_secondary'))
    .onShown(() => {
      this.viewModel.showRoute(ROUTE_CREATE_VAULT)
    })
  }
}

