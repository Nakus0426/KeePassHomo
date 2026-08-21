import { common } from '@kit.AbilityKit'
import { LengthMetrics, uiMaterial } from '@kit.ArkUI'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { ROUTE_CREATE_VAULT, ROUTE_FILE_SUMMARY, ROUTE_UNLOCK, ROUTE_WELCOME } from '../../constants/RouteConstants'
import { PageTopBar, StatusText } from '../../components/PageChrome'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { VaultAppViewModel } from '../../viewmodel/VaultAppViewModel'

@ComponentV2
export struct SplashContent {
  @Param viewModel: VaultAppViewModel = new VaultAppViewModel()
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

@ComponentV2
struct DataSourceCard {
  @Param icon: Resource = $r('sys.symbol.folder_fill')
  @Param title: Resource = $r('app.string.open_local_vault')
  @Param description: Resource = $r('app.string.open_local_vault_description')
  @Param selectable: boolean = true
  @Event onSelect: () => void = () => {
  }

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: $r('sys.float.padding_level8') }) {
        Stack() {
          SymbolGlyph(this.icon)
            .fontSize($r('sys.float.Title_L'))
            .fontColor([$r('sys.color.brand')])
        }
        .padding($r('sys.float.padding_level4'))
        .borderRadius('50%')
        .backgroundColor($r('sys.color.comp_emphasize_secondary'))

        Column({ space: $r('sys.float.padding_level2') }) {
          Text(this.title)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontColor($r('sys.color.font_primary'))
            .fontWeight(FontWeight.Medium)
          Text(this.description)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize($r('sys.float.Title_S'))
          .fontColor([$r('sys.color.font_secondary')])
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .enabled(this.selectable)
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .borderRadius($r('sys.float.corner_radius_level10'))
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      interactive: true,
      lightEffect: { color: undefined },
    }))
    .onClick(() => this.onSelect())
  }
}

@ComponentV2
export struct WelcomePage {
  @Param viewModel: VaultAppViewModel = new VaultAppViewModel()

  build() {
    HdsNavDestination() {
      Scroll() {
        Column({ space: $r('sys.float.padding_level8') }) {
          Column({ space: $r('sys.float.padding_level2') }) {
            Image($r('app.media.launch_icon'))
              .width($r('app.float.welcome_icon_size'))
              .height($r('app.float.welcome_icon_size'))
            Text($r('app.string.app_title'))
              .fontSize($r('sys.float.Title_L'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Text($r('app.string.welcome_description'))
              .fontSize($r('sys.float.Subtitle_M'))
              .fontColor($r('sys.color.font_secondary'))
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: $r('sys.float.padding_level16') })

          Row({ space: $r('sys.float.padding_level8') }) {
            Stack() {
              SymbolGlyph($r('sys.symbol.shield_checkered'))
                .fontSize($r('sys.float.Title_L'))
                .fontColor([$r('sys.color.brand')])
            }
            .padding($r('sys.float.padding_level4'))
            .borderRadius('50%')
            .backgroundColor($r('sys.color.comp_emphasize_secondary'))

            Column({ space: $r('sys.float.padding_level2') }) {
              Text($r('app.string.local_storage_title'))
                .fontSize($r('sys.float.Subtitle_L'))
                .fontColor($r('sys.color.font_primary'))
                .fontWeight(FontWeight.Medium)
              Text($r('app.string.local_storage_description'))
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding($r('sys.float.padding_level8'))
          .margin({ top: $r('sys.float.padding_level8') })
          .backgroundColor($r('sys.color.comp_emphasize_tertiary'))
          .borderRadius($r('sys.float.corner_radius_level10'))

          Text($r('app.string.choose_data_source'))
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
            .alignSelf(ItemAlign.Start)
            .padding({ left: $r('sys.float.padding_level8'), top: $r('sys.float.padding_level8') })

          Column({ space: $r('sys.float.padding_level6') }) {
            DataSourceCard({
              icon: $r('sys.symbol.plus'),
              title: $r('app.string.create_vault'),
              description: $r('app.string.create_vault_source_description'),
              onSelect: () => this.viewModel.openCreateVault(),
            })
            DataSourceCard({
              icon: $r('sys.symbol.folder_badge_plus'),
              title: $r('app.string.open_local_vault'),
              description: $r('app.string.open_local_vault_description'),
              selectable: !this.viewModel.busy,
              onSelect: () => this.viewModel.chooseLocalVault(),
            })
            DataSourceCard({
              icon: $r('sys.symbol.icloud'),
              title: $r('app.string.connect_webdav'),
              description: $r('app.string.connect_webdav_description'),
              onSelect: () => this.viewModel.showWebDavPending(),
            })
          }
          .width('100%')

          StatusText({ status: this.viewModel.status })

          Column({ space: $r('sys.float.padding_level2') }) {
            Text() {
              SymbolSpan($r('sys.symbol.lock_fill'))
              Span(' ')
              Span($r('app.string.privacy_statement'))
            }
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))

            Text($r('app.string.privacy_statement_secondary'))
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .padding($r('sys.float.padding_level8'))
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .onShown(() => this.viewModel.showRoute(ROUTE_WELCOME))
  }
}

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

@ComponentV2
export struct FileSummaryPage {
  @Param viewModel: VaultAppViewModel = new VaultAppViewModel()
  private readonly scroller: Scroller = new Scroller()

  build() {
    HdsNavDestination() {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          if (this.viewModel.fileSummary !== undefined) {
            Column({ space: 12 }) {
              Text(this.viewModel.fileSummary.name)
                .width('100%')
                .fontSize($r('app.float.text_heading'))
                .fontWeight(FontWeight.Medium)
              Text(`${this.viewModel.formatName(this.viewModel.fileSummary.format)} · ${
              this.viewModel.formatSize(this.viewModel.fileSummary.size)}`)
                .width('100%')
                .fontColor($r('sys.color.font_secondary'))
              Text(new Date(this.viewModel.fileSummary.modifiedAt * 1000).toLocaleString())
                .width('100%')
                .fontColor($r('sys.color.font_secondary'))
              Text(this.viewModel.fileSummary.readOnly ? $r('app.string.read_only') : $r('app.string.writable'))
                .width('100%')
                .fontColor(this.viewModel.fileSummary.readOnly
                  ? $r('sys.color.alert') : $r('sys.color.confirm'))
            }
            .width('100%')
            .padding($r('sys.float.padding_level8'))
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius($r('sys.float.corner_radius_level4'))
          }
          if (this.viewModel.fileSummary?.readOnly) {
            Text($r('app.string.read_only_explanation'))
              .width('100%')
              .fontColor($r('sys.color.alert'))
          }
          Blank()
          Button($r('app.string.continue_action'))
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('sys.color.brand'))
            .onClick(() => this.viewModel.pushRoute(ROUTE_UNLOCK))
          Button($r('app.string.reselect_file'))
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('sys.color.comp_background_primary'))
            .fontColor($r('sys.color.font_primary'))
            .onClick(() => this.viewModel.chooseLocalVault())
        }
        .width('100%')
        .height('100%')
        .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .padding($r('sys.float.padding_level12'))
      }
      .padding({ top: $r('sys.float.single_line_titlebar_height') })
      .edgeEffect(EdgeEffect.Spring)
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR,
          blurEffectiveStartOffset: LengthMetrics.vp(0),
          blurEffectiveEndOffset: LengthMetrics.vp(20),
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
        originalStyle: {
          contentStyle: {
            titleStyle: { mainTitleColor: $r('sys.color.font_primary') },
            backIconStyle: { backgroundColor: Color.Transparent },
          },
        },
      },
      content: {
        title: {
          mainTitle: $r('app.string.file_summary'),
        },
      },
    })
    .bindToScrollable([this.scroller])
    .hideBackButton(false)
    .backgroundColor($r('sys.color.background_secondary'))
    .onShown(() => this.viewModel.showRoute(ROUTE_FILE_SUMMARY))
  }
}

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
          ? $r('app.string.select_key_file') : this.viewModel.currentKeyFileName())
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
