import { common } from '@kit.AbilityKit'
import { promptAction, SymbolGlyphModifier, uiMaterial } from '@kit.ArkUI'
import { BusinessError, pasteboard } from '@kit.BasicServicesKit'
import { fileIo, picker } from '@kit.CoreFileKit'
import { AppToast, inspectSshPrivateKey, SshKeyAlgorithm, SshKeyInspection } from '@ohos/common'
import { FileUtil, LogUtil, ResUtil } from '@pura/harmony-utils'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { EntryEditorViewModel } from '../../viewmodel/EntryEditorViewModel'
import { SshKeyDraft, sshKeySummary } from '../../model/SshKeyPayload'
import { isPasteboardReadGranted, requestPasteboardRead } from '../../model/PasteboardAccess'
import { SshKeyGeneratorSheet } from './SshKeyGeneratorSheet'

// 单条密钥文本上限：PEM 最大档 RSA8192 也远小于此值，用于拦住误粘贴的大文件。
const SSH_KEY_MAX_BYTES: number = 64 * 1024

function sshKeyFileName(sourceName: string, inspection: SshKeyInspection): string {
  if (sourceName.length > 0) {
    const dot: number = sourceName.lastIndexOf('.')
    const base: string = dot > 0 ? sourceName.slice(0, dot) : sourceName
    return base.length > 0 ? base : sourceName
  }
  return inspection.algorithm === 'RSA' ? 'id_rsa' : 'id_ed25519'
}

// SSH 密钥行：一个条目可放多条密钥，密钥内容序列化在受保护字段里，卡片只展示摘要。
@ComponentV2
export struct EntrySshKeysField {
  @Param editor: EntryEditorViewModel = new EntryEditorViewModel()
  @Param readOnly: boolean = false
  @Event onActivity: () => void = () => {
  }
  @Local private busy: boolean = false
  // 剪贴板读取只能由粘贴控件本身触发授权，故选中「粘贴」后再单独呈现一次控件。
  @Local private pasteMode: boolean = false
  @Local private generateSheetVisible: boolean = false
  @Local private renameName: string = ''
  private renameTarget: SshKeyDraft | undefined = undefined
  private readonly app: AppViewModel = appViewModel
  private readonly dialogController: promptAction.DialogController = new promptAction.DialogController()
  private readonly sheetMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
  })

  @Computed
  private get keys(): SshKeyDraft[] {
    return this.editor.sshKeys
  }

  private copy(value: string): void {
    if (value.length === 0) {
      return
    }
    this.app.copyValue(value).then((copied: boolean) => {
      if (copied) {
        AppToast.showAboveSheets(this.getUIContext(), $r('app.string.copy_completed'))
      }
    })
  }

  private async pickKeyFile(): Promise<void> {
    this.busy = true
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions()
      options.maxSelectNumber = 1
      options.selectMode = picker.DocumentSelectMode.FILE
      const uris: string[] = await new picker.DocumentViewPicker(context).select(options)
      if (uris === undefined || uris.length === 0) {
        return
      }
      this.addKey(FileUtil.getFileName(uris[0]), await FileUtil.readText(uris[0]))
    } catch (error) {
      const failure: BusinessError = error as BusinessError
      LogUtil.error(`读取 SSH 密钥文件失败，错误码=${failure.code}，错误信息=${failure.message}`)
      AppToast.showAboveSheets(this.getUIContext(), $r('app.string.ssh_key_pick_failed'))
    } finally {
      this.busy = false
    }
  }

  private addKey(sourceName: string, text: string): void {
    const content: string = text.trim()
    if (content.length === 0) {
      return
    }

    if (content.length > SSH_KEY_MAX_BYTES) {
      AppToast.showAboveSheets(this.getUIContext(),
        ResUtil.getStringSync($r('app.string.ssh_key_limit_exceeded'))
          .replace('%s', FileUtil.getFormatFileSize(SSH_KEY_MAX_BYTES)))
      return
    }
    const inspection: SshKeyInspection | undefined = inspectSshPrivateKey(content)
    if (inspection === undefined) {
      AppToast.showAboveSheets(this.getUIContext(), $r('app.string.ssh_key_inspect_failed'))
      return
    }
    this.editor.addSshKey(sshKeyFileName(sourceName, inspection), content,
      inspection.publicKey, inspection.algorithm, inspection.bits)
    this.pasteMode = false
    AppToast.showAboveSheets(this.getUIContext(), $r('app.string.ssh_key_added'))
    this.onActivity()
  }

  private readClipboard(): void {
    pasteboard.getSystemPasteboard().getData((error: BusinessError, data: pasteboard.PasteData) => {
      if (error) {
        LogUtil.error(`读取剪贴板失败，错误码=${error.code}，错误信息=${error.message}`)
        AppToast.showAboveSheets(this.getUIContext(), $r('app.string.ssh_key_paste_failed'))
        return
      }
      // 剪贴板没有文本记录时 getPrimaryText 运行期返回 undefined，类型声明未体现。
      const text: string | undefined = data.getPrimaryText() as string | undefined
      if (text === undefined || text.trim().length === 0) {
        AppToast.showAboveSheets(this.getUIContext(), $r('app.string.ssh_key_paste_empty'))
        return
      }
      this.addKey('', text)
    })
  }

  // 先申请受限权限：已授权或本次同意则直接读，被拒绝或当前不可申请时改用粘贴控件。
  private startPaste(): void {
    if (isPasteboardReadGranted()) {
      this.readClipboard()
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    requestPasteboardRead(context).then((granted: boolean) => {
      if (granted) {
        this.readClipboard()
        return
      }
      this.pasteMode = true
    }).catch((error: Error) => {
      LogUtil.error(`申请剪贴板读取权限失败，错误信息=${error.message}`)
      this.pasteMode = true
    })
  }

  private pasteFromClipboard(result: PasteButtonOnClickResult): void {
    if (this.busy) {
      return
    }
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      AppToast.showAboveSheets(this.getUIContext(), $r('app.string.ssh_key_paste_failed'))
      return
    }
    this.readClipboard()
  }

  // 确认即收起半模态：生成期间的忙碌反馈由「添加」按钮承担，结果用 toast 反馈。
  private generate(algorithm: SshKeyAlgorithm): void {
    this.generateSheetVisible = false
    if (this.busy) {
      return
    }
    this.busy = true
    this.app.generateSshKeyPair(this.editor, algorithm).then((generated: boolean) => {
      if (generated) {
        AppToast.showAboveSheets(this.getUIContext(), $r('app.string.ssh_key_generated'))
        this.onActivity()
        return
      }
      AppToast.showAboveSheets(this.getUIContext(), $r('app.string.ssh_key_generate_failed'))
    }).finally(() => this.busy = false)
  }

  private async exportPrivate(key: SshKeyDraft): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
      options.newFileNames = [key.name]
      const uris: string[] = await new picker.DocumentViewPicker(context).save(options)
      if (uris === undefined || uris.length === 0) {
        return
      }
      const data: string = key.privateKey
      const file: fileIo.File = FileUtil.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC)
      try {
        FileUtil.writeSync(file.fd, data)
      } finally {
        FileUtil.closeSync(file)
      }
      AppToast.showAboveSheets(this.getUIContext(), $r('app.string.ssh_key_export_success'))
    } catch (error) {
      const failure: BusinessError = error as BusinessError
      LogUtil.error(`导出 SSH 私钥失败，错误码=${failure.code}，错误信息=${failure.message}`)
      AppToast.showAboveSheets(this.getUIContext(), $r('app.string.ssh_key_pick_failed'))
    }
  }

  private openRenameDialog(key: SshKeyDraft): void {
    this.renameTarget = key
    this.renameName = key.name
    this.getUIContext()
      .getPromptAction()
      .presentCustomDialog(() => this.renameDialog(), this.dialogController, {
        width: '96%',
        cornerRadius: $r('sys.float.ohos_id_corner_radius_dialog'),
        backgroundColor: $r('sys.color.comp_background_primary'),
      })
      .catch((error: BusinessError) => {
        LogUtil.error(`打开重命名弹窗失败，错误码=${error.code}，错误信息=${error.message}`)
      })
  }

  private submitRename(): void {
    const target: SshKeyDraft | undefined = this.renameTarget
    const name: string = this.renameName.trim()
    if (target === undefined) {
      return
    }
    if (name.length === 0) {
      AppToast.show(this.getUIContext(), $r('app.string.ssh_key_name_required'))
      return
    }
    this.dialogController.close()
    if (name !== target.name && this.editor.sshKeyNameTaken(name, target)) {
      AppToast.show(this.getUIContext(), $r('app.string.ssh_key_name_duplicate'))
      return
    }
    this.editor.renameSshKey(target, name)
    this.renameTarget = undefined
    this.onActivity()
  }

  private confirmRemove(key: SshKeyDraft): void {
    const options: AlertDialogParamWithButtons = {
      title: $r('app.string.ssh_key_remove'),
      message: $r('app.string.ssh_key_remove_message'),
      primaryButton: {
        value: $r('app.string.cancel'),
        action: () => {
        },
      },
      secondaryButton: {
        value: $r('app.string.delete_entry'),
        fontColor: $r('sys.color.warning'),
        action: () => {
          this.editor.removeSshKey(key)
          this.onActivity()
        },
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  @Builder
  private keyMenu(key: SshKeyDraft) {
    Menu() {
      MenuItem({
        content: $r('app.string.ssh_key_copy_private'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.doc_text_on_doc_text')),
      })
        .onClick(() => this.copy(key.privateKey))

      MenuItem({
        content: $r('app.string.ssh_key_copy_public'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.key')),
      })
        .onClick(() => this.copy(key.publicKey))

      MenuItem({
        content: $r('app.string.ssh_key_export'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_down_to_line')),
      })
        .onClick(() => this.exportPrivate(key))

      if (!this.readOnly) {
        MenuItem({
          content: $r('app.string.ssh_key_rename'),
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.square_and_pencil')),
        })
          .onClick(() => this.openRenameDialog(key))

        MenuItem({
          content: $r('app.string.ssh_key_remove'),
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.trash')).fontColor([$r('sys.color.warning')]),
        })
          .contentFontColor($r('sys.color.warning'))
          .onClick(() => this.confirmRemove(key))
      }
    }
  }

  @Builder
  private addMenu() {
    Menu() {
      MenuItem({
        content: $r('app.string.ssh_key_pick_file'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.doc_text')).fontSize($r('sys.float.Body_L')),
      })
        .labelFont({ size: $r('sys.float.Body_M') })
        .onClick(() => this.pickKeyFile())

      MenuItem({
        content: $r('app.string.ssh_key_paste'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.doc_text_on_doc_text')).fontSize(
          $r('sys.float.Body_L')),
      })
        .labelFont({ size: $r('sys.float.Body_M') })
        .onClick(() => this.startPaste())

      MenuItem({
        content: $r('app.string.ssh_key_generate'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.wand_and_stars')).fontSize($r('sys.float.Body_L')),
      })
        .labelFont({ size: $r('sys.float.Body_M') })
        .onClick(() => this.generateSheetVisible = true)
    }
    .menuItemDivider({ color: $r('sys.color.comp_divider') })
  }

  @Builder
  private renameDialog() {
    Column({ space: $r('sys.float.padding_level6') }) {
      Text($r('app.string.ssh_key_rename'))
        .fontSize($r('sys.float.Title_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)

      TextInput({ placeholder: $r('app.string.ssh_key_name_placeholder'), text: this.renameName })
        .fontSize($r('sys.float.Body_L'))
        .height($r('app.float.control_height'))
        .backgroundColor(Color.Transparent)
        .showUnderline(true)
        .underlineColor({ typing: $r('sys.color.brand') })
        .onChange((value: string) => this.renameName = value)

      Row({ space: $r('sys.float.padding_level6') }) {
        Button($r('app.string.cancel'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
          .onClick(() => this.dialogController.close())

        Divider()
          .vertical(true)
          .color($r('sys.color.comp_divider'))
          .height($r('sys.float.Title_S'))

        Button($r('app.string.confirm'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.brand'))
          .layoutWeight(1)
          .onClick(() => this.submitRename())
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
  }

  @Builder
  private keyCard(key: SshKeyDraft) {
    Row({ space: $r('sys.float.padding_level8') }) {
      Stack() {
        SymbolGlyph($r('sys.symbol.key'))
          .fontSize($r('sys.float.Title_L'))
          .fontColor([$r('sys.color.brand')])
      }
      .padding($r('sys.float.padding_level8'))
      .borderRadius('50%')
      .backgroundColor($r('sys.color.comp_emphasize_secondary'))

      Column({ space: $r('sys.float.padding_level2') }) {
        Row({ space: $r('sys.float.padding_level4') }) {
          Text(key.name)
            .layoutWeight(1)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(key.persisted ? $r('app.string.ssh_key_badge_saved') : $r('app.string.ssh_key_badge_pending'))
            .fontSize($r('sys.float.Caption_M'))
            .fontColor($r('sys.color.brand'))
            .padding({
              left: $r('sys.float.padding_level8'),
              right: $r('sys.float.padding_level8'),
              top: $r('sys.float.padding_level2'),
              bottom: $r('sys.float.padding_level2'),
            })
            .backgroundColor($r('sys.color.comp_emphasize_secondary'))
            .borderRadius($r('sys.float.corner_radius_level16'))
        }
        .width('100%')

        Text(sshKeySummary(key))
          .width('100%')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
    .borderRadius($r('sys.float.corner_radius_level10'))
    .onClick(() => this.copy(key.privateKey))
    .bindContextMenu(this.keyMenu(key), ResponseType.LongPress)
  }

  // 与「其他」区的新增按钮同款，复用系统点按反馈；生成期间换成加载态并禁用。
  @Builder
  private addRow() {
    Row() {
      Button() {
        Row({ space: $r('sys.float.padding_level4') }) {
          if (this.busy) {
            LoadingProgress()
              .width($r('sys.float.chip_normal_icon_size'))
              .height($r('sys.float.chip_normal_icon_size'))
              .color($r('sys.color.font_emphasize'))

            Text($r('app.string.ssh_key_generating'))
              .fontSize($r('sys.float.chip_normal_font_size'))
              .fontColor($r('sys.color.font_emphasize'))
          } else {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize($r('sys.float.chip_normal_icon_size'))
              .fontColor([$r('sys.color.font_emphasize')])

            Text($r('app.string.add'))
              .fontSize($r('sys.float.chip_normal_font_size'))
              .fontColor($r('sys.color.font_emphasize'))
          }
        }
      }
      .width('100%')
      .height($r('sys.float.chip_normal_height'))
      .buttonStyle(ButtonStyleMode.NORMAL)
      .type(ButtonType.Capsule)
      .enabled(!this.busy)
      .bindMenu(this.addMenu)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  // 粘贴控件必须由用户直接点击才能拿到剪贴板临时授权，故独立成一块而不是菜单项。
  @Builder
  private pasteRow() {
    Column({ space: $r('sys.float.padding_level8') }) {
      Column({ space: $r('sys.float.padding_level2') }) {
        Text($r('app.string.ssh_key_paste_action'))
          .width('100%')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))

        Text($r('app.string.ssh_key_paste_reason'))
          .width('100%')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row() {
        PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
          .fontSize($r('sys.float.chip_normal_font_size'))
          .backgroundColor($r('sys.color.comp_emphasize_secondary'))
          .fontColor($r('sys.color.font_emphasize'))
          .onClick((_event: ClickEvent, result: PasteButtonOnClickResult) => this.pasteFromClipboard(result))
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius($r('sys.float.corner_radius_level10'))
  }

  @LocalBuilder
  private generateSheet() {
    SshKeyGeneratorSheet({
      onConfirm: (algorithm: SshKeyAlgorithm) => this.generate(algorithm),
      onClose: () => this.generateSheetVisible = false,
      onActivity: () => this.onActivity(),
    })
  }

  build() {
    Column({ space: $r('sys.float.padding_level8') }) {
      ForEach(this.keys, (key: SshKeyDraft) => {
        this.keyCard(key)
      }, (key: SshKeyDraft) => `${key.id}`)

      if (!this.readOnly) {
        if (this.pasteMode) {
          this.pasteRow()
        }
        this.addRow()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .bindSheet($$this.generateSheetVisible, this.generateSheet(), {
      dragBar: true,
      backgroundColor: Color.Transparent,
      systemMaterial: this.sheetMaterial,
      showClose: false,
      detents: [SheetSize.MEDIUM],
      onDisappear: () => this.generateSheetVisible = false,
    })
  }
}
