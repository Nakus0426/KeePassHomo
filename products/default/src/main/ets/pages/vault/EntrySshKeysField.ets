import { common } from '@kit.AbilityKit'
import { LengthMetrics, promptAction } from '@kit.ArkUI'
import { BusinessError, pasteboard } from '@kit.BasicServicesKit'
import { picker } from '@kit.CoreFileKit'
import { inspectSshPrivateKey, SshKeyAlgorithm, SshKeyInspection } from '@ohos/common'
import { FileUtil, LogUtil, ResUtil } from '@pura/harmony-utils'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { EntryEditorViewModel } from '../../viewmodel/EntryEditorViewModel'
import { SshKeyDraft } from '../../model/SshKeyPayload'
import { exportSshPrivateKey } from '../../model/SshKeyExport'
import { SshKeyCard } from './SshKeyCard'
import { isPasteboardReadGranted, requestPasteboardRead } from '../../model/PasteboardAccess'
import { SshKeyGeneratorSheet } from './SshKeyGeneratorSheet'
import { DsButton, DsButtonTone, DsButtonVariant } from '../../components/DsButton'
import { DsContextMenu } from '../../components/DsContextMenu'
import { DsDialog, DsDialogTone, dsDialogOptions } from '../../components/DsDialog'
import { DsField } from '../../components/DsField'
import { DsInput, DsInputTone } from '../../components/DsInput'
import { DsListRowMotion, playRowLeave } from '../../components/DsListRowMotion'
import { LIST_ROW_PUSH_IN } from '../../components/ListRowEnterTransition'
import { DsMenuItem } from '../../components/DsMenuItem'
import { DsNotice, DsNoticeTone } from '../../components/DsNotice'
import { DsToastHost } from '../../components/DsToast'
import { copyEntryValue } from './EntryClipboardActions'
import { dsSheetOptions } from '../../components/DsSheetOptions'
import { pickFiles, UserCancelledError } from '../../model/DocumentPicker'

// 单条密钥文本上限：PEM 最大档 RSA8192 也远小于此值，用于拦住误粘贴的大文件。
const SSH_KEY_MAX_BYTES: number = 64 * 1024
const MENU_TARGET_SPACE: number = 8

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
  // 编辑会话是否仍打开：关闭时动画回调不再写回草稿。
  @Param active: boolean = false
  @Event onActivity: () => void = () => {
  }
  @Local private busy: boolean = false
  // 剪贴板读取只能由粘贴控件本身触发授权，故选中「粘贴」后再单独呈现一次控件。
  @Local private pasteMode: boolean = false
  @Local private generateSheetVisible: boolean = false
  @Local private renameName: string = ''
  @Local private renameError: ResourceStr | undefined = undefined
  private renameTarget: SshKeyDraft | undefined = undefined
  private removeTarget: SshKeyDraft | undefined = undefined
  // 正在离场的密钥：卡片据此收高倒塌，动画结束后才删数据。
  @Local private removingKeyId: number = -1
  private readonly app: AppViewModel = appViewModel
  private readonly dialogController: promptAction.DialogController = new promptAction.DialogController()
  private readonly renameDialogController: promptAction.DialogController = new promptAction.DialogController()

  @Computed
  private get keys(): SshKeyDraft[] {
    return this.editor.sshKeys
  }

  @Computed
  private get menuOptions(): MenuOptions {
    return {
      placement: Placement.BottomLeft,
      targetSpace: LengthMetrics.vp(MENU_TARGET_SPACE),
      borderRadius: $r('app.float.ds_radius_none'),
      backgroundColor: $r('app.color.ds_surface_lowest'),
      backgroundBlurStyle: BlurStyle.NONE,
      mask: {
        color: $r('app.color.ds_scrim'),
        backgroundBlurStyle: BlurStyle.NONE,
      },
    }
  }

  private copy(value: string): void {
    copyEntryValue(this.getUIContext(), this.app, value)
  }

  private async pickKeyFile(): Promise<void> {
    this.busy = true
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions()
      options.maxSelectNumber = 1
      options.selectMode = picker.DocumentSelectMode.FILE
      const uris: string[] = await pickFiles(context, options)
      this.addKey(FileUtil.getFileName(uris[0]), await FileUtil.readText(uris[0]))
    } catch (error) {
      if (error instanceof UserCancelledError) {
        return
      }
      const failure: BusinessError = error as BusinessError
      LogUtil.error(`读取 SSH 密钥文件失败，错误码=${failure.code}，错误信息=${failure.message}`)
      DsToastHost.show(this.getUIContext(), $r('app.string.ssh_key_pick_failed'))
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
      DsToastHost.show(this.getUIContext(),
        ResUtil.getStringSync($r('app.string.ssh_key_limit_exceeded'))
          .replace('%s', FileUtil.getFormatFileSize(SSH_KEY_MAX_BYTES)))
      return
    }
    const inspection: SshKeyInspection | undefined = inspectSshPrivateKey(content)
    if (inspection === undefined) {
      DsToastHost.show(this.getUIContext(), $r('app.string.ssh_key_inspect_failed'))
      return
    }
    this.editor.addSshKey(sshKeyFileName(sourceName, inspection), content,
      inspection.publicKey, inspection.algorithm, inspection.bits)
    this.pasteMode = false
    DsToastHost.show(this.getUIContext(), $r('app.string.ssh_key_added'))
    this.onActivity()
  }

  private readClipboard(): void {
    pasteboard.getSystemPasteboard().getData((error: BusinessError, data: pasteboard.PasteData) => {
      if (error) {
        LogUtil.error(`读取剪贴板失败，错误码=${error.code}，错误信息=${error.message}`)
        DsToastHost.show(this.getUIContext(), $r('app.string.ssh_key_paste_failed'))
        return
      }
      // 剪贴板没有文本记录时 getPrimaryText 运行期返回 undefined，类型声明未体现。
      const text: string | undefined = data.getPrimaryText() as string | undefined
      if (text === undefined || text.trim().length === 0) {
        DsToastHost.show(this.getUIContext(), $r('app.string.ssh_key_paste_empty'))
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
      DsToastHost.show(this.getUIContext(), $r('app.string.ssh_key_paste_failed'))
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
        DsToastHost.show(this.getUIContext(), $r('app.string.ssh_key_generated'))
        this.onActivity()
        return
      }
      DsToastHost.show(this.getUIContext(), $r('app.string.ssh_key_generate_failed'))
    }).finally(() => this.busy = false)
  }

  private openRenameDialog(key: SshKeyDraft): void {
    this.renameTarget = key
    this.renameName = key.name
    this.renameError = undefined
    this.getUIContext()
      .getPromptAction()
      .presentCustomDialog(() => this.renameDialog(), this.renameDialogController, dsDialogOptions())
      .catch((error: BusinessError) => {
        LogUtil.error(`打开重命名弹窗失败，错误码=${error.code}，错误信息=${error.message}`)
      })
  }

  private validateKeyName(name: string): ResourceStr | undefined {
    if (name.length === 0) {
      return $r('app.string.ssh_key_name_required')
    }
    const target: SshKeyDraft | undefined = this.renameTarget
    if (target !== undefined && name !== target.name && this.editor.sshKeyNameTaken(name, target)) {
      return $r('app.string.ssh_key_name_duplicate')
    }
    return undefined
  }

  private applyRenameName(value: string): void {
    this.renameName = value
    if (this.renameError !== undefined) {
      this.renameError = this.validateKeyName(value.trim())
    }
  }

  private submitRename(): void {
    const target: SshKeyDraft | undefined = this.renameTarget
    if (target === undefined) {
      return
    }
    const name: string = this.renameName.trim()
    const error: ResourceStr | undefined = this.validateKeyName(name)
    this.renameError = error
    if (error !== undefined) {
      return
    }
    this.renameDialogController.close()
    this.editor.renameSshKey(target, name)
    this.renameTarget = undefined
    this.onActivity()
  }

  // 与自定义字段卡同一套离场：先在原位收高倒塌，动画结束后才删数据。
  private removeKey(key: SshKeyDraft): void {
    if (this.removingKeyId !== -1) {
      return
    }
    playRowLeave(this.getUIContext(), this.active, () => this.removingKeyId = key.id, () => {
      this.editor.removeSshKey(key)
      this.onActivity()
      this.removingKeyId = -1
    })
  }

  // 新建条目还没有 uuid，待保存密钥直接删除；编辑已有条目才走确认。
  private confirmRemove(key: SshKeyDraft): void {
    if (this.editor.entryUuid.length === 0) {
      this.removeKey(key)
      return
    }
    this.removeTarget = key
    this.getUIContext()
      .getPromptAction()
      .presentCustomDialog(() => this.deleteDialog(), this.dialogController, dsDialogOptions())
  }

  @Builder
  private deleteDialog() {
    DsDialog({
      title: $r('app.string.ssh_key_remove'),
      message: $r('app.string.ssh_key_remove_message'),
      icon: $r('app.string.symbol_delete'),
      tone: DsDialogTone.Error,
      cancelLabel: $r('app.string.cancel'),
      confirmLabel: $r('app.string.ssh_key_remove'),
      onCancel: () => {
        this.dialogController.close()
        this.removeTarget = undefined
      },
      onConfirm: () => {
        this.dialogController.close()
        const target: SshKeyDraft | undefined = this.removeTarget
        this.removeTarget = undefined
        if (target !== undefined) {
          this.removeKey(target)
        }
      },
    })
  }

  @LocalBuilder
  private addMenuHeader() {
    Column() {
      Text($r('app.string.ssh_add_menu_title'))
        .fontSize($r('app.float.ds_font_body'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))
    }
    .width('100%')
    .padding({
      top: $r('app.float.ds_space_md'),
      bottom: $r('app.float.ds_space_md'),
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
    })
    .backgroundColor($r('app.color.ds_surface_low'))
    .alignItems(HorizontalAlign.Start)
  }

  @LocalBuilder
  private addMenuItems() {
    DsMenuItem({
      icon: $r('app.string.symbol_upload_file'),
      label: $r('app.string.ssh_key_pick_file'),
      onAction: () => this.pickKeyFile(),
    })
    DsMenuItem({
      icon: $r('app.string.symbol_copy'),
      label: $r('app.string.ssh_key_paste'),
      onAction: () => this.startPaste(),
    })
    DsMenuItem({
      icon: $r('app.string.symbol_generate'),
      label: $r('app.string.ssh_key_generate'),
      onAction: () => this.generateSheetVisible = true,
    })
  }

  @LocalBuilder
  private addMenu() {
    DsContextMenu({
      header: this.addMenuHeader,
      content: this.addMenuItems,
    })
  }

  @LocalBuilder
  private renameInputField() {
    DsInput({
      text: this.renameName,
      placeholder: $r('app.string.ssh_key_name_placeholder'),
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
      title: $r('app.string.ssh_key_rename'),
      message: $r('app.string.ssh_key_rename_message'),
      cancelLabel: $r('app.string.cancel'),
      confirmLabel: $r('app.string.save'),
      contentBuilder: this.renameInput,
      onCancel: () => this.renameDialogController.close(),
      onConfirm: () => this.submitRename(),
    })
  }

  // 粘贴控件必须由用户直接点击才能拿到剪贴板临时授权，故独立成一块而不是菜单项。
  @Builder
  private pasteRow() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      Column({ space: $r('app.float.ds_space_2') }) {
        Text($r('app.string.ssh_key_paste_action'))
          .width('100%')
          .fontSize($r('app.float.ds_font_body'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ds_text_primary'))

        Text($r('app.string.ssh_key_paste_reason'))
          .width('100%')
          .fontSize($r('app.float.ds_font_body_sm'))
          .fontColor($r('app.color.ds_text_secondary'))
          .maxLines(2)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Row() {
        PasteButton({ text: PasteDescription.PASTE, buttonType: ButtonType.Normal })
          .fontSize($r('app.float.ds_font_body_sm'))
          .backgroundColor($r('app.color.ds_surface_high'))
          .fontColor($r('app.color.ds_text_primary'))
          .borderRadius($r('app.float.ds_radius_none'))
          .onClick((_event: ClickEvent, result: PasteButtonOnClickResult) => this.pasteFromClipboard(result))
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .padding($r('app.float.ds_space_md'))
    .backgroundColor($r('app.color.ds_surface_low'))
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
      if (this.keys.length === 0) {
        DsNotice({
          tone: DsNoticeTone.Default,
          title: $r('app.string.ssh_key_empty_title'),
          body: $r('app.string.ssh_key_empty_body'),
        })
      }

      ForEach(this.keys, (key: SshKeyDraft) => {
        DsListRowMotion({
          leaving: key.id === this.removingKeyId,
          enterTransition: LIST_ROW_PUSH_IN,
        }) {
          SshKeyCard({
            sshKey: key,
            editable: !this.readOnly,
            onCopyPrivate: () => this.copy(key.privateKey),
            onCopyPublic: () => this.copy(key.publicKey),
            onExport: () => exportSshPrivateKey(this.getUIContext(), key),
            onRename: () => this.openRenameDialog(key),
            onRemove: () => this.confirmRemove(key),
          })
        }
      }, (key: SshKeyDraft) => `${key.id}`)

      if (!this.readOnly) {
        if (this.pasteMode) {
          this.pasteRow()
        }
        DsButton({
          label: $r('app.string.ssh_key_add'),
          variant: DsButtonVariant.Dashed,
          tone: DsButtonTone.Default,
          leadingIcon: $r('app.string.symbol_add'),
          loading: this.busy,
          fullWidth: true,
          menuBuilder: this.addMenu,
          menuOptions: this.menuOptions,
          onTap: () => {
          },
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .bindSheet($$this.generateSheetVisible, this.generateSheet(), dsSheetOptions({
      detents: [SheetSize.MEDIUM],
      onDisappear: () => this.generateSheetVisible = false,
    }))
  }
}
