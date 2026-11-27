import { BusinessError } from '@kit.BasicServicesKit'
import { motion } from '@kit.MultimodalAwarenessKit'
import { VaultEntry } from '@ohos/common'
import { LogUtil, ResUtil } from '@pura/harmony-utils'
import { stageOneVaultStore, VaultSearchMatch } from '../model/StageOneVaultStore'
import { vaultHomeViewModel } from './VaultHomeViewModel'
import {
  EntryGroupHeaderModel,
  EntryListItem,
  EntryListItemKind,
  EntryRowModel,
  EntrySearchSectionModel,
} from './EntryRowModel'

// 首页条目列表 ViewModel（模块级单例）：列表项和分组段的唯一来源，组件侧不持有业务逻辑。
@ObservedV2
export class HomeEntryListViewModel {
  // 整体替换列表项；行模型与段头模型跨刷新复用，@Trace 字段负责局部更新。
  @Trace items: EntryListItem[] = []
  // 悬浮按钮贴右还是贴左：跟随握持手，初始与设备不支持智感握姿时固定贴右。
  @Trace fabRight: boolean = true
  // 握持手回调需要固定引用，退订时才能配对。
  private readonly onHoldingHandChanged: (status: motion.HoldingHandStatus) => void =
    (status: motion.HoldingHandStatus) => this.applyHoldingHand(status)
  private handListening: boolean = false
  private appendGroupName: boolean = false
  private lastRevision: number = -1
  private readonly rowCache: Map<string, EntryRowModel> = new Map()
  private readonly headerCache: Map<string, EntryGroupHeaderModel> = new Map()
  private readonly sectionCache: Map<string, EntrySearchSectionModel> = new Map()

  // 快照变化、解锁刷新、条目增删保存后都必须调用，否则列表与快照脱节。
  refresh(): void {
    if (stageOneVaultStore.locked) {
      this.items = []
      this.rowCache.clear()
      this.headerCache.clear()
      this.sectionCache.clear()
      this.appendGroupName = false
      this.lastRevision = -1
      return
    }
    // 数据变化后清掉已删除条目的行模型；筛选切换版本不变，整张缓存继续复用。
    const revision: number = vaultHomeViewModel.dataRevision
    if (revision !== this.lastRevision) {
      this.lastRevision = revision
      this.pruneRows()
    }
    const appendGroupName: boolean = vaultHomeViewModel.isSearching
    // 行内容只在数据版本变化或进出搜索（副标题带分组名）时重算。
    const refreshRows: boolean = appendGroupName !== this.appendGroupName
    this.appendGroupName = appendGroupName
    this.items = this.buildItems(this.buildRows(refreshRows, appendGroupName, this.buildMatchTags()))
  }

  // 命中标签由分区快照带回，列表只做合并，不再重扫标签。
  private buildMatchTags(): Map<string, string> {
    const matchTags: Map<string, string> = new Map()
    for (const section of vaultHomeViewModel.searchSections) {
      for (const pair of section.matchedTags) {
        matchTags.set(pair[0], pair[1])
      }
    }
    return matchTags
  }

  private pruneRows(): void {
    const live: Set<string> = stageOneVaultStore.entryUuids()
    for (const uuid of this.rowCache.keys()) {
      if (!live.has(uuid)) {
        this.rowCache.delete(uuid)
      }
    }
  }

  // 新快照里已不存在的行与分组头：页面先对它们播离场动画，动画结束再 refresh 移除。
  leavingItems(): EntryListItem[] {
    const liveRows: Set<string> = new Set()
    const liveGroups: Set<string> = new Set()
    for (const entry of vaultHomeViewModel.entries) {
      liveRows.add(entry.uuid)
      liveGroups.add(entry.groupUuid)
    }
    const liveSections: Set<string> = new Set()
    for (const section of vaultHomeViewModel.searchSections) {
      liveSections.add(`section:${section.match}`)
    }
    const leaving: EntryListItem[] = []
    for (const item of this.items) {
      if (item.kind === EntryListItemKind.Row) {
        if (!liveRows.has(item.row!.uuid)) {
          leaving.push(item)
        }
        continue
      }
      if (item.kind === EntryListItemKind.Header && !liveGroups.has(item.header!.groupUuid)) {
        leaving.push(item)
        continue
      }
      if (item.kind === EntryListItemKind.Section && !liveSections.has(item.section!.key)) {
        leaving.push(item)
      }
    }
    return leaving
  }

  // 先乐观更新行模型让图标立即响应，再落盘。
  toggleFavorite(uuid: string): void {
    const row: EntryRowModel | undefined = this.rowCache.get(uuid)
    if (row === undefined) {
      return
    }
    const previous: boolean = row.favorite
    row.setFavorite(!previous)
    this.persistFavorite(uuid, !previous).then((applied: boolean) => {
      this.rowCache.get(uuid)?.setFavorite(applied)
    })
  }

  subscribeHoldingHand(): void {
    if (!canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      LogUtil.info('当前设备不支持动作感知，新增条目悬浮按钮固定贴右')
      return
    }
    try {
      motion.on('holdingHandChanged', this.onHoldingHandChanged)
      this.handListening = true
    } catch (error) {
      // 801 机型不支持智感握姿、201 缺权限：都保持贴右默认位置，不打扰用户。
      LogUtil.warn(`订阅握持手失败，新增条目悬浮按钮固定贴右，错误码=${(error as BusinessError).code}`)
    }
  }

  unsubscribeHoldingHand(): void {
    if (!this.handListening) {
      return
    }
    this.handListening = false
    try {
      motion.off('holdingHandChanged', this.onHoldingHandChanged)
    } catch (error) {
      LogUtil.warn(`取消握持手订阅失败，错误码=${(error as BusinessError).code}`)
    }
  }

  private buildRows(refreshRows: boolean, appendGroupName: boolean,
    matchTags: Map<string, string>): EntryRowModel[] {
    const rows: EntryRowModel[] = []
    const revision: number = vaultHomeViewModel.dataRevision
    for (const entry of vaultHomeViewModel.entries) {
      let row: EntryRowModel | undefined = this.rowCache.get(entry.uuid)
      if (row === undefined) {
        row = new EntryRowModel(entry, appendGroupName)
        this.rowCache.set(entry.uuid, row)
      } else if (refreshRows || row.revision !== revision) {
        row.update(entry, appendGroupName)
      } else if (row.leaving) {
        // 行模型跨筛选保留，离场态要先复位，否则重新进入列表时会保持零高度。
        row.leaving = false
      }
      row.setMatchTag(matchTags.get(entry.uuid) ?? '')
      row.revision = revision
      rows.push(row)
    }
    return rows
  }

  // 搜索态按 标题 / 标签 / 分组 / 内容 分段；常规态按文档分组顺序展开为扁平的段头 + 行列表。
  private buildItems(rows: EntryRowModel[]): EntryListItem[] {
    const items: EntryListItem[] = []
    if (vaultHomeViewModel.isSearching) {
      const liveKeys: Set<string> = new Set()
      for (const section of vaultHomeViewModel.searchSections) {
        const key: string = `section:${section.match}`
        liveKeys.add(key)
        let header: EntrySearchSectionModel | undefined = this.sectionCache.get(key)
        if (header === undefined) {
          header = new EntrySearchSectionModel(key)
          this.sectionCache.set(key, header)
        }
        header.update(this.sectionName(section.match), section.entries.length)
        items.push(new EntryListItem(`sectionheader:${key}`, EntryListItemKind.Section, undefined, undefined, header))
        for (const entry of section.entries) {
          const row: EntryRowModel | undefined = this.rowCache.get(entry.uuid)
          if (row !== undefined) {
            items.push(new EntryListItem(`row:${row.uuid}`, EntryListItemKind.Row, undefined, row))
          }
        }
      }
      for (const cachedKey of this.sectionCache.keys()) {
        if (!liveKeys.has(cachedKey)) {
          this.sectionCache.delete(cachedKey)
        }
      }
      this.headerCache.clear()
      return items
    }
    this.sectionCache.clear()

    const rowsByGroup: Map<string, EntryRowModel[]> = new Map()
    for (const row of rows) {
      const groupRows: EntryRowModel[] | undefined = rowsByGroup.get(row.groupUuid)
      if (groupRows === undefined) {
        rowsByGroup.set(row.groupUuid, [row])
      } else {
        groupRows.push(row)
      }
    }

    const liveHeaderKeys: Set<string> = new Set()
    for (const group of stageOneVaultStore.groups()) {
      const groupRows: EntryRowModel[] = rowsByGroup.get(group.uuid) ?? []
      if (groupRows.length === 0) {
        continue
      }
      liveHeaderKeys.add(group.uuid)
      let header: EntryGroupHeaderModel | undefined = this.headerCache.get(group.uuid)
      if (header === undefined) {
        header = new EntryGroupHeaderModel(group.uuid)
        this.headerCache.set(group.uuid, header)
      }
      header.update(group.name, groupRows.length)
      items.push(new EntryListItem(`header:${group.uuid}`, EntryListItemKind.Header, header))
      for (const row of groupRows) {
        items.push(new EntryListItem(`row:${row.uuid}`, EntryListItemKind.Row, undefined, row))
      }
    }
    for (const groupUuid of this.headerCache.keys()) {
      if (!liveHeaderKeys.has(groupUuid)) {
        this.headerCache.delete(groupUuid)
      }
    }
    return items
  }

  private sectionName(match: VaultSearchMatch): string {
    switch (match) {
      case VaultSearchMatch.Tag:
        return ResUtil.getStringSync($r('app.string.entry_search_section_tag'))
      case VaultSearchMatch.Group:
        return ResUtil.getStringSync($r('app.string.entry_search_section_group'))
      case VaultSearchMatch.Body:
        return ResUtil.getStringSync($r('app.string.entry_search_section_body'))
      default:
        return ResUtil.getStringSync($r('app.string.entry_search_section_title'))
    }
  }

  // 只有明确的左/右手握持才翻转，其余状态保持当前侧，避免识别抖动让按钮来回跳。
  private applyHoldingHand(status: motion.HoldingHandStatus): void {
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
      this.switchFabSide(false)
      return
    }
    if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) {
      this.switchFabSide(true)
    }
  }

  private switchFabSide(right: boolean): void {
    if (this.fabRight !== right) {
      this.fabRight = right
    }
  }

  private async persistFavorite(uuid: string, favorite: boolean): Promise<boolean> {
    try {
      const entry: VaultEntry = await stageOneVaultStore.setFavorite(uuid, favorite)
      vaultHomeViewModel.syncFavorite(uuid, entry.favorite)
      return entry.favorite
    } catch (error) {
      LogUtil.error(`更新收藏状态失败，错误码=${(error as BusinessError).code}`)
      return !favorite
    }
  }
}

export const homeEntryListViewModel: HomeEntryListViewModel = new HomeEntryListViewModel()
