import { promptAction } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { VaultAttachmentMeta } from '@ohos/common'
import { LogUtil } from '@pura/harmony-utils'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { exportAttachment, previewAttachment } from '../../model/AttachmentFiles'
import { AttachmentCard } from './AttachmentCard'
import { AttachmentReauthDialog } from './AttachmentReauthDialog'

// 预览态的附件卡片列表：卡片与编辑态共用 AttachmentCard，只注入预览态可用的动作。
@ComponentV2
export struct EntryAttachmentList {
  @Param entryUuid: string = ''
  @Param attachments: VaultAttachmentMeta[] = []
  @Local private reauthMessage: ResourceStr = ''
  @Local private reauthConfirm: ResourceStr = ''
  private pendingAction: (() => void) | undefined = undefined
  private readonly app: AppViewModel = appViewModel
  private readonly dialogController: promptAction.DialogController = new promptAction.DialogController()

  private startPreview(attachment: VaultAttachmentMeta): void {
    this.presentReauth($r('app.string.preview_reauth_message'), $r('app.string.preview_reauth_confirm'), () => {
      previewAttachment(this.getUIContext(), attachment.name,
        () => this.app.readAttachment(this.entryUuid, attachment.name))
    })
  }

  private startExport(attachment: VaultAttachmentMeta): void {
    this.presentReauth($r('app.string.reauthenticate_message'), $r('app.string.reauthenticate_confirm'), () => {
      exportAttachment(this.getUIContext(), attachment.name,
        () => this.app.readAttachment(this.entryUuid, attachment.name))
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

  build() {
    Column({ space: $r('sys.float.padding_level8') }) {
      ForEach(this.attachments, (attachment: VaultAttachmentMeta) => {
        AttachmentCard({
          name: attachment.name,
          fileSize: attachment.size,
          showBadge: false,
          onPreview: () => this.startPreview(attachment),
          onExport: () => this.startExport(attachment),
        })
      }, (attachment: VaultAttachmentMeta) => attachment.name)
    }
    .width('100%')
  }
}
