import { DsDialog, DsDialogTone } from '../../components/DsDialog'

// 单条与批量删除共用同一确认弹窗：只有文案随目标数量切换。
@ComponentV2
export struct EntryDeleteDialog {
  @Param batch: boolean = false
  @Event onCancel: () => void = () => {
  }
  @Event onConfirm: () => void = () => {
  }

  build() {
    DsDialog({
      title: this.batch
        ? $r('app.string.entry_batch_delete_title')
        : $r('app.string.delete_entry_title'),
      message: this.batch
        ? $r('app.string.entry_batch_delete_message')
        : $r('app.string.delete_entry_message'),
      icon: $r('app.string.symbol_delete'),
      tone: DsDialogTone.Error,
      cancelLabel: $r('app.string.cancel'),
      confirmLabel: this.batch ? $r('app.string.entry_batch_delete') : $r('app.string.delete_entry'),
      onCancel: () => this.onCancel(),
      onConfirm: () => this.onConfirm(),
    })
  }
}
