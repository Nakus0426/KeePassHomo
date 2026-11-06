import { BusinessError } from '@kit.BasicServicesKit'
import { motion } from '@kit.MultimodalAwarenessKit'
import { VaultEntry } from '@ohos/common'
import { LogUtil } from '@pura/harmony-utils'
import { stageOneVaultStore } from '../model/StageOneVaultStore'
import { vaultHomeViewModel } from './VaultHomeViewModel'
import {
  EntryGroupHeaderModel,
  EntryListItem,
  EntryListItemKind,
  EntryRowModel,
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
  private readonly rowCache: Map<string, EntryRowModel> = new Map()
  private readonly headerCache: Map<string, EntryGroupHeaderModel> = new Map()

  // 快照变化、解锁刷新、条目增删保存后都必须调用，否则列表与快照脱节。
  refresh(): void {
    if (stageOneVaultStore.locked) {
      this.items = []
      this.rowCache.clear()
      this.headerCache.clear()
      return
    }
    this.items = this.buildItems(this.buildRows())
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

  private buildRows(): EntryRowModel[] {
    const rows: EntryRowModel[] = []
    const liveUuids: Set<string> = new Set()
    const appendGroupName: boolean = vaultHomeViewModel.searchQuery.length > 0
    for (const entry of vaultHomeViewModel.entries) {
      liveUuids.add(entry.uuid)
      let row: EntryRowModel | undefined = this.rowCache.get(entry.uuid)
      if (row === undefined) {
        row = new EntryRowModel(entry, appendGroupName)
        this.rowCache.set(entry.uuid, row)
      } else {
        row.update(entry, appendGroupName)
      }
      rows.push(row)
    }
    for (const uuid of Array.from(this.rowCache.keys())) {
      if (!liveUuids.has(uuid)) {
        this.rowCache.delete(uuid)
      }
    }
    return rows
  }

  // 搜索态按设计隐藏分组段头；常规态按文档分组顺序展开为扁平的段头 + 行列表。
  private buildItems(rows: EntryRowModel[]): EntryListItem[] {
    const items: EntryListItem[] = []
    if (vaultHomeViewModel.searchQuery.length > 0) {
      this.headerCache.clear()
      for (const row of rows) {
        items.push(new EntryListItem(`row:${row.uuid}`, EntryListItemKind.Row, undefined, row))
      }
      return items
    }

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
    for (const groupUuid of Array.from(this.headerCache.keys())) {
      if (!liveHeaderKeys.has(groupUuid)) {
        this.headerCache.delete(groupUuid)
      }
    }
    return items
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
      vaultHomeViewModel.invalidate()
      return entry.favorite
    } catch (error) {
      LogUtil.error(`更新收藏状态失败，错误码=${(error as BusinessError).code}`)
      return !favorite
    }
  }
}

export const homeEntryListViewModel: HomeEntryListViewModel = new HomeEntryListViewModel()
