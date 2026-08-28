import { VaultEntry } from '@ohos/common'
import { stageOneVaultStore, VaultBrowseMode } from '../model/StageOneVaultStore'

/**
 * 保险库浏览域 ViewModel（模块级单例）：搜索词、筛选模式与选中分组
 * 跨导航保留（开发计划 3.3 节：主模块切换保留必要非敏感界面状态），
 * 锁定时由 AppViewModel 调用 clear() 全部清除。
 */
@ObservedV2
export class VaultHomeViewModel {
  @Trace revision: number = 0
  @Trace searchQuery: string = ''
  @Trace browseMode: VaultBrowseMode = VaultBrowseMode.All
  @Trace selectedGroupUuid: string = ''

  setSearchQuery(value: string): void {
    this.searchQuery = value
  }

  setBrowseMode(mode: VaultBrowseMode): void {
    this.browseMode = mode
  }

  selectBrowseGroup(groupUuid: string): void {
    this.selectedGroupUuid = groupUuid
  }

  /**
   * 保险库存储变更后失效派生数据，驱动列表重新取数。
   */
  invalidate(): void {
    this.revision++
  }

  /**
   * 锁定时清空搜索词与选中分组。
   */
  clear(): void {
    this.searchQuery = ''
    this.selectedGroupUuid = ''
  }

  entries(): VaultEntry[] {
    this.revision
    return stageOneVaultStore.entries()
  }

  visibleEntries(): VaultEntry[] {
    this.revision
    return stageOneVaultStore.browse(this.searchQuery, this.browseMode, this.selectedGroupUuid)
  }
}

export const vaultHomeViewModel: VaultHomeViewModel = new VaultHomeViewModel()
