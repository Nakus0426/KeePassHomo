import { BusinessError } from '@kit.BasicServicesKit'
import { motion } from '@kit.MultimodalAwarenessKit'
import { VaultEntry } from '@ohos/common'
import { LogUtil } from '@pura/harmony-utils'
import { stageOneVaultStore } from '../model/StageOneVaultStore'
import { EntrySheetMode, EntrySheetState } from './EntrySheetState'
import { vaultHomeViewModel } from './VaultHomeViewModel'

/**
 * 列表行的 UI 回调出口：ViewModel 只声明「该做什么」，不持有 UIContext。
 * 每个方法对应一次列表动画帧或一次提示，由页面实现。
 */
/**
 * 列表的 UI 回调出口：ViewModel 只声明「该做什么」，不持有 UIContext。
 * 每个方法对应一次列表动画帧或一次提示，由页面继承并覆写。
 * 用类而非接口承载：ArkTS 不允许用对象字面量实现接口（arkts-no-untyped-obj-literals）。
 */
export class VaultEntryListHost {
  animateRowExit(uuid: string): void {
    throw new Error(`列表动画出口未实现：animateRowExit(${uuid})`)
  }

  refreshSnapshot(): void {
    throw new Error('列表动画出口未实现：refreshSnapshot')
  }

  notifyDeleted(): void {
    throw new Error('列表动画出口未实现：notifyDeleted')
  }

  animateFabSide(right: boolean): void {
    throw new Error(`列表动画出口未实现：animateFabSide(${right})`)
  }
}

/**
 * 列表行模型：把「一次渲染要用的行数据」在一个可观察对象里备齐。
 * 头像与收藏在此解析完成，行组件不再需要 aboutToAppear 去查库 —— 那是官方 FAQ faqs-arkui-609
 * 明确点出的坑（列表项生命周期里做数据加载会因节点复用而出错）。
 */
@ObservedV2
export class EntryRowModel {
  readonly uuid: string
  readonly entry: VaultEntry
  @Trace avatarData: ArrayBuffer | undefined = undefined
  @Trace favorite: boolean = false

  constructor(entry: VaultEntry, avatarData: ArrayBuffer | undefined) {
    this.uuid = entry.uuid
    this.entry = entry
    this.avatarData = avatarData
    this.favorite = entry.favorite
  }

  setFavorite(favorite: boolean): void {
    this.favorite = favorite
  }
}

/**
 * 首页条目列表 ViewModel（模块级单例）：行模型的唯一来源、列表动作的唯一入口。
 * 行组件只消费行模型；头像解析、删除编排、握持手策略都在这里，
 * 组件侧不留业务逻辑（依据 arkts-mvvm-v2：View 只做展示与交互绑定）。
 * 本层不引用 AppViewModel，避免两个 ViewModel 互相依赖。
 */
@ObservedV2
export class HomeEntryListViewModel {
  /**
   * 行模型数组：列表渲染的唯一数据源，与浏览快照一一对应。
   * 只在重建时整体替换，绝不在渲染过程中逐项改动 ——
   * 逐项改动会让复用节点读到半成品。
   */
  @Trace rows: EntryRowModel[] = []
  /** 悬浮按钮贴右还是贴左：跟随握持手，初始与设备不支持智感握姿时固定贴右。 */
  @Trace fabRight: boolean = true
  /** 半模态的开合与形态：列表页是它唯一的持有者。 */
  @Trace sheet: EntrySheetState = new EntrySheetState()
  /** 握持手回调需要固定引用，退订时才能配对。 */
  private readonly onHoldingHandChanged: (status: motion.HoldingHandStatus) => void =
    (status: motion.HoldingHandStatus) => this.applyHoldingHand(status)
  /** 订阅是否生效，决定退订时是否需要调用 off。 */
  private handListening: boolean = false
  /** 翻转动作要落到界面动画上，回调出口由宿主注入。 */
  private host: VaultEntryListHost | undefined = undefined

  /**
   * 按当前浏览快照重建行模型。头像只在这里读一次，行组件不再查库。
   * 快照变化、解锁刷新、条目增删保存后都必须调用，
   * 否则列表与快照脱节 —— 判空与渲染都读这里，脱节会让列表整片消失。
   */
  refresh(): void {
    this.rows = this.entryRows()
  }

  // ── 半模态入口 ────────────────────────────────────────────────────────────

  /** 新建条目：没有预览态可退，直接进编辑态。 */
  openNewEntry(): void {
    this.sheet.entryUuid = ''
    this.sheet.editFromPreview = false
    this.sheet.mode = EntrySheetMode.Edit
    this.sheet.visible = true
  }

  /** 查看条目：进预览态，并记一次活动让闲置计时不误锁。 */
  openEntry(uuid: string): void {
    this.sheet.entryUuid = uuid
    this.sheet.editFromPreview = false
    this.sheet.mode = EntrySheetMode.Preview
    this.sheet.visible = true
    stageOneVaultStore.touch()
  }

  /** 左滑编辑条目：直接打开编辑态半模态。 */
  openEdit(uuid: string): void {
    this.sheet.entryUuid = uuid
    this.sheet.editFromPreview = false
    this.sheet.mode = EntrySheetMode.Edit
    this.sheet.visible = true
    stageOneVaultStore.touch()
  }

  // ── 列表动作 ──────────────────────────────────────────────────────────────

  /**
   * 切换收藏：先乐观更新行模型让图标立即响应，再落盘。
   * 落盘后主表整体重建成新对象，因此回写必须按 uuid 重新定位，不持有旧行模型的引用。
   */
  toggleFavorite(uuid: string): void {
    const row: EntryRowModel | undefined = this.rows.find((item: EntryRowModel) => item.uuid === uuid)
    if (row === undefined) {
      return
    }
    const next: boolean = !row.favorite
    LogUtil.info(`[收藏调试] 请求切换，uuid=${uuid}，当前=${row.favorite}，目标=${next}`)
    row.setFavorite(next)
    this.persistFavorite(uuid, next).then((applied: boolean) => {
      // 主表在收藏筛选下会整体重排，回写必须按 uuid 重新定位，不持有旧行模型的引用。
      this.refresh()
      const refreshedRow: EntryRowModel | undefined = this.rows.find((item: EntryRowModel) => item.uuid === uuid)
      refreshedRow?.setFavorite(applied)
      LogUtil.info(`[收藏调试] 列表回写完成，uuid=${uuid}，状态=${applied}，找到行=${refreshedRow !== undefined}`)
    })
  }

  /**
   * 删除条目：落盘成功后才播出场动画，动画结束由宿主重建快照。
   * 顺序是业务规则 —— 高度先收成 0，其余卡片才会随布局动画上移，
   * 数据移除发生在动画之后才不会看到跳动，所以整段编排归这里。
   */
  deleteEntry(uuid: string, host: VaultEntryListHost): void {
    this.persistDelete(uuid).then((deleted: boolean) => {
      if (!deleted) {
        return
      }
      host.animateRowExit(uuid)
      host.notifyDeleted()
    })
  }

  // ── 行模型主表 ────────────────────────────────────────────────────────────

  /** 按当前浏览快照解析行模型；头像只在这里读一次，行组件不再查库。 */
  private entryRows(): EntryRowModel[] {
    return vaultHomeViewModel.entries.map((entry: VaultEntry): EntryRowModel => {
      return new EntryRowModel(entry, entry.hasAvatar ? stageOneVaultStore.loadEntryAvatar(entry.uuid) : undefined)
    })
  }

  // ── 握持手 ────────────────────────────────────────────────────────────────

  subscribeHoldingHand(host: VaultEntryListHost): void {
    this.host = host
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
    this.host = undefined
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

  /**
   * 握持手变化：只有明确的左手/右手握持才翻转，未握持、双手握持、未识别一律保持当前侧，
   * 避免识别抖动让按钮来回跳。
   */
  private applyHoldingHand(status: motion.HoldingHandStatus): void {
    if (this.host === undefined) {
      return
    }
    if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
      this.switchFabSide(false)
      return
    }
    if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) {
      this.switchFabSide(true)
    }
  }

  private switchFabSide(right: boolean): void {
    if (this.fabRight === right) {
      return
    }
    this.fabRight = right
    this.host!.animateFabSide(right)
  }

  // ── 落盘 ──────────────────────────────────────────────────────────────────

  private async persistFavorite(uuid: string, favorite: boolean): Promise<boolean> {
    try {
      const entry: VaultEntry = await stageOneVaultStore.setFavorite(uuid, favorite)
      vaultHomeViewModel.invalidate()
      LogUtil.info(`[收藏调试] 落盘完成，uuid=${uuid}，状态=${entry.favorite}`)
      return entry.favorite
    } catch (error) {
      LogUtil.error(`更新收藏状态失败，错误码=${(error as BusinessError).code}`)
      return favorite
    }
  }

  private async persistDelete(uuid: string): Promise<boolean> {
    try {
      await stageOneVaultStore.deleteEntry(uuid)
      return true
    } catch (error) {
      LogUtil.error(`删除条目失败，错误码=${(error as BusinessError).code}`)
      return false
    }
  }
}

export const homeEntryListViewModel: HomeEntryListViewModel = new HomeEntryListViewModel()
