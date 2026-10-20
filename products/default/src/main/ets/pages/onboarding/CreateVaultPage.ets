import { HdsNavDestination } from '@kit.UIDesignKit'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { CreateVaultViewModel } from '../../viewmodel/CreateVaultViewModel'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { DsButton, DsButtonVariant } from '../../components/DsButton'
import { DsField } from '../../components/DsField'
import { DsInput } from '../../components/DsInput'
import { DsPageHeader } from '../../components/DsPageHeader'
import { DsSegmented, DsSegmentItem } from '../../components/DsSegmented'
import { DsStrengthMeter } from '../../components/DsStrengthMeter'
import { Status } from '../../components/FormItem'
import { appRouter } from '../../navigation/AppRouter'

const AUTH_MODES: DsSegmentItem[] = [
  { label: $r('app.string.auth_mode_password_and_key'), enabled: true },
  { label: $r('app.string.auth_mode_password_only'), enabled: false },
  { label: $r('app.string.auth_mode_key_only'), enabled: false },
]

@ComponentV2
export struct CreateVaultPage {
  private readonly viewModel: AppViewModel = appViewModel
  @Local private form: CreateVaultViewModel = new CreateVaultViewModel()
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private submitted: boolean = false
  @Local private masterPasswordVisible: boolean = false
  @Local private confirmPasswordVisible: boolean = false

  @Computed
  get topInset(): number {
    return this.getUIContext().px2vp(this.immersiveLayout.topAvoidAreaHeightPx)
  }

  @Computed
  get bottomInset(): number {
    return this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx)
  }

  @Computed
  get boundKeyFileName(): string {
    return this.viewModel.currentKeyFileUri().length > 0
      ? this.viewModel.currentKeyFileUri().split('/').pop() ?? '' : ''
  }

  @Computed
  get canSubmit(): boolean {
    return this.form.vaultName.trim().length > 0
      && this.form.masterPassword.length > 0
      && this.form.confirmPassword === this.form.masterPassword
  }

  private errorOf(controllerMessage: ResourceStr, invalid: boolean): ResourceStr | undefined {
    return this.submitted && invalid ? controllerMessage : undefined
  }

  private handleSubmit(): void {
    if (this.form.validate() === undefined) {
      this.viewModel.createVault(this.form.vaultName, this.form.masterPassword)
      return
    }
    this.submitted = true
  }

  private submitEnabled(): boolean {
    return this.canSubmit && !this.viewModel.busy
  }

  @Builder
  private vaultNameField() {
    DsField({
      label: $r('app.string.vault_name'),
      required: true,
      error: this.errorOf(this.form.vaultNameController.message,
        this.form.vaultNameController.status === Status.Invalid),
    }) {
      DsInput({
        text: this.form.vaultName,
        placeholder: $r('app.string.text_input_placeholder'),
        suffix: $r('app.string.kdbx_suffix'),
        onChange: (value: string) => {
          this.form.setVaultName(value)
          this.form.vaultNameController.validate(value)
        },
      })
    }
  }

  @Builder
  private authModeField() {
    DsField({ label: $r('app.string.vault_auth_mode'), required: true }) {
      DsSegmented({ items: AUTH_MODES, selectedIndex: 0, onSelect: (_index: number) => {
      } })
    }
  }

  @Builder
  private masterPasswordField() {
    DsField({
      label: $r('app.string.master_password'),
      required: true,
      error: this.errorOf(this.form.masterPasswordController.message,
        this.form.masterPasswordController.status === Status.Invalid),
    }) {
      Column({ space: $r('app.float.ds_space_md') }) {
        DsInput({
          text: this.form.masterPassword,
          placeholder: $r('app.string.text_input_placeholder'),
          type: InputType.Password,
          showPassword: this.masterPasswordVisible,
          onChange: (value: string) => {
            this.form.setMasterPassword(value)
            this.form.masterPasswordController.validate(value)
            this.form.confirmPasswordController.validate(this.form.confirmPassword)
          },
        }) {
          SymbolGlyph(this.masterPasswordVisible ? $r('sys.symbol.eye_slash') : $r('sys.symbol.eye'))
            .fontSize($r('app.float.ds_icon_sm'))
            .fontColor([$r('app.color.ds_text_tertiary')])
            .onClick(() => this.masterPasswordVisible = !this.masterPasswordVisible)
        }

        DsInput({
          text: this.form.confirmPassword,
          placeholder: $r('app.string.confirm_password'),
          type: InputType.Password,
          showPassword: this.confirmPasswordVisible,
          onChange: (value: string) => {
            this.form.setConfirmPassword(value)
            this.form.confirmPasswordController.validate(value)
          },
        }) {
          SymbolGlyph(this.confirmPasswordVisible ? $r('sys.symbol.eye_slash') : $r('sys.symbol.eye'))
            .fontSize($r('app.float.ds_icon_sm'))
            .fontColor([$r('app.color.ds_text_tertiary')])
            .onClick(() => this.confirmPasswordVisible = !this.confirmPasswordVisible)
        }

        DsStrengthMeter({ password: this.form.masterPassword })

        if (this.submitted && this.form.confirmPasswordController.status === 'invalid') {
          Row({ space: $r('app.float.ds_space_xs') }) {
            SymbolGlyph($r('sys.symbol.exclamationmark_circle_fill'))
              .fontSize($r('app.float.ds_icon_tiny'))
              .fontColor([$r('app.color.ds_error')])
            Text(this.form.confirmPasswordController.message)
              .fontSize($r('app.float.ds_font_body_sm'))
              .fontColor($r('app.color.ds_error'))
              .layoutWeight(1)
          }
          .width('100%')
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private keyFileField() {
    DsField({ label: $r('app.string.key_file_label'), required: true }) {
      Column({ space: $r('app.float.ds_space_md') }) {
        Row({ space: $r('app.float.ds_space_sm') }) {
          SymbolGlyph($r('sys.symbol.key'))
            .fontSize($r('app.float.ds_icon_md'))
            .fontColor([$r('app.color.ds_text_primary')])
          Column({ space: 2 }) {
            Text(this.boundKeyFileName.length > 0
              ? this.boundKeyFileName : $r('app.string.key_file_unbound_title'))
              .fontSize($r('app.float.ds_font_body'))
              .fontWeight(600)
              .fontColor($r('app.color.ds_text_primary'))
            Text(this.boundKeyFileName.length > 0
              ? this.viewModel.currentKeyFileUri() : $r('app.string.key_file_unbound_description'))
              .fontSize($r('app.float.ds_font_body_sm'))
              .fontColor($r('app.color.ds_text_secondary'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        if (this.boundKeyFileName.length > 0) {
          Row({ space: $r('app.float.ds_space_sm') }) {
            Row() {
              Text($r('app.string.key_file_import'))
                .fontSize($r('app.float.ds_font_body_sm'))
                .fontWeight(600)
                .fontColor($r('app.color.ds_text_primary'))
            }
            .layoutWeight(1)
            .height($r('app.float.ds_button_height'))
            .justifyContent(FlexAlign.Center)
            .backgroundColor($r('app.color.ds_surface_highest'))
            .onClick(() => this.viewModel.chooseKeyFile())

            Row() {
              Text($r('app.string.key_file_remove'))
                .fontSize($r('app.float.ds_font_body_sm'))
                .fontWeight(600)
                .fontColor($r('app.color.ds_error'))
            }
            .height($r('app.float.ds_button_height'))
            .padding({ left: $r('app.float.ds_space_md'), right: $r('app.float.ds_space_md') })
            .justifyContent(FlexAlign.Center)
            .onClick(() => this.viewModel.clearKeyFile())
          }
          .width('100%')
        } else {
          DsButton({
            label: $r('app.string.key_file_import'),
            variant: DsButtonVariant.Secondary,
            leadingIcon: $r('sys.symbol.upload'),
            onTap: () => this.viewModel.chooseKeyFile(),
          })
        }
      }
      .width('100%')
      .padding($r('app.float.ds_space_md'))
      .backgroundColor($r('app.color.ds_surface_low'))
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private bottomPanel() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      if (!this.submitEnabled()) {
        Row({ space: $r('app.float.ds_space_xs') }) {
          SymbolGlyph($r('sys.symbol.exclamationmark_circle_fill'))
            .fontSize($r('app.float.ds_icon_tiny'))
            .fontColor([$r('app.color.ds_text_tertiary')])
          Text($r('app.string.create_vault_hint'))
            .fontSize($r('app.float.ds_font_body_sm'))
            .fontColor($r('app.color.ds_text_tertiary'))
            .layoutWeight(1)
        }
        .width('100%')
      }

      DsButton({
        label: this.viewModel.busy ? $r('app.string.creating') : $r('app.string.create_open_vault'),
        variant: DsButtonVariant.Filled,
        trailingIcon: $r('sys.symbol.chevron_forward'),
        active: this.submitEnabled(),
        onTap: () => this.handleSubmit(),
      })
    }
    .width('100%')
    .padding({
      top: $r('app.float.ds_space_md'),
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
      bottom: this.bottomInset + 8,
    })
    .backgroundColor($r('app.color.ds_surface_canvas'))
  }

  build() {
    HdsNavDestination() {
      Column() {
        DsPageHeader({
          title: $r('app.string.create_vault'),
          subtitle: $r('app.string.create_vault_subtitle'),
          showMore: false,
          onBack: () => appRouter.pop(),
        })

        Stack({ alignContent: Alignment.Bottom }) {
          Scroll() {
            Column({ space: $r('app.float.ds_space_xl') }) {
              this.vaultNameField()
              this.authModeField()
              this.masterPasswordField()
              this.keyFileField()
            }
            .width('100%')
            .padding({
              top: $r('app.float.ds_space_lg'),
              bottom: 160,
              left: $r('app.float.ds_gutter'),
              right: $r('app.float.ds_gutter'),
            })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)

          this.bottomPanel()
        }
        .width('100%')
        .layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .padding({ top: this.topInset })
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.ds_surface_canvas'))
  }
}

@Builder
export function createVaultPageBuilder() {
  CreateVaultPage()
}
