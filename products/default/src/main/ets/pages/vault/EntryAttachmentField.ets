import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo, picker } from '@kit.CoreFileKit'
import { AppToast } from '@ohos/common'
import { FileUtil, LogUtil, ResUtil } from '@pura/harmony-utils'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { AttachmentEditAction, EntryAttachmentEditor, EntryEditorViewModel } from '../../viewmodel/EntryEditorViewModel'
import { exportAttachment, previewAttachment } from '../../model/AttachmentFiles'
import { AttachmentCard } from './AttachmentCard'
import { AttachmentReauthDialog } from './AttachmentReauthDialog'

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
  @Local private reauthMessage: ResourceStr = ''
  @Local private reauthConfirm: ResourceStr = ''
  private pendingAction: (() => void) | undefined = undefined
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

  // 未保存的新附件直接用草稿字节，已入库的附件才回读引擎。
  private readAttachment(item: EntryAttachmentEditor): ArrayBuffer {
    return item.data ?? this.app.readAttachment(this.entryUuid, item.name)
  }

  // 导出与预览都把明文带出保险库，统一先认证；认证通过才在回调里读字节并落盘。
  private startExport(item: EntryAttachmentEditor): void {
    this.presentReauth($r('app.string.reauthenticate_message'), $r('app.string.reauthenticate_confirm'), () => {
      exportAttachment(this.getUIContext(), item.name, () => this.readAttachment(item))
    })
  }

  private startPreview(item: EntryAttachmentEditor): void {
    this.presentReauth($r('app.string.preview_reauth_message'), $r('app.string.preview_reauth_confirm'), () => {
      previewAttachment(this.getUIContext(), item.name, () => this.readAttachment(item))
    })
  }

  private presentReauth(message: ResourceStr, confirmLabel: ResourceStr, action: () => void): void {
    this.pendingAction = action
    this.reauthMessage = message
    this.reauthConfirm = confirmLabel
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

  private runPendingAction(): void {
    const action: (() => void) | undefined = this.pendingAction
    this.pendingAction = undefined
    if (action !== undefined) {
      action()
    }
  }

  @Builder
  private reauthDialog() {
    AttachmentReauthDialog({
      controller: this.dialogController,
      message: this.reauthMessage,
      confirmLabel: this.reauthConfirm,
      onAuthenticated: () => this.runPendingAction(),
    })
  }

  @Builder
  private attachmentRow(item: EntryAttachmentEditor) {
    AttachmentCard({
      name: item.name,
      fileSize: item.size,
      persisted: item.action === AttachmentEditAction.Keep,
      editable: !this.readOnly,
      onPreview: () => this.startPreview(item),
      onExport: () => this.startExport(item),
      onRemove: () => this.confirmRemove(item),
    })
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
        .width('100%')
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
