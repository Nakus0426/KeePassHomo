import { VaultEntry, VaultGroup } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { stageOneVaultStore, VaultBrowseMode } from '../model/StageOneVaultStore'

const GROUP_LABEL_MAX_CHARS: number = 10

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
  // 批量选择属于首页界面状态，但标题栏与页面都要渲染，故由 ViewModel 统一持有。
  @Trace batchMode: boolean = false
  @Trace selectedUuids: string[] = []
  // 首页滚动时底部页签与新建按钮的显隐；AppShell 与页面共用同一份状态。
  @Trace chromeHidden: boolean = false
  private readonly selectedLookup: Set<string> = new Set()

  setSearchQuery(value: string): void {
    this.searchQuery = value
    this.rebuild()
  }

  setBrowseMode(mode: VaultBrowseMode): void {
    this.browseMode = mode
    this.rebuild()
  }

  @Computed
  get isAllMode(): boolean {
    return this.browseMode === VaultBrowseMode.All
  }

  @Computed
  get isFavoritesMode(): boolean {
    return this.browseMode === VaultBrowseMode.Favorites
  }

  @Computed
  get isArchivedMode(): boolean {
    return this.browseMode === VaultBrowseMode.Archived
  }

  @Computed
  get browseIndex(): number {
    if (this.browseMode === VaultBrowseMode.Favorites) {
      return 1
    }
    if (this.browseMode === VaultBrowseMode.Archived) {
      return 2
    }
    return 0
  }

  setBrowseModeAtIndex(index: number): void {
    if (index === 1) {
      this.setBrowseMode(VaultBrowseMode.Favorites)
      return
    }
    if (index === 2) {
      this.setBrowseMode(VaultBrowseMode.Archived)
      return
    }
    this.setBrowseMode(VaultBrowseMode.All)
  }

  // 首页列表滚动方向直接驱动 chrome 显隐：手指上滑隐藏，下滑恢复。
  updateChromeVisibility(scrollOffset: number): void {
    if (scrollOffset > 0 && !this.chromeHidden) {
      this.chromeHidden = true
      return
    }
    if (scrollOffset < 0 && this.chromeHidden) {
      this.chromeHidden = false
    }
  }

  showChrome(): void {
    if (this.chromeHidden) {
      this.chromeHidden = false
    }
  }

  selectedGroupLabel(): string {
    if (stageOneVaultStore.locked || this.selectedGroupUuids.length === 0) {
      return ResUtil.getStringSync($r('app.string.group_filter_all'))
    }
    const groups: VaultGroup[] = stageOneVaultStore.groups()
    const selected: VaultGroup | undefined = groups.find((group: VaultGroup) =>
    group.uuid === this.selectedGroupUuids[0])
    if (selected === undefined || selected.uuid === stageOneVaultStore.defaultGroupUuid()) {
      return ResUtil.getStringSync($r('app.string.group_filter_all'))
    }
    return selected.name.length > GROUP_LABEL_MAX_CHARS
      ? `${selected.name.slice(0, GROUP_LABEL_MAX_CHARS)}…`
      : selected.name
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

  // 收藏只改行模型；仅已收藏筛选需重算快照，其余模式直接同步条目，避免列表重建打断图标形变。
  syncFavorite(entryUuid: string, favorite: boolean): void {
    if (this.browseMode === VaultBrowseMode.Favorites && !favorite) {
      this.invalidate()
      return
    }
    const entry: VaultEntry | undefined = this.entries.find((item: VaultEntry) => item.uuid === entryUuid)
    if (entry !== undefined) {
      entry.favorite = favorite
    }
  }

  enterBatch(uuid: string): void {
    this.chromeHidden = false
    this.batchMode = true
    this.selectedLookup.clear()
    this.selectedLookup.add(uuid)
    this.selectedUuids = [uuid]
  }

  exitBatch(): void {
    this.chromeHidden = false
    this.batchMode = false
    this.selectedLookup.clear()
    this.selectedUuids = []
  }

  toggleSelection(uuid: string): void {
    if (this.selectedLookup.has(uuid)) {
      this.selectedLookup.delete(uuid)
    } else {
      this.selectedLookup.add(uuid)
    }
    this.selectedUuids = Array.from(this.selectedLookup)
  }

  selectAll(uuids: string[]): void {
    this.selectedLookup.clear()
    for (const uuid of uuids) {
      this.selectedLookup.add(uuid)
    }
    this.selectedUuids = Array.from(this.selectedLookup)
  }

  selectAllVisible(): void {
    this.selectAll(this.entries.map((entry: VaultEntry): string => entry.uuid))
  }

  isSelected(uuid: string): boolean {
    // 读取 @Trace 数组建立观察依赖；命中判断走 Set，避免长列表逐行 includes。
    const selected: string[] = this.selectedUuids
    return selected.length > 0 && this.selectedLookup.has(uuid)
  }

  clearFilters(): void {
    this.searchQuery = ''
    this.browseMode = VaultBrowseMode.All
    this.selectedGroupUuids = [stageOneVaultStore.defaultGroupUuid()]
    this.rebuild()
  }

  // 锁定时清空搜索词、选中分组、批量状态与快照：条目标题、用户名不留在内存里。
  clear(): void {
    this.searchQuery = ''
    this.selectedGroupUuids = []
    this.entries = []
    this.hasAnyEntry = false
    this.batchMode = false
    this.selectedUuids = []
    this.chromeHidden = false
    this.selectedLookup.clear()
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
