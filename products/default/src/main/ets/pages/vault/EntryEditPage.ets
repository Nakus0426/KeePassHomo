import { uiMaterial } from '@kit.ArkUI'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { VaultGroup } from '@ohos/common'
import { ROUTE_VAULT } from '../../constants/RouteConstants'
import { GeneratorContent } from '../generator/GeneratorComponents'
import { StatusText } from '../../components/PageChrome'
import { PASSWORD_REVEAL_SECONDS } from '../../constants/SecurityConstants'
import { appRouter } from '../../navigation/AppRouter'
import { EntryEditParam } from '../../navigation/RouteParams'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { EntryEditorViewModel } from '../../viewmodel/EntryEditorViewModel'

@ComponentV2
export struct EntryEditPage {
  private readonly viewModel: AppViewModel = appViewModel
  @Local private editor: EntryEditorViewModel = new EntryEditorViewModel()
  @Local private generatorSheetVisible: boolean = false
  @Local private showPassword: boolean = false
  @Local private unsavedDialogVisible: boolean = false
  private readonly generatorSheetMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
    applyShadow: true,
  })
  private revealTimer: number = -1

  aboutToAppear(): void {
    const param: EntryEditParam | undefined = appRouter.topParam() as EntryEditParam | undefined
    if (param?.entryUuid !== undefined && param.entryUuid.length > 0) {
      this.viewModel.loadEntryForEdit(this.editor, param.entryUuid)
    } else {
      this.viewModel.loadNewEntry(this.editor)
    }
  }

  private revealPassword(): void {
    this.showPassword = true
    this.revealTimer = setTimeout(() => this.showPassword = false, PASSWORD_REVEAL_SECONDS * 1000)
  }

  private hidePassword(): void {
    this.showPassword = false
    if (this.revealTimer >= 0) {
      clearTimeout(this.revealTimer)
      this.revealTimer = -1
    }
  }

  private requestEditorExit(): void {
    if (!this.editor.changed()) {
      this.exitEditor()
      return
    }
    this.unsavedDialogVisible = true
  }

  private exitEditor(): void {
    this.unsavedDialogVisible = false
    if (this.editor.entryUuid.length === 0) {
      appRouter.resetTo(ROUTE_VAULT)
    } else {
      appRouter.pop()
    }
  }

  private openGeneratorSheet(): void {
    this.viewModel.prepareGenerator()
    this.generatorSheetVisible = true
  }

  private closeGeneratorSheet(): void {
    this.generatorSheetVisible = false
    this.viewModel.generator.clearSensitiveState()
  }

  private fillPasswordFromGenerator(): void {
    this.editor.setPassword(this.viewModel.generator.value)
    this.viewModel.generator.clearSensitiveState()
    this.viewModel.recordActivity()
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
                .onClick(() => this.requestEditorExit())
              Text(this.editor.entryUuid.length === 0
                ? $r('app.string.new_entry') : $r('app.string.edit'))
                .layoutWeight(1)
                .fontSize($r('app.float.text_heading'))
                .fontWeight(FontWeight.Bold)
              Button(this.viewModel.busy ? $r('app.string.saving') : $r('app.string.save'))
                .enabled(!this.viewModel.busy)
                .backgroundColor(Color.Transparent)
                .fontColor($r('sys.color.brand'))
                .onClick(() => this.viewModel.saveEntry(this.editor))
            }
            .width('100%')
            .height($r('app.float.control_height'))

            TextInput({ placeholder: $r('app.string.entry_title'), text: this.editor.title })
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.comp_background_primary'))
              .onChange((value: string) => this.editor.setTitle(value))
            TextInput({ placeholder: $r('app.string.username'), text: this.editor.username })
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.comp_background_primary'))
              .onChange((value: string) => this.editor.setUsername(value))
            Row({ space: 8 }) {
              TextInput({ placeholder: $r('app.string.password'), text: this.editor.password })
                .type(this.showPassword ? InputType.Normal : InputType.Password)
                .height($r('app.float.control_height'))
                .layoutWeight(1)
                .backgroundColor($r('sys.color.comp_background_primary'))
                .onChange((value: string) => this.editor.setPassword(value))
              Button(this.showPassword ? $r('app.string.hide') : $r('app.string.show'))
                .height($r('app.float.control_height'))
                .backgroundColor($r('sys.color.comp_emphasize_secondary'))
                .fontColor($r('sys.color.brand'))
                .onClick(() => this.showPassword ? this.hidePassword() : this.revealPassword())
              Button($r('app.string.generate'))
                .height($r('app.float.control_height'))
                .backgroundColor($r('sys.color.brand'))
                .onClick(() => this.openGeneratorSheet())
            }
            .width('100%')

            TextInput({ placeholder: $r('app.string.website'), text: this.editor.url })
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.comp_background_primary'))
              .onChange((value: string) => this.editor.setUrl(value))
            if (this.editor.url.length > 0 &&
              !this.editor.url.startsWith('https://') &&
              !this.editor.url.startsWith('http://')) {
              Text('网址格式异常，但不会阻止保存')
                .width('100%')
                .fontColor($r('sys.color.alert'))
            }
            TextArea({ placeholder: $r('app.string.notes'), text: this.editor.notes })
              .width('100%')
              .backgroundColor($r('sys.color.comp_background_primary'))
              .onChange((value: string) => this.editor.setNotes(value))
            TextInput({ placeholder: $r('app.string.tags'), text: this.editor.tags })
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.comp_background_primary'))
              .onChange((value: string) => this.editor.setTags(value))
            Text($r('app.string.group'))
              .width('100%')
              .fontColor($r('sys.color.font_secondary'))
            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.viewModel.groups(), (group: VaultGroup) => {
                  Button(group.path)
                    .backgroundColor(this.editor.groupUuid === group.uuid
                      ? $r('sys.color.brand') : $r('sys.color.comp_background_primary'))
                    .fontColor(this.editor.groupUuid === group.uuid
                      ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
                    .onClick(() => this.editor.setGroup(group.uuid))
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

        if (this.unsavedDialogVisible) {
          Column({ space: 12 }) {
            Text($r('app.string.unsaved_title'))
              .fontSize($r('app.float.text_heading'))
              .fontWeight(FontWeight.Bold)
            Text($r('app.string.unsaved_message'))
              .fontColor($r('sys.color.font_secondary'))
            Button($r('app.string.save'))
              .width('100%')
              .backgroundColor($r('sys.color.brand'))
              .onClick(() => this.viewModel.saveEntry(this.editor))
            Button($r('app.string.discard'))
              .width('100%')
              .backgroundColor($r('sys.color.background_secondary'))
              .fontColor($r('sys.color.warning'))
              .onClick(() => this.exitEditor())
            Button($r('app.string.continue_editing'))
              .width('100%')
              .backgroundColor(Color.Transparent)
              .fontColor($r('sys.color.brand'))
              .onClick(() => this.unsavedDialogVisible = false)
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
    .onHidden(() => this.hidePassword())
    .onBackPressed(() => {
      if (this.unsavedDialogVisible) {
        this.unsavedDialogVisible = false
      } else {
        this.requestEditorExit()
      }
      return true
    })
  }
}

@Builder
export function entryEditPageBuilder() {
  EntryEditPage()
}
