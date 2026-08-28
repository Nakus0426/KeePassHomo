import { uiMaterial } from '@kit.ArkUI'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { GeneratorContent } from '../generator/GeneratorComponents'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { ColorModeState, colorModeState } from '../../state/ColorModeState'
import { VaultAppViewModel, vaultAppViewModel } from '../../viewmodel/VaultAppViewModel'
import { BounceAnimator, ColorUtil } from '@ohos/common'
import { LogUtil, ResUtil } from '@pura/harmony-utils'
import { FormItem } from '../../components/FormItem'
import { PasswordStrengthIndicator } from '../../components/PasswordStrengthIndicator'
import { PasswordVisibilityToggle } from '../../components/PasswordVisibilityToggle'

@ComponentV2
export struct CreateVaultPage {
  private readonly viewModel: VaultAppViewModel = vaultAppViewModel
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private colorMode: ColorModeState = colorModeState
  @Local private generatorSheetVisible: boolean = false
  @Local private masterPasswordVisible: boolean = false
  @Local private confirmPasswordVisible: boolean = false
  private readonly generatorSheetMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
    applyShadow: true,
  })
  private bounce: BounceAnimator = new BounceAnimator()
  private readonly scroller: Scroller = new Scroller()

  private displayPath(uri: string): string {
    const rawPath: string = uri.startsWith('file://') ? uri.substring('file://'.length) : uri
    return decodeURIComponent(rawPath)
  }

  private handleSubmit(): void {
    const invalidFieldKey: string | undefined = this.viewModel.validateCreateForm()
    if (invalidFieldKey === undefined) {
      this.viewModel.createVault()
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
      animation: { duration: 300, curve: Curve.EaseInOut },
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
    this.viewModel.fillMasterPasswordFromGenerator()
    this.generatorSheetVisible = false
  }

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
      const buttonHeight =
        ResUtil.getNumber($r('app.float.control_height').id)
      const padding = ResUtil.getNumber($r('sys.float.padding_level8').id)
      res =
        this.getUIContext().px2vp(this.bottomAvoidAreaHeight + buttonHeight + padding * 2)
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
    TextInput({ placeholder: $r('app.string.text_input_placeholder'), text: this.viewModel?.vaultName })
      .height($r('app.float.control_height'))
      .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .onChange((value: string) => this.viewModel.setVaultName(value))
  }

  @LocalBuilder
  masterPasswordBuilder() {
    Row({ space: $r('sys.float.padding_level2') }) {
      TextInput({ placeholder: $r('app.string.text_input_placeholder'), text: this.viewModel?.masterPassword })
        .type(InputType.Password)
        .showPasswordIcon(false)
        .showPassword(this.masterPasswordVisible)
        .height($r('app.float.control_height'))
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .onChange((value: string) => this.viewModel?.setMasterPassword(value))

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
    .height($r('app.float.control_height'))
    .width('100%')
    .padding({ right: $r('sys.float.padding_level4') })
    .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
    .borderRadius($r('sys.float.ohos_id_corner_radius_text_field'))
    .backgroundColor($r('sys.color.comp_background_primary'))
  }

  @LocalBuilder
  confirmPasswordBuilder() {
    Row({ space: $r('sys.float.padding_level2') }) {
      TextInput({ placeholder: $r('app.string.text_input_placeholder'), text: this.viewModel?.confirmPassword })
        .type(InputType.Password)
        .showPasswordIcon(false)
        .showPassword(this.confirmPasswordVisible)
        .height($r('app.float.control_height'))
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .onChange((value: string) => this.viewModel?.setConfirmPassword(value))

      PasswordVisibilityToggle({
        visible: this.confirmPasswordVisible,
        onChange: (visible: boolean) => this.confirmPasswordVisible = visible,
      })
    }
    .height($r('app.float.control_height'))
    .width('100%')
    .padding({ right: $r('sys.float.padding_level4') })
    .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
    .borderRadius($r('sys.float.ohos_id_corner_radius_text_field'))
    .backgroundColor($r('sys.color.comp_background_primary'))
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
    GeneratorContent({
      viewModel: this.viewModel.generator,
      clipboardSeconds: this.viewModel.clipboardSeconds,
      showFillAction: true,
      onCopy: (value: string) => this.viewModel.copyValue(value),
      onFillEditor: () => this.fillMasterPasswordFromGenerator(),
      onActivity: () => this.viewModel.recordActivity(),
    })
      .padding({
        right: $r('sys.float.padding_level8'),
        bottom: $r('sys.float.padding_level8'),
        left: $r('sys.float.padding_level8'),
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
                value: this.viewModel.vaultName,
                schema: this.viewModel.vaultNameSchema,
                controller: this.viewModel.vaultNameController,
                reserveFeedbackSpace: true,
                required: true,
              })
              .id('field_vaultName')

            FormItem({
              label: $r('app.string.master_password'),
              contentBuilder: this.masterPasswordBuilder,
              value: this.viewModel.masterPassword,
              schema: this.viewModel.masterPasswordSchema,
              controller: this.viewModel.masterPasswordController,
              reserveFeedbackSpace: true,
              required: true,
            })
              .id('field_masterPassword')

            FormItem({
              label: $r('app.string.confirm_password'),
              contentBuilder: this.confirmPasswordBuilder,
              value: this.viewModel.confirmPassword,
              schema: this.viewModel.confirmPasswordSchema,
              controller: this.viewModel.confirmPasswordController,
              reserveFeedbackSpace: true,
              required: true,
            })
              .id('field_confirmPassword')

            PasswordStrengthIndicator({ password: this.viewModel.masterPassword })
              .margin({ left: $r('sys.float.padding_level8'), bottom: $r('sys.float.padding_level12') })

            FormItem({
              label: $r('app.string.key_file_label'),
              contentBuilder: this.keyFileBuilder,
              reserveFeedbackSpace: true,
            })
              .id('field_keyFile')

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
      .bindSheet($$this.generatorSheetVisible, this.generatorSheet(), {
        height: SheetSize.LARGE,
        dragBar: true,
        backgroundColor: Color.Transparent,
        systemMaterial: this.generatorSheetMaterial,
        title: { title: $r('app.string.password_generator') },
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

