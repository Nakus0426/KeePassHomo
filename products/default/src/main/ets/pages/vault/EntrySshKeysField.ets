import { common } from '@kit.AbilityKit'
import { LengthMetrics, promptAction, SymbolGlyphModifier } from '@kit.ArkUI'
import { BusinessError, pasteboard } from '@kit.BasicServicesKit'
import { picker } from '@kit.CoreFileKit'
import { AppToast, inspectSshPrivateKey, SshKeyAlgorithm, SshKeyInspection } from '@ohos/common'
import { FileUtil, LogUtil, ResUtil } from '@pura/harmony-utils'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { EntryEditorViewModel } from '../../viewmodel/EntryEditorViewModel'
import { SshKeyDraft } from '../../model/SshKeyPayload'
import { exportSshPrivateKey } from '../../model/SshKeyExport'
import { SshKeyCard } from './SshKeyCard'
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

  private openRenameDialog(key: SshKeyDraft): void {
    this.renameTarget = key
    this.renameName = key.name
    this.getUIContext()
      .getPromptAction()
      .presentCustomDialog(() => this.renameDialog(), this.dialogController, {
        backgroundColor: $r('app.color.ds_surface_low'),
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
        fontColor: $r('app.color.ds_warning'),
        action: () => {
          this.editor.removeSshKey(key)
          this.onActivity()
        },
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  @Builder
  private addMenu() {
    Menu() {
      MenuItem({
        content: $r('app.string.ssh_key_pick_file'),
        symbolStartIcon: new SymbolGlyphModifier($r('app.string.symbol_upload_file')).fontSize($r('sys.float.Body_L')),
      })
        .labelFont({ size: $r('sys.float.Body_M') })
        .onClick(() => this.pickKeyFile())

      MenuItem({
        content: $r('app.string.ssh_key_paste'),
        symbolStartIcon: new SymbolGlyphModifier($r('app.string.symbol_copy')).fontSize(
          $r('sys.float.Body_L')),
      })
        .labelFont({ size: $r('sys.float.Body_M') })
        .onClick(() => this.startPaste())

      MenuItem({
        content: $r('app.string.ssh_key_generate'),
        symbolStartIcon: new SymbolGlyphModifier($r('app.string.symbol_generate')).fontSize($r('sys.float.Body_L')),
      })
        .labelFont({ size: $r('sys.float.Body_M') })
        .onClick(() => this.generateSheetVisible = true)
    }
    .menuItemDivider({
      strokeWidth: LengthMetrics.resource($r('sys.float.alert_divider_width')),
      color: $r('app.color.ds_outline_variant'),
      startMargin: LengthMetrics.resource($r('sys.float.menu_divider_start_margin')),
      endMargin: LengthMetrics.resource($r('sys.float.menu_divider_end_margin')),
    })
  }

  @Builder
  private renameDialog() {
    Column() {
      Text($r('app.string.ssh_key_rename'))
        .fontSize($r('sys.float.ohos_id_text_size_dialog_tittle'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.ds_text_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ left: $r('app.float.ds_space_md'), right: $r('app.float.ds_space_md') })

      TextInput({ placeholder: $r('app.string.ssh_key_name_placeholder'), text: this.renameName })
        .fontSize($r('sys.float.Body_L'))
        .height($r('app.float.control_height'))
        .backgroundColor(Color.Transparent)
        .showUnderline(true)
        .underlineColor({ normal: $r('app.color.ds_outline_variant'), typing: $r('app.color.ds_primary') })
        .margin({
          top: $r('app.float.ds_space_6'),
          left: $r('app.float.ds_space_md'),
          right: $r('app.float.ds_space_md'),
        })
        .onChange((value: string) => this.renameName = value)

      Row({ space: $r('app.float.ds_space_2') }) {
        Button($r('app.string.cancel'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('app.color.ds_primary'))
          .layoutWeight(1)
          .onClick(() => this.dialogController.close())

        Divider()
          .vertical(true)
          .strokeWidth(1)
          .color($r('app.color.ds_outline_variant'))
          .height($r('sys.float.ohos_id_dialog_divider_height'))

        Button($r('app.string.confirm'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('app.color.ds_primary'))
          .layoutWeight(1)
          .onClick(() => this.submitRename())
      }
      .width('100%')
      .margin({ top: $r('app.float.ds_space_2') })
      .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })
    }
    .width('100%')
    .padding({ top: $r('app.float.ds_space_6'), bottom: $r('app.float.ds_space_sm') })
  }

  // 与「其他」区的新增按钮同款，复用系统点按反馈；生成期间换成加载态并禁用。
  @Builder
  private addRow() {
    Row() {
      Button() {
        Row({ space: $r('app.float.ds_space_xs') }) {
          if (this.busy) {
            LoadingProgress()
              .width($r('sys.float.chip_normal_icon_size'))
              .height($r('sys.float.chip_normal_icon_size'))
              .color($r('app.color.ds_text_primary'))

            Text($r('app.string.ssh_key_generating'))
              .fontSize($r('sys.float.chip_normal_font_size'))
              .fontColor($r('app.color.ds_text_primary'))
          } else {
            SymbolGlyph($r('app.string.symbol_add'))
              .fontSize($r('sys.float.chip_normal_icon_size'))
              .fontColor([$r('app.color.ds_text_primary')])

            Text($r('app.string.add'))
              .fontSize($r('sys.float.chip_normal_font_size'))
              .fontColor($r('app.color.ds_text_primary'))
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
    Column({ space: $r('app.float.ds_space_sm') }) {
      Column({ space: $r('app.float.ds_space_2') }) {
        Text($r('app.string.ssh_key_paste_action'))
          .width('100%')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ds_text_primary'))

        Text($r('app.string.ssh_key_paste_reason'))
          .width('100%')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.ds_text_secondary'))
          .maxLines(2)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row() {
        PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Capsule })
          .fontSize($r('sys.float.chip_normal_font_size'))
          .backgroundColor($r('app.color.ds_surface_high'))
          .fontColor($r('app.color.ds_text_primary'))
          .onClick((_event: ClickEvent, result: PasteButtonOnClickResult) => this.pasteFromClipboard(result))
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .padding($r('app.float.ds_space_sm'))
    .backgroundColor($r('app.color.ds_surface_high'))
    .borderRadius($r('app.float.ds_radius_none'))
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
    Column({ space: $r('app.float.ds_space_sm') }) {
      ForEach(this.keys, (key: SshKeyDraft) => {
        SshKeyCard({
          sshKey: key,
          editable: !this.readOnly,
          onCopyPrivate: () => this.copy(key.privateKey),
          onCopyPublic: () => this.copy(key.publicKey),
          onExport: () => exportSshPrivateKey(this.getUIContext(), key),
          onRename: () => this.openRenameDialog(key),
          onRemove: () => this.confirmRemove(key),
        })
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
      backgroundColor: $r('app.color.ds_surface_lowest'),
      showClose: false,
      detents: [SheetSize.MEDIUM],
      onDisappear: () => this.generateSheetVisible = false,
    })
  }
}
