import { SymbolGlyphModifier, uiMaterial } from '@kit.ArkUI'
import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { GeneratorContent, GeneratorContentController } from '../generator/GeneratorComponents'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { ColorModeState, colorModeState } from '../../state/ColorModeState'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { CreateVaultViewModel } from '../../viewmodel/CreateVaultViewModel'
import { AnimationTokens, BounceAnimator, ColorUtil } from '@ohos/common'
import { LogUtil, ResUtil } from '@pura/harmony-utils'
import { FormItem } from '../../components/FormItem'
import { FormTextField } from '../../components/FormTextField'
import { PasswordStrengthIndicator } from '../../components/PasswordStrengthIndicator'
import { PasswordVisibilityToggle } from '../../components/PasswordVisibilityToggle'

@ComponentV2
export struct CreateVaultPage {
  private readonly viewModel: AppViewModel = appViewModel
  @Local private form: CreateVaultViewModel = new CreateVaultViewModel()
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private colorMode: ColorModeState = colorModeState
  @Local private generatorSheetVisible: boolean = false
  @Local private masterPasswordVisible: boolean = false
  @Local private confirmPasswordVisible: boolean = false
  private readonly generatorController: GeneratorContentController = new GeneratorContentController()
  private readonly fillIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.checkmark'))
    .fontColor([$r('sys.color.confirm')])
    .fontSize($r('sys.float.titlebar_icon_width'))
  private bounce: BounceAnimator = new BounceAnimator()
  private readonly scroller: Scroller = new Scroller()

  private displayPath(uri: string): string {
    const rawPath: string = uri.startsWith('file://') ? uri.substring('file://'.length) : uri
    return decodeURIComponent(rawPath)
  }

  private handleSubmit(): void {
    const invalidFieldKey: string | undefined = this.form.validate()
    if (invalidFieldKey === undefined) {
      this.viewModel.createVault(this.form.vaultName, this.form.masterPassword)
      return
    }
    this.scrollToField(invalidFieldKey)
  }

  private scrollToField(fieldKey: string): void {
    const componentUtils = this.getUIContext().getComponentUtils()
    const fieldTopPx: number = componentUtils.getRectangleById(`field_${fieldKey}`).windowOffset.y
    const scrollTopPx: number = componentUtils.getRectangleById('create_vault_scroll').windowOffset.y
    const targetY: number = this.scroller.currentOffset().yOffset +
      this.getUIContext().px2vp(fieldTopPx - scrollTopPx) - this.topAvoidAreaHeight
    this.scroller.scrollTo({
      xOffset: 0,
      yOffset: Math.max(targetY, 0),
      animation: {
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
      },
    })
  }

  private openGeneratorSheet(): void {
    this.viewModel.prepareGenerator()
    this.generatorSheetVisible = true
  }

  private closeGeneratorSheet(): void {
    this.generatorSheetVisible = false
    this.viewModel.generator.clearSensitiveState()
  }

  private fillMasterPasswordFromGenerator(): void {
    const password: string = this.generatorController.getCurrentPassword()
    if (password.length === 0) {
      return
    }
    this.form.setMasterPassword(password)
    this.form.setConfirmPassword(password)
    this.viewModel.recordActivity()
    this.closeGeneratorSheet()
  }

  @Computed
  get topAvoidAreaHeight() {
    const titlebarHeightPx =
      ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const paddingTopPx = ResUtil.getNumber($r('sys.float.padding_level12').id)
    return this.getUIContext().px2vp(this.immersiveLayout.topAvoidAreaHeightPx + titlebarHeightPx + paddingTopPx)
  }

  @Computed
  get scrollBottomAvoidAreaHeight() {
    const buttonHeight =
      ResUtil.getNumber($r('app.float.control_height').id)
    const padding = ResUtil.getNumber($r('sys.float.padding_level8').id)
    return this.getUIContext().px2vp(this.bottomSafeAreaHeight + buttonHeight + padding * 2)
  }

  @Computed
  get sheetTopAvoidAreaHeight() {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const paddingHeightPx = ResUtil.getNumber($r('sys.float.padding_level12').id)
    return this.getUIContext().px2vp(titlebarHeightPx + paddingHeightPx)
  }

  @Computed
  get bottomSafeAreaHeight() {
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

  @Computed
  get textInputButtonSize() {
    let res: number = 0
    try {
      const buttonHeight =
        ResUtil.getNumber($r('app.float.control_height').id)
      const padding = ResUtil.getNumber($r('sys.float.padding_level4').id)
      res =
        this.getUIContext().px2vp(buttonHeight - padding * 2)
    } catch (error) {
      LogUtil.error(error.message)
    }

    return res
  }

  @LocalBuilder
  vaultNameBuilder() {
    FormTextField({
      placeholder: $r('app.string.text_input_placeholder'),
      text: this.form.vaultName,
      onChange: (value: string) => this.form.setVaultName(value),
    })
  }

  @LocalBuilder
  masterPasswordBuilder() {
    FormTextField({
      placeholder: $r('app.string.text_input_placeholder'),
      text: this.form.masterPassword,
      type: InputType.Password,
      showPassword: this.masterPasswordVisible,
      onChange: (value: string) => this.form.setMasterPassword(value),
    }) {
      PasswordVisibilityToggle({
        visible: this.masterPasswordVisible,
        onChange: (visible: boolean) => this.masterPasswordVisible = visible,
      })

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.wand_and_stars'))
          .fontSize(22)
          .fontColor([$r('sys.color.brand')])
          .scale({ x: this.bounce.scale, y: this.bounce.scale })
      }
      .width(this.textInputButtonSize)
      .height(this.textInputButtonSize)
      .backgroundColor(Color.Transparent)
      .onClick(() => this.bounce.play(this.getUIContext(), () => this.openGeneratorSheet()))
    }
  }

  @LocalBuilder
  confirmPasswordBuilder() {
    FormTextField({
      placeholder: $r('app.string.text_input_placeholder'),
      text: this.form.confirmPassword,
      type: InputType.Password,
      showPassword: this.confirmPasswordVisible,
      onChange: (value: string) => this.form.setConfirmPassword(value),
    }) {
      PasswordVisibilityToggle({
        visible: this.confirmPasswordVisible,
        onChange: (visible: boolean) => this.confirmPasswordVisible = visible,
      })
    }
  }

  @LocalBuilder
  keyFileBuilder() {
    Button() {
      Row({ space: $r('sys.float.padding_level4') }) {
        Text(
          this.viewModel?.currentKeyFileUri()?.length === undefined || this.viewModel.currentKeyFileUri().length === 0
            ? $r('app.string.select_placeholder') : this.displayPath(this.viewModel.currentKeyFileUri()))
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
    .onClick(() => this.viewModel?.chooseKeyFile())
  }

  @LocalBuilder
  private generatorSheet() {
    HdsNavigation() {
      GeneratorContent({
        viewModel: this.viewModel.generator,
        controller: this.generatorController,
        topOffset: this.sheetTopAvoidAreaHeight,
        bottomOffset: this.bottomSafeAreaHeight,
        onActivity: () => this.viewModel.recordActivity(),
      })
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
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
          mainTitle: $r('app.string.password_generator'),
        },
        menu: {
          value: [{
            content: {
              icon: $r('sys.symbol.doc_text_on_doc_text'),
              label: $r('app.string.copy'),
              action: () => this.generatorController.copyPassword(),
            },
          }, {
            content: {
              icon: this.fillIcon,
              label: $r('app.string.fill_current_entry'),
              action: () => this.fillMasterPasswordFromGenerator(),
            },
          }],
        },
      },
    })
  }

  build() {
    HdsNavDestination() {
      Stack() {
        Scroll(this.scroller) {
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
            .margin({ bottom: $r('sys.float.padding_level16') })

            FormItem(
              {
                label: $r('app.string.vault_name'),
                contentBuilder: this.vaultNameBuilder,
                value: this.form.vaultName,
                schema: this.form.vaultNameSchema,
                controller: this.form.vaultNameController,
                reserveFeedbackSpace: true,
                required: true,
              })
              .id('field_vaultName')

            FormItem({
              label: $r('app.string.master_password'),
              contentBuilder: this.masterPasswordBuilder,
              value: this.form.masterPassword,
              schema: this.form.masterPasswordSchema,
              controller: this.form.masterPasswordController,
              reserveFeedbackSpace: true,
              required: true,
            })
              .id('field_masterPassword')

            FormItem({
              label: $r('app.string.confirm_password'),
              contentBuilder: this.confirmPasswordBuilder,
              value: this.form.confirmPassword,
              schema: this.form.confirmPasswordSchema,
              controller: this.form.confirmPasswordController,
              reserveFeedbackSpace: true,
              required: true,
            })
              .id('field_confirmPassword')

            PasswordStrengthIndicator({ password: this.form.masterPassword })
              .margin({ left: $r('sys.float.padding_level8'), bottom: $r('sys.float.padding_level12') })

            FormItem({ label: $r('app.string.key_file_label'), contentBuilder: this.keyFileBuilder })
              .id('field_keyFile')
              .margin({ bottom: $r('sys.float.padding_level8') })

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
                  Span(this.viewModel.currentKeyFileUri().length === 0
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
        .id('create_vault_scroll')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .padding(
          {
            top: this.topAvoidAreaHeight,
            bottom: this.scrollBottomAvoidAreaHeight,
            left: $r('sys.float.padding_level8'),
            right: $r('sys.float.padding_level8'),
          })

        Row({ space: $r('sys.float.padding_level6') }) {
          Button() {
            if (this.viewModel.busy) {
              Row({ space: $r('sys.float.padding_level2') }) {
                LoadingProgress()
                  .width($r('sys.float.padding_level12'))
                  .height($r('sys.float.padding_level12'))
                  .color($r('sys.color.font_on_primary'))
                Text($r('app.string.creating'))
                  .fontSize($r('sys.float.Body_L'))
                  .fontColor($r('sys.color.font_on_primary'))
              }
            } else {
              Text($r('app.string.create_vault'))
                .fontSize($r('sys.float.Body_L'))
                .fontColor($r('sys.color.font_on_primary'))
            }
          }
          .width('100%')
          .height($r('app.float.control_height'))
          .enabled(!this.viewModel.busy)
          .systemMaterial(new uiMaterial.ImmersiveMaterial({
            interactive: true,
            style: uiMaterial.ImmersiveStyle.REGULAR,
            applyShadow: false,
            materialColor: $r('sys.color.brand'),
          }))
          .onClick(() => this.handleSubmit())
        }
        .position({ bottom: 0 })
        .padding({
          right: $r('sys.float.padding_level8'),
          bottom: this.bottomSafeAreaHeight,
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
      .bindSheet($$this.generatorSheetVisible, this.generatorSheet(), {
        dragBar: true,
        backgroundColor: Color.Transparent,
        systemMaterial: new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
        }),
        showClose: false,
        onDisappear: () => this.closeGeneratorSheet(),
      })
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
  }
}

@Builder
export function createVaultPageBuilder() {
  CreateVaultPage()
}
