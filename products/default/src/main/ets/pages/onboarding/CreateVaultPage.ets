import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { ROUTE_CREATE_VAULT } from '../../constants/RouteConstants'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { ColorModeState, colorModeState } from '../../state/ColorModeState'
import { VaultAppViewModel } from '../../viewmodel/VaultAppViewModel'
import { ColorUtil } from '@ohos/common'
import { LogUtil, ResUtil } from '@pura/harmony-utils'
import { FormItem } from '../../components/FormItem'

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
  get scrollBottomAvoidAreaHeight() {
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

  @Builder
  vaultNameBuilder() {
    TextInput({ placeholder: $r('app.string.text_input_placeholder'), text: this.viewModel?.vaultName })
      .height($r('app.float.control_height'))
      .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .onChange((value: string) => this.viewModel.setVaultName(value))
  }

  @Builder
  saveLocationBuilder() {
    Button() {
      Row({ space: $r('sys.float.padding_level4') }) {
        Text(this.viewModel?.createFileName?.length === undefined || this.viewModel.createFileName.length === 0
          ? $r('app.string.select_placeholder') : this.viewModel?.createFileName)
          .fontColor($r('sys.color.font_secondary'))
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize($r('sys.float.Title_S'))
          .fontColor([$r('sys.color.font_secondary')])
      }
      .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
    }
    .width('100%')
    .height($r('app.float.control_height'))
    .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .onClick(() => this.viewModel?.chooseCreateLocation())
  }

  @Builder
  masterPasswordBuilder() {
    TextInput({ placeholder: $r('app.string.text_input_placeholder'), text: this.viewModel?.masterPassword })
      .type(InputType.Password)
      .height($r('app.float.control_height'))
      .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .onChange((value: string) => this.viewModel?.setMasterPassword(value))
  }

  @Builder
  confirmPasswordBuilder() {
    TextInput({ placeholder: $r('app.string.text_input_placeholder'), text: this.viewModel?.confirmPassword })
      .type(InputType.Password)
      .height($r('app.float.control_height'))
      .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .onChange((value: string) => this.viewModel?.setConfirmPassword(value))
  }

  @Builder
  keyFileBuilder() {
    Button() {
      Row({ space: $r('sys.float.padding_level4') }) {
        Text(
          this.viewModel?.currentKeyFileName()?.length === undefined || this.viewModel.currentKeyFileName().length === 0
            ? $r('app.string.select_placeholder') : this.viewModel?.currentKeyFileName())
          .fontColor($r('sys.color.font_secondary'))
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize($r('sys.float.Title_S'))
          .fontColor([$r('sys.color.font_secondary')])
      }
      .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
    }
    .width('100%')
    .height($r('app.float.control_height'))
    .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .onClick(() => this.viewModel?.chooseCreateLocation())
  }

  build() {
    HdsNavDestination() {
      Stack() {
        Scroll() {
          Column() {
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

            FormItem(
              { label: $r('app.string.vault_name'), contentBuilder: this.vaultNameBuilder, reserveFeedbackSpace: true })

            FormItem({
              label: $r('app.string.save_location'),
              contentBuilder: this.saveLocationBuilder,
              reserveFeedbackSpace: true,
            })

            FormItem({
              label: $r('app.string.master_password'),
              contentBuilder: this.masterPasswordBuilder,
              reserveFeedbackSpace: true,
            })

            FormItem({
              label: $r('app.string.confirm_password'),
              contentBuilder: this.masterPasswordBuilder,
              reserveFeedbackSpace: true,
            })

            FormItem({
              label: $r('app.string.key_file_label'),
              contentBuilder: this.keyFileBuilder,
              reserveFeedbackSpace: true,
            })

            Row({ space: $r('sys.float.padding_level8') }) {
              Stack() {
                SymbolGlyph($r('sys.symbol.folder_fill'))
                  .fontSize($r('sys.float.Title_L'))
                  .fontColor([$r('sys.color.brand')])
              }
              .padding($r('sys.float.padding_level4'))
              .borderRadius('50%')
              .backgroundColor($r('sys.color.comp_emphasize_secondary'))

              Column({ space: $r('sys.float.padding_level2') }) {
                Text() {
                  Span($r('app.string.format'))
                    .fontColor($r('sys.color.font_secondary'))
                  Span(' ')
                  Span($r('app.string.kdbx4'))
                    .fontColor($r('sys.color.font_primary'))
                    .fontWeight(FontWeight.Medium)
                }

                Text() {
                  Span($r('app.string.credential'))
                    .fontColor($r('sys.color.font_secondary'))
                  Span(' ')
                  Span(this.viewModel.currentKeyFileName().length === 0
                    ? $r('app.string.create_summary_without_key_file') : $r('app.string.create_summary_with_key_file'))
                    .fontColor($r('sys.color.font_primary'))
                    .fontWeight(FontWeight.Medium)
                }
              }
              .alignItems(HorizontalAlign.Start)
            }
            .padding($r('sys.float.padding_level8'))
            .backgroundColor($r('sys.color.comp_background_tertiary'))
            .borderRadius($r('sys.float.corner_radius_level10'))
            .width('100%')
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
            .height($r('app.float.control_height'))
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

