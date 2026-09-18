import { VaultEntry } from '@ohos/common'
import { stageOneVaultStore, VaultBrowseMode } from '../model/StageOneVaultStore'

/**
 * 保险库浏览域 ViewModel（模块级单例）：搜索词、筛选模式与选中分组集合
 * 跨导航保留（开发计划 3.3 节：主模块切换保留必要非敏感界面状态），
 * 锁定时由 AppViewModel 调用 clear() 全部清除。
 */
@ObservedV2
export class VaultHomeViewModel {
  @Trace searchQuery: string = ''
  @Trace browseMode: VaultBrowseMode = VaultBrowseMode.All
  @Trace selectedGroupUuids: string[] = []
  /** 当前筛选条件下的列表快照：列表渲染的唯一数据源。 */
  @Trace entries: VaultEntry[] = []
  /** 库内是否存在条目（不含筛选）：区分「空库」与「筛选无命中」两种空态。 */
  @Trace hasAnyEntry: boolean = false

  setSearchQuery(value: string): void {
    this.searchQuery = value
    this.rebuild()
  }

  setBrowseMode(mode: VaultBrowseMode): void {
    this.browseMode = mode
    this.rebuild()
  }

  /** 覆盖选中分组集合；空集合表示不按分组过滤。 */
  selectBrowseGroups(groupUuids: string[]): void {
    this.selectedGroupUuids = groupUuids
    this.rebuild()
  }

  /**
   * 保险库存储变更后重建快照，列表随之刷新。
   */
  invalidate(): void {
    this.rebuild()
  }

  /**
   * 锁定时清空搜索词、选中分组与快照：条目标题、用户名不留在内存里。
   */
  clear(): void {
    this.searchQuery = ''
    this.selectedGroupUuids = []
    this.entries = []
    this.hasAnyEntry = false
  }

  /**
   * 重建列表快照。browse() 会全量过滤并排序，是一次性 O(n log n) 成本，
   * 因此只在数据或筛选条件变化时执行一次，绝不进入 build() 之类的高频路径。
   * 锁定判断取 store 自己的锁定态：解锁流程里先刷新、后同步界面锁定标志。
   */
  private rebuild(): void {
    if (stageOneVaultStore.locked) {
      this.entries = []
      this.hasAnyEntry = false
      return
    }
    this.entries = stageOneVaultStore.browse(this.searchQuery, this.browseMode, this.selectedGroupUuids)
    this.hasAnyEntry = stageOneVaultStore.entries().length > 0
  }
}

export const vaultHomeViewModel: VaultHomeViewModel = new VaultHomeViewModel()
