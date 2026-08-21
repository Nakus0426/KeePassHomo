import { uiMaterial } from '@kit.ArkUI'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { VaultEntry, VaultFormat, VaultGroup } from '@ohos/common'
import { ROUTE_ENTRY_DETAIL, ROUTE_ENTRY_EDIT, ROUTE_TEMPLATE, ROUTE_VAULT } from '../../constants/RouteConstants'
import { GeneratorContent } from '../generator/GeneratorPage'
import { PageTopBar, StatusText } from '../../components/PageChrome'
import { VaultBrowseMode } from '../../model/StageOneVaultStore'
import { VaultAppViewModel } from '../../viewmodel/VaultAppViewModel'

@ComponentV2
export struct VaultHomePage {
  @Param viewModel: VaultAppViewModel = new VaultAppViewModel()
  @Event onRootBack: () => void = () => {
  }

  @Builder
  private browseModeButton(title: Resource, mode: VaultBrowseMode) {
    Button(title)
      .layoutWeight(1)
      .backgroundColor(this.viewModel.browseMode === mode
        ? $r('sys.color.brand') : $r('sys.color.comp_background_primary'))
      .fontColor(this.viewModel.browseMode === mode
        ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
      .onClick(() => this.viewModel.setBrowseMode(mode))
  }

  build() {
    HdsNavDestination() {
      Column({ space: 12 }) {
        PageTopBar({
          title: $r('app.string.vault_home'),
          showLock: true,
          onLock: () => this.viewModel.lockVault(),
        })
        Text(this.viewModel.currentSource().displayName)
          .width('100%')
          .fontSize($r('app.float.text_caption'))
          .fontColor($r('sys.color.font_secondary'))
        if (this.viewModel.currentSource().readOnly) {
          Text($r('app.string.read_only_explanation'))
            .width('100%')
            .fontColor($r('sys.color.alert'))
          if (this.viewModel.currentFormat() === VaultFormat.Kdbx31) {
            Column({ space: 8 }) {
              Text($r('app.string.upgrade_required'))
                .width('100%')
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
              Text($r('app.string.upgrade_description'))
                .width('100%')
                .fontSize($r('app.float.text_caption'))
                .fontColor($r('sys.color.font_secondary'))
              Button(this.viewModel.busy ? $r('app.string.upgrading') : $r('app.string.backup_and_upgrade'))
                .width('100%')
                .enabled(!this.viewModel.busy)
                .backgroundColor($r('sys.color.brand'))
                .onClick(() => this.viewModel.upgradeLegacyVault())
            }
            .width('100%')
            .padding($r('sys.float.padding_level8'))
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius($r('sys.float.corner_radius_level4'))
          }
        }
        StatusText({ status: this.viewModel.status })
        TextInput({ placeholder: $r('app.string.search_vault'), text: this.viewModel.searchQuery })
          .width('100%')
          .height($r('app.float.control_height'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .onChange((value: string) => this.viewModel.setSearchQuery(value))
        Row({ space: 8 }) {
          this.browseModeButton($r('app.string.all_entries'), VaultBrowseMode.All)
          this.browseModeButton($r('app.string.favorites'), VaultBrowseMode.Favorites)
          this.browseModeButton($r('app.string.archived'), VaultBrowseMode.Archived)
        }
        .width('100%')

        Scroll() {
          Row({ space: 8 }) {
            Button($r('app.string.groups'))
              .backgroundColor(this.viewModel.selectedGroupUuid.length === 0
                ? $r('sys.color.brand') : $r('sys.color.comp_background_primary'))
              .fontColor(this.viewModel.selectedGroupUuid.length === 0
                ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
              .onClick(() => this.viewModel.selectBrowseGroup(''))
            ForEach(this.viewModel.groups(), (group: VaultGroup) => {
              Button(group.name)
                .backgroundColor(this.viewModel.selectedGroupUuid === group.uuid
                  ? $r('sys.color.brand') : $r('sys.color.comp_background_primary'))
                .fontColor(this.viewModel.selectedGroupUuid === group.uuid
                  ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
                .onClick(() => this.viewModel.selectBrowseGroup(group.uuid))
            }, (group: VaultGroup) => group.uuid)
          }
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)

        if (this.viewModel.entries().length === 0) {
          Column({ space: 12 }) {
            Text($r('app.string.no_entries'))
              .fontSize($r('app.float.text_heading'))
              .fontWeight(FontWeight.Medium)
            Text($r('app.string.no_entries_description'))
              .fontColor($r('sys.color.font_secondary'))
              .textAlign(TextAlign.Center)
            if (!this.viewModel.currentSource().readOnly) {
              Button($r('app.string.new_entry'))
                .backgroundColor($r('sys.color.brand'))
                .onClick(() => this.viewModel.pushRoute(ROUTE_TEMPLATE))
            }
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.viewModel.visibleEntries().length === 0) {
          Column() {
            Text($r('app.string.no_results'))
              .fontSize($r('app.float.text_heading'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 8 }) {
            ForEach(this.viewModel.visibleEntries(), (entry: VaultEntry) => {
              ListItem() {
                Row({ space: 12 }) {
                  Text(entry.title.substring(0, 1).toUpperCase())
                    .width($r('app.float.control_height'))
                    .height($r('app.float.control_height'))
                    .textAlign(TextAlign.Center)
                    .fontColor($r('sys.color.font_on_primary'))
                    .backgroundColor($r('sys.color.brand'))
                    .borderRadius($r('sys.float.corner_radius_level4'))
                  Column({ space: 4 }) {
                    Text(entry.title)
                      .width('100%')
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('sys.color.font_primary'))
                    Text(this.viewModel.field(entry, 'UserName'))
                      .width('100%')
                      .fontSize($r('app.float.text_caption'))
                      .fontColor($r('sys.color.font_secondary'))
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  if (entry.favorite) {
                    Text($r('app.string.favorites'))
                      .fontSize($r('app.float.text_caption'))
                      .fontColor($r('sys.color.brand'))
                  }
                }
                .width('100%')
                .padding($r('sys.float.padding_level8'))
                .backgroundColor($r('sys.color.comp_background_primary'))
                .borderRadius($r('sys.float.corner_radius_level4'))
                .onClick(() => this.viewModel.openEntry(entry.uuid))
              }
            }, (entry: VaultEntry) => entry.uuid)
          }
          .width('100%')
          .layoutWeight(1)

          if (!this.viewModel.currentSource().readOnly) {
            Button($r('app.string.new_entry'))
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.brand'))
              .onClick(() => this.viewModel.pushRoute(ROUTE_TEMPLATE))
          }
        }
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding({
        top: $r('sys.float.padding_level12'),
        right: $r('sys.float.padding_level12'),
        bottom: $r('app.float.module_content_bottom_padding'),
        left: $r('sys.float.padding_level12'),
      })
      .onTouch(() => this.viewModel.recordActivity())
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .onShown(() => this.viewModel.showRoute(ROUTE_VAULT))
    .onBackPressed(() => {
      this.onRootBack()
      return true
    })
  }
}

@ComponentV2
export struct TemplatePage {
  @Param viewModel: VaultAppViewModel = new VaultAppViewModel()

  @Builder
  private templateRow(title: Resource, description: Resource, enabled: boolean) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title)
          .width('100%')
          .fontWeight(FontWeight.Medium)
        Text(description)
          .width('100%')
          .fontSize($r('app.float.text_caption'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button(enabled ? $r('app.string.continue_action') : $r('app.string.not_available'))
        .enabled(enabled)
        .backgroundColor(enabled ? $r('sys.color.comp_emphasize_secondary') : $r('sys.color.background_secondary'))
        .fontColor(enabled ? $r('sys.color.brand') : $r('sys.color.font_secondary'))
        .onClick(() => this.viewModel.startNewEntry())
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level4'))
  }

  build() {
    HdsNavDestination() {
      Column({ space: 12 }) {
        PageTopBar({
          title: $r('app.string.choose_template'),
          showBack: true,
          onBack: () => this.viewModel.popRoute(),
        })
        this.templateRow($r('app.string.login_template'), $r('app.string.login_template_description'), true)
        this.templateRow($r('app.string.credit_card_template'), $r('app.string.not_available'), false)
        this.templateRow($r('app.string.secure_note_template'), $r('app.string.not_available'), false)
        this.templateRow($r('app.string.identity_template'), $r('app.string.not_available'), false)
        this.templateRow($r('app.string.wifi_template'), $r('app.string.not_available'), false)
        this.templateRow($r('app.string.license_template'), $r('app.string.not_available'), false)
        Blank()
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding($r('sys.float.padding_level12'))
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .onShown(() => this.viewModel.showRoute(ROUTE_TEMPLATE))
  }
}

@ComponentV2
export struct EntryEditPage {
  @Param viewModel: VaultAppViewModel = new VaultAppViewModel()
  @Local private generatorSheetVisible: boolean = false
  private readonly generatorSheetMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
    applyShadow: true,
  })

  private openGeneratorSheet(): void {
    this.viewModel.prepareEditorGenerator()
    this.generatorSheetVisible = true
  }

  private closeGeneratorSheet(): void {
    this.generatorSheetVisible = false
    this.viewModel.generator.clearSensitiveState()
  }

  private fillPasswordFromGenerator(): void {
    this.viewModel.fillEditorFromGenerator()
    this.generatorSheetVisible = false
  }

  @Builder
  private generatorSheet() {
    GeneratorContent({
      viewModel: this.viewModel.generator,
      clipboardSeconds: this.viewModel.clipboardSeconds,
      showFillAction: true,
      onCopy: (value: string) => this.viewModel.copyValue(value),
      onFillEditor: () => this.fillPasswordFromGenerator(),
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
        Scroll() {
          Column({ space: 14 }) {
            Row({ space: 12 }) {
              Button($r('app.string.cancel'))
                .backgroundColor(Color.Transparent)
                .fontColor($r('sys.color.brand'))
                .onClick(() => this.viewModel.requestEditorExit())
              Text(this.viewModel.selectedEntryUuid.length === 0
                ? $r('app.string.new_entry') : $r('app.string.edit'))
                .layoutWeight(1)
                .fontSize($r('app.float.text_heading'))
                .fontWeight(FontWeight.Bold)
              Button(this.viewModel.busy ? $r('app.string.saving') : $r('app.string.save'))
                .enabled(!this.viewModel.busy)
                .backgroundColor(Color.Transparent)
                .fontColor($r('sys.color.brand'))
                .onClick(() => this.viewModel.saveEntry())
            }
            .width('100%')
            .height($r('app.float.control_height'))

            TextInput({ placeholder: $r('app.string.entry_title'), text: this.viewModel.editorTitle })
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.comp_background_primary'))
              .onChange((value: string) => this.viewModel.setEditorTitle(value))
            TextInput({ placeholder: $r('app.string.username'), text: this.viewModel.editorUsername })
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.comp_background_primary'))
              .onChange((value: string) => this.viewModel.setEditorUsername(value))
            Row({ space: 8 }) {
              TextInput({ placeholder: $r('app.string.password'), text: this.viewModel.editorPassword })
                .type(this.viewModel.showEditorPassword ? InputType.Normal : InputType.Password)
                .height($r('app.float.control_height'))
                .layoutWeight(1)
                .backgroundColor($r('sys.color.comp_background_primary'))
                .onChange((value: string) => this.viewModel.setEditorPassword(value))
              Button(this.viewModel.showEditorPassword ? $r('app.string.hide') : $r('app.string.show'))
                .height($r('app.float.control_height'))
                .backgroundColor($r('sys.color.comp_emphasize_secondary'))
                .fontColor($r('sys.color.brand'))
                .onClick(() => this.viewModel.showEditorPassword
                  ? this.viewModel.hidePasswords() : this.viewModel.revealPassword(ROUTE_ENTRY_EDIT))
              Button($r('app.string.generate'))
                .height($r('app.float.control_height'))
                .backgroundColor($r('sys.color.brand'))
                .onClick(() => this.openGeneratorSheet())
            }
            .width('100%')

            TextInput({ placeholder: $r('app.string.website'), text: this.viewModel.editorUrl })
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.comp_background_primary'))
              .onChange((value: string) => this.viewModel.setEditorUrl(value))
            if (this.viewModel.editorUrl.length > 0 &&
              !this.viewModel.editorUrl.startsWith('https://') &&
              !this.viewModel.editorUrl.startsWith('http://')) {
              Text('网址格式异常，但不会阻止保存')
                .width('100%')
                .fontColor($r('sys.color.alert'))
            }
            TextArea({ placeholder: $r('app.string.notes'), text: this.viewModel.editorNotes })
              .width('100%')
              .backgroundColor($r('sys.color.comp_background_primary'))
              .onChange((value: string) => this.viewModel.setEditorNotes(value))
            TextInput({ placeholder: $r('app.string.tags'), text: this.viewModel.editorTags })
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.comp_background_primary'))
              .onChange((value: string) => this.viewModel.setEditorTags(value))
            Text($r('app.string.group'))
              .width('100%')
              .fontColor($r('sys.color.font_secondary'))
            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.viewModel.groups(), (group: VaultGroup) => {
                  Button(group.path)
                    .backgroundColor(this.viewModel.editorGroupUuid === group.uuid
                      ? $r('sys.color.brand') : $r('sys.color.comp_background_primary'))
                    .fontColor(this.viewModel.editorGroupUuid === group.uuid
                      ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
                    .onClick(() => this.viewModel.setEditorGroup(group.uuid))
                }, (group: VaultGroup) => group.uuid)
              }
            }
            .width('100%')
            .scrollable(ScrollDirection.Horizontal)
            .scrollBar(BarState.Off)

            StatusText({ status: this.viewModel.status })
          }
          .width('100%')
          .constraintSize({ maxWidth: $r('app.float.content_max_width') })
          .padding($r('sys.float.padding_level12'))
        }
        .width('100%')
        .height('100%')

        if (this.viewModel.unsavedDialogVisible) {
          Column({ space: 12 }) {
            Text($r('app.string.unsaved_title'))
              .fontSize($r('app.float.text_heading'))
              .fontWeight(FontWeight.Bold)
            Text($r('app.string.unsaved_message'))
              .fontColor($r('sys.color.font_secondary'))
            Button($r('app.string.save'))
              .width('100%')
              .backgroundColor($r('sys.color.brand'))
              .onClick(() => this.viewModel.saveEntry())
            Button($r('app.string.discard'))
              .width('100%')
              .backgroundColor($r('sys.color.background_secondary'))
              .fontColor($r('sys.color.warning'))
              .onClick(() => this.viewModel.exitEditor())
            Button($r('app.string.continue_editing'))
              .width('100%')
              .backgroundColor(Color.Transparent)
              .fontColor($r('sys.color.brand'))
              .onClick(() => this.viewModel.dismissUnsavedDialog())
          }
          .width($r('app.float.dialog_width'))
          .padding($r('sys.float.padding_level12'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius($r('sys.float.corner_radius_level8'))
          .shadow({
            radius: 24,
            color: 0x33000000,
            offsetX: 0,
            offsetY: 8,
          })
        }
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
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .onShown(() => this.viewModel.showRoute(ROUTE_ENTRY_EDIT))
    .onBackPressed(() => {
      if (this.viewModel.unsavedDialogVisible) {
        this.viewModel.dismissUnsavedDialog()
      } else {
        this.viewModel.requestEditorExit()
      }
      return true
    })
  }
}

@ComponentV2
export struct EntryDetailPage {
  @Param viewModel: VaultAppViewModel = new VaultAppViewModel()

  @Builder
  private detailField(label: Resource, value: string) {
    Column({ space: 8 }) {
      Text(label)
        .width('100%')
        .fontSize($r('app.float.text_caption'))
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: 8 }) {
        Text(value)
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
        if (value.length > 0) {
          Button($r('app.string.copy'))
            .backgroundColor(Color.Transparent)
            .fontColor($r('sys.color.brand'))
            .onClick(() => this.viewModel.copyValue(value))
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level4'))
  }

  @Builder
  private passwordField(value: string) {
    Column({ space: 8 }) {
      Text($r('app.string.password'))
        .width('100%')
        .fontSize($r('app.float.text_caption'))
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: 8 }) {
        Text(this.viewModel.showEntryPassword ? value : $r('app.string.password_hidden'))
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
        Button(this.viewModel.showEntryPassword ? $r('app.string.hide') : $r('app.string.show'))
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.brand'))
          .onClick(() => this.viewModel.showEntryPassword
            ? this.viewModel.hidePasswords() : this.viewModel.revealPassword(ROUTE_ENTRY_DETAIL))
        Button($r('app.string.copy'))
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.brand'))
          .onClick(() => this.viewModel.copyValue(value))
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level4'))
  }

  build() {
    HdsNavDestination() {
      Column({ space: 16 }) {
        PageTopBar({
          title: $r('app.string.login_template'),
          showBack: true,
          onBack: () => this.viewModel.popRoute(),
        })
        Text(this.viewModel.entry(this.viewModel.selectedEntryUuid).title)
          .width('100%')
          .fontSize($r('sys.float.Title_L'))
          .fontWeight(FontWeight.Bold)
        Text(this.viewModel.entry(this.viewModel.selectedEntryUuid).groupPath)
          .width('100%')
          .fontColor($r('sys.color.font_secondary'))
        Row({ space: 8 }) {
          Button(this.viewModel.entry(this.viewModel.selectedEntryUuid).favorite
            ? $r('app.string.remove_favorite') : $r('app.string.add_favorite'))
            .enabled(!this.viewModel.busy && !this.viewModel.currentSource().readOnly)
            .backgroundColor($r('sys.color.comp_emphasize_secondary'))
            .fontColor($r('sys.color.brand'))
            .onClick(() => this.viewModel.toggleFavorite())
          Button(this.viewModel.entry(this.viewModel.selectedEntryUuid).archived
            ? $r('app.string.restore_entry') : $r('app.string.archive_entry'))
            .enabled(!this.viewModel.busy && !this.viewModel.currentSource().readOnly)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .fontColor($r('sys.color.font_primary'))
            .onClick(() => this.viewModel.toggleArchived())
        }
        .width('100%')

        this.detailField($r('app.string.username'),
          this.viewModel.field(this.viewModel.entry(this.viewModel.selectedEntryUuid), 'UserName'))
        this.passwordField(
          this.viewModel.field(this.viewModel.entry(this.viewModel.selectedEntryUuid), 'Password'))
        this.detailField($r('app.string.website'),
          this.viewModel.field(this.viewModel.entry(this.viewModel.selectedEntryUuid), 'URL'))
        this.detailField($r('app.string.notes'),
          this.viewModel.field(this.viewModel.entry(this.viewModel.selectedEntryUuid), 'Notes'))
        if (this.viewModel.entry(this.viewModel.selectedEntryUuid).tags.length > 0) {
          this.detailField($r('app.string.tags'),
            this.viewModel.entry(this.viewModel.selectedEntryUuid).tags.join(', '))
        }
        if (this.viewModel.clipboardSeconds > 0) {
          Text($r('app.string.copied_countdown', this.viewModel.clipboardSeconds))
            .width('100%')
            .fontColor($r('sys.color.confirm'))
            .textAlign(TextAlign.Center)
        }
        Blank()
        if (!this.viewModel.currentSource().readOnly) {
          Button($r('app.string.edit'))
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('sys.color.brand'))
            .onClick(() => this.viewModel.startEditEntry())
        }
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding($r('sys.float.padding_level12'))
      .onTouch(() => this.viewModel.recordActivity())
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .onShown(() => this.viewModel.showRoute(ROUTE_ENTRY_DETAIL))
  }
}
