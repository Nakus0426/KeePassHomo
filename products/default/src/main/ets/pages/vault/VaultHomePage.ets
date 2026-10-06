import { curves, ListItemModifier, SymbolGlyphModifier, UIContext } from '@kit.ArkUI'
import { HdsListItem } from '@kit.UIDesignKit'
import { AnimationTokens, AppToast, VaultEntry } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { EntryCard } from '../../components/EntryCard'
import { TAB_BAR_FLOAT_TOP_INSET_VP } from '../../constants/TabBarMetrics'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import {
  EntryRowModel,
  HomeEntryListViewModel,
  homeEntryListViewModel,
  VaultEntryListHost,
} from '../../viewmodel/HomeEntryListViewModel'
import { VaultHomeViewModel, vaultHomeViewModel } from '../../viewmodel/VaultHomeViewModel'
import { EntrySheet } from './EntrySheet'

const TITLE_BAR_FILTER_ROW_HEIGHT_VP: number = 56

/** 卡片间距，与卡片内边距同档，保持纵向节奏一致。 */
const CARD_SPACING_VP: number = 8

/** 屏幕外预加载条数：官方长列表最佳实践建议取一屏条数的 1/2（本场景一屏约 7 张卡片）。 */
const CARD_CACHED_COUNT: number = 3

/**
 * 列表动画与提示的落地实现：ViewModel 发出语义动作，界面动画留在视图层。
 * 动作体需要页面的 UIContext，所以先创建页面实例再回填。
 */
class HomeListHost extends VaultEntryListHost {
  onRowExit: (uuid: string) => void = () => {
  }
  onSnapshotRefresh: () => void = () => {
  }
  onDeleted: () => void = () => {
  }
  onFabSide: (right: boolean) => void = () => {
  }

  animateRowExit(uuid: string): void {
    this.onRowExit(uuid)
  }

  refreshSnapshot(): void {
    this.onSnapshotRefresh()
  }

  notifyDeleted(): void {
    this.onDeleted()
  }

  animateFabSide(right: boolean): void {
    this.onFabSide(right)
  }
}

/**
 * 首页条目列表。只做三件事：渲染行模型、把交互交给 ViewModel、实现列表动画回调。
 * 头像解析、收藏、删除编排、握持手策略、新建与查看入口全部在 HomeEntryListViewModel 里。
 */
@ComponentV2
export struct VaultHomePage {
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private home: VaultHomeViewModel = vaultHomeViewModel
  @Local private list: HomeEntryListViewModel = homeEntryListViewModel
  @Local private app: AppViewModel = appViewModel
  /**
   * 卡片增删转场：HdsListItem 不支持通用属性，转场只能经 ListItemModifier 下发。
   * 配合新增/删除处的 animateTo 使用：入场由小放大淡入，出场缩小淡出；
   * animation 写在组合链首个效果上，按官方规则会同时作用于后面的 scale 效果。
   */
  private readonly entryCardItemModifier: ListItemModifier = new ListItemModifier()
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY
        .animation({
          duration: AnimationTokens.STATE_TRANSITION_DURATION,
          curve: AnimationTokens.STATE_TRANSITION_CURVE,
        })
        .combine(TransitionEffect.scale({
          x: AnimationTokens.CARD_ENTER_SCALE,
          y: AnimationTokens.CARD_ENTER_SCALE,
        })),
      TransitionEffect.OPACITY
        .animation({
          duration: AnimationTokens.STATE_TRANSITION_DURATION,
          curve: AnimationTokens.STATE_TRANSITION_CURVE,
        })
        .combine(TransitionEffect.scale({
          x: AnimationTokens.CARD_EXIT_SCALE,
          y: AnimationTokens.CARD_EXIT_SCALE,
        })),
    ))
  /** 列表与空态整屏切换的交叉淡入淡出：只淡入淡出，缩放留给卡片本身。 */
  private readonly stateSwitchTransition: TransitionEffect = TransitionEffect.OPACITY
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })
  /**
   * 最近一次播出场动画的条目 uuid，初值为空串。
   * 出场走属性动画（缩小、淡出、高度收起）而不依赖移除节点的 transition：
   * 高度收成 0 让后续卡片随布局动画上移，动画结束后才移除数据。
   * 被删条目不会再回到列表，标记只在下次删除时覆盖，绝不复位：移除那一帧复位会让
   * 已收起的卡片节点在被销毁前恢复原尺寸，于是在旧位置闪一下。
   */
  @Local private removingEntryUuid: string = ''
  /** 悬浮按钮是否已经出场过：首次出场用官方给的较强弹性曲线，之后用绕行曲线。 */
  @Local private fabAppeared: boolean = false
  private readonly fabRulesRight: AlignRuleOption = {
    right: { anchor: '__container__', align: HorizontalAlign.End },
    bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
  }
  private readonly fabRulesLeft: AlignRuleOption = {
    left: { anchor: '__container__', align: HorizontalAlign.Start },
    bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
  }
  /** 首次出场曲线：stiffness 200，出场更利落。 */
  private readonly fabAppearCurve: ICurve = curves.interpolatingSpring(0, 1, 200, 17)
  /** 握持手切换的绕行曲线：stiffness 170，侧边绕行更自然。 */
  private readonly fabHandSwitchCurve: ICurve = curves.interpolatingSpring(0, 1, 170, 17)
  /** 列表动画回调出口：ViewModel 发出语义动作，界面动画留在视图层。 */
  private readonly listHost: HomeListHost = new HomeListHost()
  /**
   * 行模型缓存对应的快照。快照由 vaultHomeViewModel 持有：锁定时清空、解锁与筛选变化时重建，
   * 因此渲染前必须确认行模型就是当前这份快照的，否则会出现「快照有条目、列表为空」。
   * 用快照引用本身作比较：每次重建都会换成新数组，引用相等即无需重建。
   */
  private syncedEntries: VaultEntry[] | undefined = undefined

  aboutToAppear(): void {
    this.listHost.onRowExit = (uuid: string): void => this.animateRowExit(uuid)
    this.listHost.onSnapshotRefresh = (): void => this.app.refreshHomeSnapshot()
    this.listHost.onDeleted =
      (): void => AppToast.show(this.getUIContext(), $r('app.string.entry_moved_to_recycle_bin'))
    this.listHost.onFabSide = (right: boolean): void => this.animateFabSide(right)
    this.list.subscribeHoldingHand(this.listHost)
  }

  aboutToDisappear(): void {
    this.list.unsubscribeHoldingHand()
  }

  /**
   * 保证行模型对应当前快照，返回最新的行数。
   * 比较快照引用而不是「列表为空就重建」：空库与筛选无命中本来就是空的，
   * 按空判断会让每次渲染都白重建一遍。
   */
  private syncRows(): number {
    const entries: VaultEntry[] = this.home.entries
    if (this.syncedEntries !== entries) {
      this.syncedEntries = entries
      this.list.refresh()
    }
    return this.list.rows.length
  }

  @Monitor('app.status')
  onStatusChanged(): void {
    if (this.app.status.length > 0) {
      AppToast.show(this.getUIContext(), this.app.status)
    }
  }

  @Computed
  get topAvoidAreaHeight(): number {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const gapPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
    const systemOffsetVp = this.getUIContext()
      .px2vp(this.immersiveLayout.topAvoidAreaHeightPx + titlebarHeightPx + gapPx)
    return systemOffsetVp + TITLE_BAR_FILTER_ROW_HEIGHT_VP
  }

  @Computed
  get bottomAvoidHeight(): number {
    const gapPx: number = ResUtil.getNumber($r('sys.float.padding_level8').id)
    const gapVp: number = this.getUIContext().px2vp(gapPx)
    // 悬浮按钮显示时，底部再让出按钮直径与按钮到内容的同档间距，避免压住最后一张卡片。
    const fabInsetVp: number = this.showNewEntryFab ? this.newEntryFabDiameter + gapVp : 0
    return TAB_BAR_FLOAT_TOP_INSET_VP + gapVp + fabInsetVp
  }

  /**
   * 悬浮按钮可见性：空库由空态自带的「新建条目」按钮承担入口，
   * 只读保险库不提供新建入口。
   */
  @Computed
  get showNewEntryFab(): boolean {
    return this.home.hasAnyEntry && !this.app.currentSource().readOnly
  }

  /** 悬浮按钮直径：取系统圆形按钮直径下限。 */
  @Computed
  get newEntryFabDiameter(): number {
    return this.getUIContext().px2vp(ResUtil.getNumber($r('sys.float.ohos_id_min_circle_button_diameter').id))
  }

  /** 悬浮按钮底边留白：悬浮底栏顶面之上再抬一个 padding_level8。 */
  @Computed
  get newEntryFabBottomInset(): number {
    const gapPx: number = ResUtil.getNumber($r('sys.float.padding_level8').id)
    return TAB_BAR_FLOAT_TOP_INSET_VP + this.getUIContext().px2vp(gapPx)
  }

  private confirmDeleteEntry(row: EntryRowModel): void {
    const options: AlertDialogParamWithButtons = {
      title: $r('app.string.delete_entry_title'),
      message: $r('app.string.delete_entry_message'),
      primaryButton: {
        value: $r('app.string.cancel'),
        action: () => {
        },
      },
      secondaryButton: {
        value: $r('app.string.delete_entry'),
        fontColor: $r('sys.color.warning'),
        action: () => this.list.deleteEntry(row.uuid, this.listHost),
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  /**
   * 出场不依赖移除节点的 transition：先把卡片缩小淡出并把高度收成 0（其余卡片随布局动画上移），
   * 动画结束后再重建快照。高度已为 0，数据移除不会产生可见跳动。
   */
  private animateRowExit(uuid: string): void {
    const uiContext: UIContext = this.getUIContext()
    uiContext.animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
      onFinish: () => {
        uiContext.animateTo({
          duration: AnimationTokens.STATE_TRANSITION_DURATION,
          curve: AnimationTokens.STATE_TRANSITION_CURVE,
        }, () => this.listHost.refreshSnapshot())
      },
    }, () => this.removingEntryUuid = uuid)
  }

  /** 悬浮按钮翻转朝向：ViewModel 决定该往哪边，动画上下文由视图层提供。 */
  private animateFabSide(right: boolean): void {
    this.getUIContext().animateTo({ curve: this.fabHandSwitchCurve }, () => this.list.fabRight = right)
  }

  @Builder
  private emptyBuilder() {
    Column({ space: $r('sys.float.padding_level6') }) {
      Image($r('app.media.empty'))
        .width($r('app.float.vault_empty_icon_size'))
        .height($r('app.float.vault_empty_icon_size'))

      if (!this.app.currentSource().readOnly) {
        Button() {
          Row({ space: $r('sys.float.padding_level4') }) {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize($r('sys.float.chip_normal_font_size'))
              .fontColor([$r('sys.color.font_emphasize')])

            Text($r('app.string.new_entry'))
              .fontSize($r('sys.float.chip_normal_font_size'))
              .fontColor($r('sys.color.font_emphasize'))
          }
        }
        .height($r('sys.float.chip_normal_height'))
        .buttonStyle(ButtonStyleMode.NORMAL)
        .type(ButtonType.Capsule)
        .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
        .onClick(() => this.list.openNewEntry())
      }
    }
    .alignItems(HorizontalAlign.Center)
    .translate({ y: '-50%' })
  }

  @Builder
  private noResultBuilder() {
    Text($r('app.string.no_results'))
      .fontSize($r('sys.float.Body_L'))
      .fontColor($r('sys.color.font_secondary'))
      .translate({ y: '-50%' })
  }

  @Builder
  private entryCardSlot(item: RepeatItem<EntryRowModel>) {
    Row() {
      EntryCard({
        entry: item.item.entry,
        avatarData: item.item.avatarData,
        favorite: item.item.favorite,
        favoriteEnabled: !this.app.currentSource().readOnly,
        onEntryClick: () => this.list.openEntry(item.item.uuid),
        onFavoriteToggle: () => this.list.toggleFavorite(item.item.uuid),
        onEdit: () => this.list.openEdit(item.item.uuid),
      })
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
    .height(this.removingEntryUuid === item.item.uuid ? 0 : 'auto')
    .opacity(this.removingEntryUuid === item.item.uuid ? 0 : 1)
    .scale({
      x: this.removingEntryUuid === item.item.uuid ? AnimationTokens.CARD_EXIT_SCALE : 1,
      y: this.removingEntryUuid === item.item.uuid ? AnimationTokens.CARD_EXIT_SCALE : 1,
    })
    .clip(this.removingEntryUuid === item.item.uuid)
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })
  }

  @Builder
  private entryListBuilder() {
    List({ space: CARD_SPACING_VP }) {
      ListItem() {
        Column()
          .width('100%')
          .height(this.topAvoidAreaHeight - CARD_SPACING_VP)
      }

      Repeat<EntryRowModel>(this.list.rows)
        .each((item: RepeatItem<EntryRowModel>) => {
          HdsListItem({
            customItemBuilder: () => {
              // 必须整体传 RepeatItem：只传 item.item 会让复用节点读不到数据变化（官方 FAQ faqs-arkui-609）。
              this.entryCardSlot(item)
            },
            listItemModifier: this.entryCardItemModifier,
            swipeActionOptions: this.app.currentSource().readOnly ? undefined : {
              icons: [{
                icon: new SymbolGlyphModifier($r('sys.symbol.square_and_pencil'))
                  .fontColor([$r('sys.color.icon_on_primary')])
                  .fontSize($r('sys.float.titlebar_icon_width')),
                backgroundColor: $r('sys.color.brand'),
                onAction: () => this.list.openEdit(item.item.uuid),
              }],
              deleteIconOptions: {
                onAction: () => this.confirmDeleteEntry(item.item),
              },
            },
          })
        })
        .key((row: EntryRowModel) => row.uuid)
        .virtualScroll({
          memoryOptimizationStrategy: RepeatMemOptStrategy.ENABLE_AUTO_CACHE_OPTIMIZATION,
        })

      ListItem() {
        Column()
          .width('100%')
          .height(this.bottomAvoidHeight - CARD_SPACING_VP)
      }
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .cachedCount(CARD_CACHED_COUNT)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .onTouch(() => this.app.recordActivity())
    .transition(this.stateSwitchTransition)
  }

  @Builder
  private emptyStateBuilder() {
    Scroll() {
      Column() {
        if (this.home.hasAnyEntry) {
          this.noResultBuilder()
        } else {
          this.emptyBuilder()
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .padding({
      top: this.topAvoidAreaHeight,
      left: $r('sys.float.padding_level8'),
      right: $r('sys.float.padding_level8'),
      bottom: this.bottomAvoidHeight,
    })
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .transition(this.stateSwitchTransition)
  }

  /**
   * 新增条目悬浮按钮：系统强调按钮默认主题色填充，图标与直径取系统圆形按钮尺寸下限。
   * 位置由 alignRules 锚定容器左右下角；左右翻转靠 if/else 换节点，由 move 转场播出官方要求的
   * 「沿本侧滑出屏幕外、从对侧滑入」绕行动效。
   */
  @LocalBuilder
  private newEntryFab(right: boolean) {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize($r('sys.float.ohos_id_min_circle_button_icon_size'))
        .fontColor([$r('sys.color.icon_on_primary')])
    }
    .width(this.newEntryFabDiameter)
    .height(this.newEntryFabDiameter)
    .alignRules(right ? this.fabRulesRight : this.fabRulesLeft)
    .backgroundColor($r('sys.color.brand'))
    .shadow(ShadowStyle.OUTER_FLOATING_SM)
    .margin({
      left: $r('sys.float.padding_level8'),
      right: $r('sys.float.padding_level8'),
      bottom: this.newEntryFabBottomInset,
    })
    .transition(TransitionEffect.move(right ? TransitionEdge.END : TransitionEdge.START)
      .animation({ curve: this.fabAppeared ? this.fabHandSwitchCurve : this.fabAppearCurve }))
    .accessibilityText($r('app.string.new_entry'))
    .onAppear(() => this.fabAppeared = true)
    .onClick(() => this.list.openNewEntry())
  }

  build() {
    RelativeContainer() {
      // 无保险库时首页无内容可说：currentSource() 是 fail-fast 断言，未选定保险库时不得读取。
      if (this.app.hasRecentVault()) {
        // 判空与列表渲染必须读同一个数据源，否则会出现「判空说有、列表渲染是空」。
        // syncRows 读 home.entries，快照换新数组即重建行模型，重绘由该依赖触发。
        if (this.syncRows() > 0) {
          this.entryListBuilder()
        } else {
          this.emptyStateBuilder()
        }

        if (this.showNewEntryFab) {
          if (this.list.fabRight) {
            this.newEntryFab(true)
          } else {
            this.newEntryFab(false)
          }
        }

        EntrySheet({ state: this.list.sheet })
      }
    }
    .width('100%')
    .height('100%')
  }
}
