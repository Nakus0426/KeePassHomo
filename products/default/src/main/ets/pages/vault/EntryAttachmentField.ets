import { common } from '@kit.AbilityKit'
import { promptAction } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo, picker } from '@kit.CoreFileKit'
import { FileUtil, LogUtil, ResUtil } from '@pura/harmony-utils'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { AttachmentEditAction, EntryAttachmentEditor, EntryEditorViewModel } from '../../viewmodel/EntryEditorViewModel'
import { exportAttachment, previewAttachment } from '../../model/AttachmentFiles'
import { AttachmentCard } from './AttachmentCard'
import { AttachmentReauthDialog } from './AttachmentReauthDialog'
import { DsButton, DsButtonTone, DsButtonVariant } from '../../components/DsButton'
import { DsDialog } from '../../components/DsDialog'
import { DsField } from '../../components/DsField'
import { DsInput, DsInputTone } from '../../components/DsInput'
import { DsNotice, DsNoticeTone } from '../../components/DsNotice'
import { DsToastHost } from '../../components/DsToast'
import { pickFiles, UserCancelledError } from '../../model/DocumentPicker'

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
  @Local private renameName: string = ''
  @Local private renameError: ResourceStr | undefined = undefined
  private pendingAction: (() => void) | undefined = undefined
  private renameTarget: EntryAttachmentEditor | undefined = undefined
  private readonly app: AppViewModel = appViewModel
  private readonly dialogController: promptAction.DialogController = new promptAction.DialogController()
  private readonly renameDialogController: promptAction.DialogController = new promptAction.DialogController()

  @Computed
  private get attachments(): EntryAttachmentEditor[] {
    return this.editor.visibleAttachments()
  }

  @Computed
  private get totalSize(): number {
    let total: number = 0
    for (const item of this.attachments) {
      total += item.size
    }
    return total
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

  private summaryText(): ResourceStr {
    if (this.pendingSize > 0) {
      return $r('app.string.attachment_summary_pending', this.attachments.length,
        FileUtil.getFormatFileSize(this.totalSize), FileUtil.getFormatFileSize(this.pendingSize))
    }
    return $r('app.string.attachment_summary', this.attachments.length,
      FileUtil.getFormatFileSize(this.totalSize))
  }

  private async addFiles(): Promise<void> {
    this.busy = true
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions()
      options.selectMode = picker.DocumentSelectMode.FILE
      const uris: string[] = await pickFiles(context, options)
      for (const uri of uris) {
        const name: string = FileUtil.getFileName(uri)
        const data: ArrayBuffer = this.readFile(uri)
        if (data.byteLength > ATTACHMENT_MAX_BYTES) {
          DsToastHost.show(this.getUIContext(),
            ResUtil.getStringSync($r('app.string.attachment_limit_exceeded'))
              .replace('%s', FileUtil.getFormatFileSize(ATTACHMENT_MAX_BYTES)))
          continue
        }
        this.editor.addAttachment(name, data)
      }
      this.onActivity()
    } catch (error) {
      if (error instanceof UserCancelledError) {
        return
      }
      const failure: BusinessError = error as BusinessError
      LogUtil.error(`读取附件失败，错误码=${failure.code}，错误信息=${failure.message}`)
      DsToastHost.show(this.getUIContext(), $r('app.string.attachment_pick_failed'))
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
        value: $r('app.string.attachment_delete'),
        fontColor: $r('app.color.ds_error'),
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

  private openRename(item: EntryAttachmentEditor): void {
    this.renameTarget = item
    this.renameName = item.name
    this.renameError = undefined
    this.getUIContext()
      .getPromptAction()
      .presentCustomDialog(() => this.renameDialog(), this.renameDialogController, {
        backgroundColor: Color.Transparent,
        backgroundBlurStyle: BlurStyle.NONE,
        cornerRadius: 0,
        width: $r('app.float.dialog_width'),
        alignment: DialogAlignment.Center,
        maskColor: $r('app.color.ds_scrim'),
      })
      .catch((error: BusinessError) => {
        LogUtil.error(`打开附件重命名弹窗失败，错误码=${error.code}，错误信息=${error.message}`)
      })
  }

  private validateAttachmentName(name: string): ResourceStr | undefined {
    if (name.length === 0) {
      return $r('app.string.attachment_name_required')
    }
    const target: EntryAttachmentEditor | undefined = this.renameTarget
    if (target !== undefined && this.editor.attachmentNameTaken(name, target)) {
      return $r('app.string.attachment_name_duplicate')
    }
    return undefined
  }

  private applyRenameName(value: string): void {
    this.renameName = value
    if (this.renameError !== undefined) {
      this.renameError = this.validateAttachmentName(value.trim())
    }
  }

  // 已入库附件按「删除旧键 + 写入新键」提交，字节直接沿用当前内容。
  private submitRename(): void {
    const target: EntryAttachmentEditor | undefined = this.renameTarget
    if (target === undefined) {
      return
    }
    const name: string = this.renameName.trim()
    const error: ResourceStr | undefined = this.validateAttachmentName(name)
    this.renameError = error
    if (error !== undefined) {
      return
    }
    this.renameDialogController.close()
    this.editor.renameAttachment(target, name, this.readAttachment(target))
    this.renameTarget = undefined
    this.onActivity()
  }

  private presentReauth(message: ResourceStr, confirmLabel: ResourceStr, action: () => void): void {
    this.pendingAction = action
    this.reauthMessage = message
    this.reauthConfirm = confirmLabel
    this.getUIContext()
      .getPromptAction()
      .presentCustomDialog(() => this.reauthDialog(), this.dialogController, {
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

  @LocalBuilder
  private renameInputField() {
    DsInput({
      text: this.renameName,
      placeholder: $r('app.string.attachment_name_placeholder'),
      tone: this.renameError === undefined ? DsInputTone.Default : DsInputTone.Error,
      onChange: (value: string) => this.applyRenameName(value),
      onSubmit: () => this.submitRename(),
    })
  }

  @LocalBuilder
  private renameInput() {
    DsField({
      feedback: this.renameError,
      reserveFeedbackSpace: true,
      contentBuilder: this.renameInputField,
    })
  }

  @Builder
  private renameDialog() {
    DsDialog({
      title: $r('app.string.attachment_rename'),
      message: $r('app.string.attachment_rename_message'),
      cancelLabel: $r('app.string.cancel'),
      confirmLabel: $r('app.string.save'),
      contentBuilder: this.renameInput,
      onCancel: () => this.renameDialogController.close(),
      onConfirm: () => this.submitRename(),
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
      onRename: () => this.openRename(item),
      onRemove: () => this.confirmRemove(item),
    })
  }

  build() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      if (this.attachments.length === 0) {
        DsNotice({
          tone: DsNoticeTone.Default,
          title: $r('app.string.attachment_empty_title'),
          body: $r('app.string.attachment_empty_body'),
        })
      }

      ForEach(this.attachments, (item: EntryAttachmentEditor) => {
        this.attachmentRow(item)
      }, (item: EntryAttachmentEditor) => `${item.id}`)

      if (this.attachments.length > 0) {
        Text(this.summaryText())
          .width('100%')
          .fontSize($r('app.float.ds_font_body_sm'))
          .fontColor($r('app.color.ds_text_tertiary'))
      }

      if (!this.readOnly) {
        DsButton({
          label: $r('app.string.attachment_add'),
          variant: DsButtonVariant.Dashed,
          tone: DsButtonTone.Default,
          leadingIcon: $r('app.string.symbol_add'),
          loading: this.busy,
          fullWidth: true,
          onTap: () => {
            this.addFiles()
          },
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
