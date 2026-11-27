import { VaultEntry } from '@ohos/common'
import {
  stageOneVaultStore,
  VaultBrowseMode,
  VaultSearchSection,
  VaultSortField,
  VaultTagOption,
} from '../model/StageOneVaultStore'

// 搜索逐字符输入合并成一次全库过滤；清空立即生效，避免列表残留旧结果。
const SEARCH_DEBOUNCE_MS: number = 180

// 快照变化来源：搜索逐字符刷新，不播列表动画；其余变化播行进场/离场。
export enum HomeSnapshotCause {
  Search = 'search',
  Data = 'data',
}

// 保险库浏览域 ViewModel（模块级单例）：搜索词、筛选模式与选中分组跨导航保留，锁定时由 AppViewModel 调用 clear() 清除。
// 依据开发计划 3.3 节：主模块切换保留必要非敏感界面状态。
@ObservedV2
export class VaultHomeViewModel {
  @Trace searchQuery: string = ''
  @Trace browseMode: VaultBrowseMode = VaultBrowseMode.All
  @Trace selectedGroupUuids: string[] = []
  @Trace selectedTags: string[] = []
  @Trace sortField: VaultSortField = VaultSortField.Title
  // 非搜索态的浏览结果；搜索态的条目由 searchSections 派生。
  @Trace private browseEntries: VaultEntry[] = []
  // 搜索态的分区快照；非搜索为空。条目顺序即列表渲染顺序。
  @Trace searchSections: VaultSearchSection[] = []

  // 列表、批量选择与离场判断都读同一份快照；搜索态由分区派生，不再另存一份扁平数组。
  @Computed
  get entries(): VaultEntry[] {
    if (!this.isSearching) {
      return this.browseEntries
    }
    const flattened: VaultEntry[] = []
    for (const section of this.searchSections) {
      flattened.push(...section.entries)
    }
    return flattened
  }

  @Computed
  get isSearching(): boolean {
    return this.searchQuery.length > 0
  }

  // 查询的归一化只在这里做一次：分区、行内高亮与标签匹配共用。
  @Computed
  get normalizedQuery(): string {
    return this.searchQuery.trim().toLocaleLowerCase()
  }
  // 库内是否存在条目（不含筛选）：区分「空库」与「筛选无命中」两种空态。
  @Trace hasAnyEntry: boolean = false
  // 批量选择属于首页界面状态，但标题栏与页面都要渲染，故由 ViewModel 统一持有。
  @Trace batchMode: boolean = false
  @Trace selectedUuids: string[] = []
  // 首页滚动时底部页签与新建按钮的显隐；AppShell 与页面共用同一份状态。
  @Trace chromeHidden: boolean = false
  // 页面在 @Monitor 里按原因分派，不参与渲染，故不加 @Trace。
  snapshotCause: HomeSnapshotCause = HomeSnapshotCause.Data
  // 条目数据版本：仅数据变化时递增，筛选切换不变，行模型据此判断是否需要重算。
  dataRevision: number = 0
  private readonly selectedLookup: Set<string> = new Set()
  private searchTimer: number = -1

  setSearchQuery(value: string): void {
    if (value === this.searchQuery) {
      return
    }
    this.searchQuery = value
    this.snapshotCause = HomeSnapshotCause.Search
    if (value.length === 0) {
      this.rebuild()
      return
    }
    clearTimeout(this.searchTimer)
    this.searchTimer = setTimeout(() => this.rebuild(), SEARCH_DEBOUNCE_MS)
  }

  setBrowseMode(mode: VaultBrowseMode): void {
    this.browseMode = mode
    this.snapshotCause = HomeSnapshotCause.Data
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

  setSortField(field: VaultSortField): void {
    if (this.sortField === field) {
      return
    }
    this.sortField = field
    this.snapshotCause = HomeSnapshotCause.Data
    this.rebuild()
  }

  setSelectedTags(tags: string[]): void {
    if (tags.length === this.selectedTags.length && tags.every((tag: string) => this.selectedTags.includes(tag))) {
      return
    }
    this.selectedTags = tags
    this.snapshotCause = HomeSnapshotCause.Data
    this.rebuild()
  }

  @Computed
  get isTagFiltering(): boolean {
    return this.selectedTags.length > 0
  }

  @Computed
  get isGroupFiltering(): boolean {
    return this.selectedGroupUuids.length > 0 && this.selectedGroupUuids[0] !== stageOneVaultStore.defaultGroupUuid()
  }

  tagOptions(): VaultTagOption[] {
    return stageOneVaultStore.tagOptions()
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

  // 空集合表示不按分组过滤。
  selectBrowseGroups(groupUuids: string[]): void {
    this.selectedGroupUuids = groupUuids
    this.snapshotCause = HomeSnapshotCause.Data
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
    this.snapshotCause = HomeSnapshotCause.Data
    this.dataRevision++
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
    this.selectedTags = []
    this.sortField = VaultSortField.Title
    this.snapshotCause = HomeSnapshotCause.Data
    this.rebuild()
  }

  // 锁定时清空搜索词、选中分组、批量状态与快照：条目标题、用户名不留在内存里。
  clear(): void {
    clearTimeout(this.searchTimer)
    this.searchTimer = -1
    this.searchQuery = ''
    this.selectedGroupUuids = []
    this.selectedTags = []
    this.sortField = VaultSortField.Title
    this.browseEntries = []
    this.searchSections = []
    this.hasAnyEntry = false
    this.batchMode = false
    this.selectedUuids = []
    this.chromeHidden = false
    this.selectedLookup.clear()
    this.dataRevision++
  }

  // 重建快照是全量过滤并排序，只在数据或筛选变化时执行，绝不进入 build() 之类的高频路径。
  // 锁定判断取 store 自己的锁定态：解锁流程里先刷新、后同步界面锁定标志。
  private rebuild(): void {
    clearTimeout(this.searchTimer)
    this.searchTimer = -1
    if (stageOneVaultStore.locked) {
      this.browseEntries = []
      this.searchSections = []
      this.hasAnyEntry = false
      return
    }
    // 分组筛选恒指向一个真实分组：解锁后默认落在根分组，根子树覆盖全库即「全部分组」。
    if (this.selectedGroupUuids.length === 0) {
      this.selectedGroupUuids = [stageOneVaultStore.defaultGroupUuid()]
    }
    if (this.isSearching) {
      this.searchSections = stageOneVaultStore.searchSections(this.searchQuery, this.browseMode,
        this.selectedGroupUuids, this.selectedTags, this.sortField)
      this.browseEntries = []
    } else {
      this.searchSections = []
      this.browseEntries = stageOneVaultStore.browse(this.searchQuery, this.browseMode, this.selectedGroupUuids,
        this.selectedTags, this.sortField)
    }
    this.hasAnyEntry = stageOneVaultStore.hasEntries()
  }
}

export const vaultHomeViewModel: VaultHomeViewModel = new VaultHomeViewModel()
