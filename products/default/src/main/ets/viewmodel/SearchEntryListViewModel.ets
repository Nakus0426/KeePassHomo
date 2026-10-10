import { VaultEntry } from '@ohos/common'
import { stageOneVaultStore, VaultBrowseMode } from '../model/StageOneVaultStore'
import { appViewModel } from './AppViewModel'
import { EntryRowModel } from './HomeEntryListViewModel'

// 搜索页列表 ViewModel（页面内实例）：固定全库「全部条目」语义，不跟随首页的浏览模式与分组筛选。
@ObservedV2
export class SearchEntryListViewModel {
  @Trace query: string = ''
  @Trace rows: EntryRowModel[] = []

  setQuery(value: string): void {
    this.query = value
    this.refresh()
  }

  // 锁定与前景超时可能同时发生：锁定态读文档会抛错，判空守卫与首页 ViewModel 同款。
  refresh(): void {
    if (stageOneVaultStore.locked) {
      this.rows = []
      return
    }
    this.rows = stageOneVaultStore.browse(this.query, VaultBrowseMode.All, [])
      .map((entry: VaultEntry): EntryRowModel => {
        return new EntryRowModel(entry, entry.hasAvatar ? stageOneVaultStore.loadEntryAvatar(entry.uuid) : undefined)
      })
  }

  // 落盘与错误上报都归 AppViewModel：星标刷新靠 revision 变化驱动重建。
  toggleFavorite(uuid: string): void {
    appViewModel.toggleFavorite(uuid)
  }
}
