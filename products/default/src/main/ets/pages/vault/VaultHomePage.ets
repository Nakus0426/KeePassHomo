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
import { entrySheetViewModel } from '../../viewmodel/EntrySheetViewModel'
import { EntrySheet } from './EntrySheet'

const TITLE_BAR_FILTER_ROW_HEIGHT_VP: number = 56

// 与卡片内边距同档，保持纵向节奏一致。
const CARD_SPACING_VP: number = 8

// 一屏约 7 张卡片，官方长列表最佳实践建议预加载一屏条数的 1/2。
const CARD_CACHED_COUNT: number = 3

// ViewModel 只发语义动作，动作体需要页面 UIContext，故先建实例再回填。
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

// 视图层只渲染行模型与列表动画，头像解析、收藏、删除编排都在 HomeEntryListViewModel。
@ComponentV2
export struct VaultHomePage {
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private home: VaultHomeViewModel = vaultHomeViewModel
  @Local private list: HomeEntryListViewModel = homeEntryListViewModel
  @Local private app: AppViewModel = appViewModel
  // HdsListItem 不支持通用属性，增删转场只能经 ListItemModifier 下发。
  // animation 写在组合链首个效果上，按官方规则会同时作用于后面的 scale 效果。
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
  // 列表与空态整屏切换只做交叉淡化，缩放留给卡片本身。
  private readonly stateSwitchTransition: TransitionEffect = TransitionEffect.OPACITY
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })
  @Local private removingEntryUuid: string = ''
  @Local private fabAppeared: boolean = false
  private readonly fabRulesRight: AlignRuleOption = {
    right: { anchor: '__container__', align: HorizontalAlign.End },
    bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
  }
  private readonly fabRulesLeft: AlignRuleOption = {
    left: { anchor: '__container__', align: HorizontalAlign.Start },
    bottom: { anchor: '__container__', align: VerticalAlign.Bottom },
  }
  private readonly fabAppearCurve: ICurve = curves.interpolatingSpring(0, 1, 200, 17)
  private readonly fabHandSwitchCurve: ICurve = curves.interpolatingSpring(0, 1, 170, 17)
  private readonly listHost: HomeListHost = new HomeListHost()
  // 快照由 vaultHomeViewModel 持有：锁定时清空、解锁与筛选变化时重建。
  // 用引用本身作比较：每次重建都换新数组，否则会出现「快照有条目、列表为空」。
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

  // 比较快照引用而不是「列表为空就重建」：空库与筛选无命中本来就是空的。
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

  // 空库入口由空态自带的「新建条目」按钮承担，只读保险库不提供新建入口。
  @Computed
  get showNewEntryFab(): boolean {
    return this.home.hasAnyEntry && !this.app.currentSource().readOnly
  }

  @Computed
  get newEntryFabDiameter(): number {
    return this.getUIContext().px2vp(ResUtil.getNumber($r('sys.float.ohos_id_min_circle_button_diameter').id))
  }

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

  private animateFabSide(right: boolean): void {
    this.getUIContext().animateTo({ curve: this.fabHandSwitchCurve }, () => this.list.fabRight = right)
  }

  @Builder
  private emptyBuilder() {
    Column({ space: $r('sys.float.padding_level6') }) {
      Image($r('app.media.entry_empty'))
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
        .onClick(() => entrySheetViewModel.openNew())
      }
    }
    .alignItems(HorizontalAlign.Center)
    .translate({ y: '-50%' })
  }

  @Builder
  private noResultBuilder() {
    Image($r('app.media.entry_search_empty'))
      .width($r('app.float.vault_empty_icon_size'))
      .height($r('app.float.vault_empty_icon_size'))
  }

  @Builder
  private entryCardSlot(item: RepeatItem<EntryRowModel>) {
    Row() {
      EntryCard({
        entry: item.item.entry,
        avatarData: item.item.avatarData,
        favorite: item.item.favorite,
        favoriteEnabled: !this.app.currentSource().readOnly,
        onEntryClick: () => entrySheetViewModel.openPreview(item.item.uuid),
        onFavoriteToggle: () => this.list.toggleFavorite(item.item.uuid),
        onEdit: () => entrySheetViewModel.openEdit(item.item.uuid),
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
                onAction: () => entrySheetViewModel.openEdit(item.item.uuid),
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

  // 位置由 alignRules 锚定容器左右下角，左右翻转靠 if/else 换节点。
  // 由 move 转场播出官方要求的「沿本侧滑出屏幕外、从对侧滑入」绕行动效。
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
    .onClick(() => entrySheetViewModel.openNew())
  }

  build() {
    RelativeContainer() {
      // 无保险库时首页无内容可说：currentSource() 是 fail-fast 断言，未选定保险库时不得读取。
      if (this.app.hasRecentVault()) {
        // 判空与列表渲染必须读同一个数据源，否则会出现「判空说有、列表渲染是空」。
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

        EntrySheet({ sheet: entrySheetViewModel })
      }
    }
    .width('100%')
    .height('100%')
  }
}
