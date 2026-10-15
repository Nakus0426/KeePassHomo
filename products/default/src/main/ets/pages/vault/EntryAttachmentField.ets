import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo, picker } from '@kit.CoreFileKit'
import { AppToast, ReauthenticationPurpose } from '@ohos/common'
import { FileUtil, LogUtil, ResUtil } from '@pura/harmony-utils'
import { IconToggleButton } from '../../components/IconToggleButton'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { AttachmentEditAction, EntryAttachmentEditor, EntryEditorViewModel } from '../../viewmodel/EntryEditorViewModel'

// 单个附件上限：整库每次保存都要完整重写，附件过大直接放大内存峰值与写入耗时。
const ATTACHMENT_MAX_BYTES: number = 10 * 1024 * 1024

// 附件行：文件进出库都在这里完成，取值不进 KDBX 字段而进条目附件。
@ComponentV2
export struct EntryAttachmentField {
  @Param editor: EntryEditorViewModel = new EntryEditorViewModel()
  @Param entryUuid: string = ''
  @Param readOnly: boolean = false
  @Param active: boolean = false
  @Event onActivity: () => void = () => {
  }
  @Local private busy: boolean = false
  @Local private reauthPassword: string = ''
  private pendingExportName: string = ''
  private pendingExportData: ArrayBuffer | undefined = undefined
  private readonly app: AppViewModel = appViewModel
  private readonly dialogController: promptAction.DialogController = new promptAction.DialogController()

  @Computed
  private get attachments(): EntryAttachmentEditor[] {
    return this.editor.visibleAttachments()
  }

  // 待保存的新增附件体积：让用户在落盘前看到保险库会变大多少。
  @Computed
  private get pendingSize(): number {
    let total: number = 0
    for (const item of this.attachments) {
      if (item.action === AttachmentEditAction.Add) {
        total += item.size
      }
    }
    return total
  }

  private async addFiles(): Promise<void> {
    this.busy = true
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions()
      options.selectMode = picker.DocumentSelectMode.FILE
      const uris: string[] = await new picker.DocumentViewPicker(context).select(options)
      if (uris === undefined || uris.length === 0) {
        return
      }
      for (const uri of uris) {
        const name: string = FileUtil.getFileName(uri)
        const data: ArrayBuffer = this.readFile(uri)
        if (data.byteLength > ATTACHMENT_MAX_BYTES) {
          AppToast.showAboveSheets(this.getUIContext(),
            ResUtil.getStringSync($r('app.string.attachment_limit_exceeded'))
              .replace('%s', FileUtil.getFormatFileSize(ATTACHMENT_MAX_BYTES)))
          continue
        }
        this.editor.addAttachment(name, data)
      }
      this.onActivity()
    } catch (error) {
      const failure: BusinessError = error as BusinessError
      LogUtil.error(`读取附件失败，错误码=${failure.code}，错误信息=${failure.message}`)
      AppToast.showAboveSheets(this.getUIContext(), $r('app.string.attachment_pick_failed'))
    } finally {
      this.busy = false
    }
  }

  // picker 返回的 uri 只有临时权限，必须立刻读进内存再交给草稿。
  private readFile(uri: string): ArrayBuffer {
    const file: fileIo.File = FileUtil.openSync(uri, fileIo.OpenMode.READ_ONLY)
    try {
      const stat: fileIo.Stat = FileUtil.statSync(file.fd)
      const data: ArrayBuffer = new ArrayBuffer(stat.size)
      FileUtil.readSync(file.fd, data, { offset: 0, length: stat.size })
      return data
    } finally {
      FileUtil.closeSync(file)
    }
  }

  private confirmRemove(item: EntryAttachmentEditor): void {
    const options: AlertDialogParamWithButtons = {
      title: $r('app.string.attachment_remove_title'),
      message: $r('app.string.attachment_remove_message'),
      primaryButton: {
        value: $r('app.string.cancel'),
        action: () => {
        },
      },
      secondaryButton: {
        value: $r('app.string.delete_entry'),
        fontColor: $r('sys.color.warning'),
        action: () => {
          this.editor.removeAttachment(item)
          this.onActivity()
        },
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  // 导出前再认证：内容离开保险库属于高风险动作，认证通过才写文件。
  private startExport(item: EntryAttachmentEditor): void {
    this.pendingExportName = item.name
    this.pendingExportData = item.data
    this.reauthPassword = ''
    this.presentReauthDialog()
  }

  private presentReauthDialog(): void {
    this.getUIContext()
      .getPromptAction()
      .presentCustomDialog(() => this.reauthDialog(), this.dialogController, {
        width: '96%',
        cornerRadius: $r('sys.float.ohos_id_corner_radius_dialog'),
        backgroundColor: $r('sys.color.comp_background_primary'),
      })
      .catch((error: BusinessError) => {
        LogUtil.error(`打开再认证弹窗失败，错误码=${error.code}，错误信息=${error.message}`)
      })
  }

  private submitExport(): void {
    const password: string = this.reauthPassword
    if (password.length === 0) {
      return
    }
    const name: string = this.pendingExportName
    const cached: ArrayBuffer | undefined = this.pendingExportData
    this.dialogController.close()
    this.app.session.reauthenticate(ReauthenticationPurpose.ExportData, password, async () => {
      await this.writeExport(name, cached)
    }).catch((error: Error) => {
      LogUtil.error(`导出附件再认证失败，错误信息=${error.message}`)
      AppToast.showAboveSheets(this.getUIContext(), $r('app.string.reauthenticate_failed'))
    })
  }

  private async writeExport(name: string, cached: ArrayBuffer | undefined): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions()
    options.newFileNames = [name]
    const uris: string[] = await new picker.DocumentViewPicker(context).save(options)
    if (uris === undefined || uris.length === 0) {
      return
    }
    // 未保存的新附件直接用草稿字节，已入库的附件才回读引擎。
    const data: ArrayBuffer = cached ?? this.app.readAttachment(this.entryUuid, name)
    const file: fileIo.File = FileUtil.openSync(uris[0], fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC)
    try {
      FileUtil.writeSync(file.fd, data)
    } finally {
      FileUtil.closeSync(file)
    }
    this.pendingExportName = ''
    this.pendingExportData = undefined
    AppToast.showAboveSheets(this.getUIContext(), $r('app.string.attachment_export_saved'))
  }

  @Builder
  private reauthDialog() {
    Column({ space: $r('sys.float.padding_level6') }) {
      Text($r('app.string.reauthenticate_title'))
        .fontSize($r('sys.float.Title_M'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
        .textAlign(TextAlign.Center)

      Text($r('app.string.reauthenticate_message'))
        .fontSize($r('sys.float.Body_M'))
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)

      TextInput({ placeholder: $r('app.string.password'), text: this.reauthPassword })
        .type(InputType.Password)
        .fontSize($r('sys.float.Body_L'))
        .height($r('app.float.control_height'))
        .backgroundColor(Color.Transparent)
        .showUnderline(true)
        .underlineColor({ typing: $r('sys.color.brand') })
        .onChange((value: string) => this.reauthPassword = value)

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

        Button($r('app.string.reauthenticate_confirm'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.brand'))
          .layoutWeight(1)
          .onClick(() => this.submitExport())
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
  }

  @Builder
  private attachmentRow(item: EntryAttachmentEditor) {
    Row({ space: $r('sys.float.padding_level8') }) {
      SymbolGlyph($r('sys.symbol.paperclip'))
        .fontSize($r('sys.float.Title_S'))
        .fontColor([$r('sys.color.brand')])

      Column({ space: $r('sys.float.padding_level2') }) {
        Text(item.name)
          .width('100%')
          .fontSize($r('sys.float.Body_M'))
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(FileUtil.getFormatFileSize(item.size))
          .width('100%')
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      IconToggleButton({
        symbol: $r('sys.symbol.arrow_down_to_line'),
        accessibilityLabel: $r('app.string.attachment_export'),
        exclusive: true,
        onToggle: () => this.startExport(item),
      })
      IconToggleButton({
        symbol: $r('sys.symbol.trash'),
        accessibilityLabel: $r('app.string.attachment_remove'),
        exclusive: true,
        onToggle: () => this.confirmRemove(item),
      })
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.ohos_id_corner_radius_text_field'))
  }

  build() {
    Column({ space: $r('sys.float.padding_level8') }) {
      ForEach(this.attachments, (item: EntryAttachmentEditor) => {
        this.attachmentRow(item)
      }, (item: EntryAttachmentEditor) => `${item.id}`)

      if (!this.readOnly) {
        Button() {
          Row({ space: $r('sys.float.padding_level4') }) {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize($r('sys.float.chip_normal_icon_size'))
              .fontColor([$r('sys.color.font_emphasize')])

            Text($r('app.string.attachment_add'))
              .fontSize($r('sys.float.chip_normal_font_size'))
              .fontColor($r('sys.color.font_emphasize'))
          }
        }
        .height($r('sys.float.chip_normal_height'))
        .buttonStyle(ButtonStyleMode.NORMAL)
        .type(ButtonType.Capsule)
        .enabled(!this.busy)
        .onClick(() => this.addFiles())
      }

      if (this.pendingSize > 0) {
        Text(ResUtil.getStringSync($r('app.string.attachment_size_notice'))
          .replace('%s', FileUtil.getFormatFileSize(this.pendingSize)))
          .width('100%')
          .fontSize($r('sys.float.Caption_S'))
          .fontColor($r('sys.color.font_tertiary'))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
