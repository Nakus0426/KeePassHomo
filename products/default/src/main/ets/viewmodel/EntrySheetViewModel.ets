import { VaultEntry, VaultField } from '@ohos/common'
import { stageOneVaultStore } from '../model/StageOneVaultStore'
import { AppViewModel, appViewModel } from './AppViewModel'

// 半模态形态：预览态只看与取值，编辑态改草稿。
export enum EntrySheetMode {
  Preview = 'preview',
  Edit = 'edit'
}

// 半模态的唯一状态源：列表只发动作，预览体与编辑体只做展示与交互。
// 三个字段各自独立：切换形态不动开合状态，切换条目不动形态。
@ObservedV2
export class EntrySheetViewModel {
  @Trace visible: boolean = false
  @Trace mode: EntrySheetMode = EntrySheetMode.Preview
  // 目标条目 uuid；空串表示新建，没有预览态。
  @Trace entryUuid: string = ''
  // 编辑态退出后是否返回预览：左滑编辑与新建直接收起半模态。
  @Trace editFromPreview: boolean = false
  // 阅读位置随预览体一同被销毁，故与预览数据同放在这里。
  @Trace notesExpanded: boolean = false
  @Trace expandedCustomFields: Set<string> = new Set<string>()
  @Trace previewEntry: VaultEntry | undefined = undefined
  @Trace avatarData: ArrayBuffer | undefined = undefined
  private readonly app: AppViewModel = appViewModel

  @Computed
  get isNewEntry(): boolean {
    return this.entryUuid.length === 0
  }

  @Computed
  get title(): string {
    return this.previewEntry?.title ?? ''
  }

  @Computed
  get groupPath(): string {
    return this.previewEntry?.groupPath ?? ''
  }

  @Computed
  get fields(): VaultField[] {
    return this.previewEntry?.fields ?? []
  }

  @Computed
  get tags(): string[] {
    return this.previewEntry?.tags ?? []
  }

  @Computed
  get favorite(): boolean {
    return this.previewEntry?.favorite ?? false
  }

  // 只读能力属于 AppViewModel，缓存进来会读到旧值。
  get readOnly(): boolean {
    return this.app.currentSource().readOnly
  }

  openNew(): void {
    this.entryUuid = ''
    this.editFromPreview = false
    this.mode = EntrySheetMode.Edit
    this.visible = true
  }

  openPreview(entryUuid: string): void {
    this.entryUuid = entryUuid
    this.editFromPreview = false
    this.mode = EntrySheetMode.Preview
    this.visible = true
    stageOneVaultStore.touch()
  }

  openEdit(entryUuid: string): void {
    this.entryUuid = entryUuid
    this.editFromPreview = false
    this.mode = EntrySheetMode.Edit
    this.visible = true
    stageOneVaultStore.touch()
  }

  // 预览态进入编辑：退出后回预览，而不是收起半模态。
  beginEdit(): void {
    this.editFromPreview = true
    this.mode = EntrySheetMode.Edit
  }

  close(): void {
    this.visible = false
  }

  exitEditor(): void {
    if (this.isNewEntry || !this.editFromPreview) {
      this.visible = false
      return
    }
    this.mode = EntrySheetMode.Preview
  }

  // 收起后复位形态并重建首页快照：列表变更要放在动画上下文里才可见。
  onDismissed(): void {
    this.visible = false
    this.mode = EntrySheetMode.Preview
    this.editFromPreview = false
    this.app.refreshHomeSnapshot()
  }

  // 唯一装载入口：不可见或新建时清空，避免残留上一条的内容。
  load(): void {
    if (!this.visible || this.entryUuid.length === 0) {
      this.previewEntry = undefined
      this.avatarData = undefined
      return
    }
    this.previewEntry = this.app.entry(this.entryUuid)
    this.avatarData = this.app.loadEntryAvatar(this.entryUuid)
  }

  toggleNotesExpanded(): void {
    this.notesExpanded = !this.notesExpanded
  }

  // 整体替换：Set 原地增删不会触发 @Trace 的赋值通知。
  toggleCustomExpanded(name: string): void {
    const next: Set<string> = new Set(this.expandedCustomFields)
    if (next.has(name)) {
      next.delete(name)
    } else {
      next.add(name)
    }
    this.expandedCustomFields = next
  }

  toggleFavorite(): void {
    this.app.toggleFavorite(this.entryUuid)
  }
}

export const entrySheetViewModel: EntrySheetViewModel = new EntrySheetViewModel()
