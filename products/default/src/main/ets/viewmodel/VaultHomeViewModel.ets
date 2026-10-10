import { VaultEntry } from '@ohos/common'
import { stageOneVaultStore, VaultBrowseMode } from '../model/StageOneVaultStore'

// 保险库浏览域 ViewModel（模块级单例）：搜索词、筛选模式与选中分组跨导航保留，锁定时由 AppViewModel 调用 clear() 清除。
// 依据开发计划 3.3 节：主模块切换保留必要非敏感界面状态。
@ObservedV2
export class VaultHomeViewModel {
  @Trace searchQuery: string = ''
  @Trace browseMode: VaultBrowseMode = VaultBrowseMode.All
  @Trace selectedGroupUuids: string[] = []
  @Trace entries: VaultEntry[] = []
  // 库内是否存在条目（不含筛选）：区分「空库」与「筛选无命中」两种空态。
  @Trace hasAnyEntry: boolean = false

  setSearchQuery(value: string): void {
    this.searchQuery = value
    this.rebuild()
  }

  setBrowseMode(mode: VaultBrowseMode): void {
    this.browseMode = mode
    this.rebuild()
  }

  // 空集合表示不按分组过滤。
  selectBrowseGroups(groupUuids: string[]): void {
    this.selectedGroupUuids = groupUuids
    this.rebuild()
  }

  // 悬空 uuid 会命中已移入回收站的子树、使分组过滤整体落空，必须随分组删除一起清理。
  dropGroupFilter(groupUuid: string): void {
    if (!this.selectedGroupUuids.includes(groupUuid)) {
      return
    }
    this.selectedGroupUuids = this.selectedGroupUuids
      .filter((uuid: string) => uuid !== groupUuid)
  }

  invalidate(): void {
    this.rebuild()
  }

  // 锁定时清空搜索词、选中分组与快照：条目标题、用户名不留在内存里。
  clear(): void {
    this.searchQuery = ''
    this.selectedGroupUuids = []
    this.entries = []
    this.hasAnyEntry = false
  }

  // 重建快照是全量过滤并排序，只在数据或筛选变化时执行，绝不进入 build() 之类的高频路径。
  // 锁定判断取 store 自己的锁定态：解锁流程里先刷新、后同步界面锁定标志。
  private rebuild(): void {
    if (stageOneVaultStore.locked) {
      this.entries = []
      this.hasAnyEntry = false
      return
    }
    // 分组筛选恒指向一个真实分组：解锁后默认落在根分组，根子树覆盖全库即「全部分组」。
    if (this.selectedGroupUuids.length === 0) {
      this.selectedGroupUuids = [stageOneVaultStore.defaultGroupUuid()]
    }
    this.entries = stageOneVaultStore.browse(this.searchQuery, this.browseMode, this.selectedGroupUuids)
    this.hasAnyEntry = stageOneVaultStore.entries().length > 0
  }
}

export const vaultHomeViewModel: VaultHomeViewModel = new VaultHomeViewModel()
