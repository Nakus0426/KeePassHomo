import { uiMaterial } from '@kit.ArkUI'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { VaultEntry, VaultFormat, VaultGroup } from '@ohos/common'
import { ROUTE_ENTRY_DETAIL, ROUTE_ENTRY_EDIT, ROUTE_TEMPLATE, ROUTE_VAULT } from '../../constants/RouteConstants'
import { GeneratorContent } from '../generator/GeneratorComponents'
import { PageTopBar, StatusText } from '../../components/PageChrome'
import { VaultBrowseMode } from '../../model/StageOneVaultStore'
import { VaultAppViewModel } from '../../viewmodel/VaultAppViewModel'

@ComponentV2
export struct EntryEditPage {
  @Param viewModel: VaultAppViewModel = new VaultAppViewModel()
  @Local private generatorSheetVisible: boolean = false
  private readonly generatorSheetMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
    applyShadow: true,
  })

  private openGeneratorSheet(): void {
    this.viewModel.prepareGenerator()
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
