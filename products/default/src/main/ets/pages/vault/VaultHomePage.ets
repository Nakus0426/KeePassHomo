import { ListItemModifier, UIContext } from '@kit.ArkUI'
import { HdsListItem } from '@kit.UIDesignKit'
import { AnimationTokens, AppToast, VaultEntry } from '@ohos/common'
import { LogUtil, ResUtil } from '@pura/harmony-utils'
import { EntryCard } from '../../components/EntryCard'
import { ROUTE_ENTRY_DETAIL } from '../../constants/RouteConstants'
import { TAB_BAR_FLOAT_TOP_INSET_VP } from '../../constants/TabBarMetrics'
import { appRouter } from '../../navigation/AppRouter'
import { EntryDetailParam } from '../../navigation/RouteParams'
import { AppSessionState, appSessionState } from '../../state/AppSessionState'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { VaultHomeViewModel, vaultHomeViewModel } from '../../viewmodel/VaultHomeViewModel'
import { EntryEditSheet, EntryEditSheetState } from './EntryEditSheet'

const TITLE_BAR_FILTER_ROW_HEIGHT_VP: number = 56

/** 卡片间距，与卡片内边距同档，保持纵向节奏一致。 */
const CARD_SPACING_VP: number = 8

/** 屏幕外预加载条数：官方长列表最佳实践建议取一屏条数的 1/2（本场景一屏约 7 张卡片）。 */
const CARD_CACHED_COUNT: number = 3

@ComponentV2
struct EntryListRow {
  @Require @Param entry: VaultEntry
  @Param favoriteEnabled: boolean = true
  @Event onEntryClick: (entry: VaultEntry) => void = () => {
  }
  @Event onFavoriteToggle: (entry: VaultEntry) => void = () => {
  }
  @Local private avatarData: ArrayBuffer | undefined = undefined

  aboutToAppear(): void {
    this.loadAvatar()
  }

  @Monitor('entry')
  private onEntryChanged(): void {
    this.loadAvatar()
  }

  private loadAvatar(): void {
    this.avatarData = this.entry.hasAvatar ? appViewModel.loadEntryAvatar(this.entry.uuid) : undefined
  }

  build() {
    EntryCard({
      entry: this.entry,
      avatarData: this.avatarData,
      favoriteEnabled: this.favoriteEnabled,
      onEntryClick: (entry: VaultEntry) => this.onEntryClick(entry),
      onFavoriteToggle: () => this.onFavoriteToggle(this.entry),
    })
  }
}

@ComponentV2
export struct VaultHomePage {
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private session: AppSessionState = appSessionState
  @Local private home: VaultHomeViewModel = vaultHomeViewModel
  @Local private app: AppViewModel = appViewModel
  @Local private entrySheet: EntryEditSheetState = new EntryEditSheetState()
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
   * 悬浮按钮出现/消失：淡入淡出叠加缩放（出现由小放大、消失缩小），参数与卡片转场同档。
   * 转场只在 animateTo 上下文中触发，条目增删后的快照刷新已由调用方包在 animateTo 里。
   */
  private readonly newEntryFabTransition: TransitionEffect = TransitionEffect.asymmetric(
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
  )
  /**
   * 正在播出场动画的条目 uuid，空串表示无。
   * 出场走属性动画（缩小、淡出、高度收起）而不依赖移除节点的 transition：
   * 高度收成 0 让后续卡片随布局动画上移，动画结束后才移除数据。
   */
  @Local private removingEntryUuid: string = ''

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

  private openNewEntry(): void {
    this.entrySheet.entryUuid = ''
    this.entrySheet.visible = true
  }

  private openEntry(entry: VaultEntry): void {
    const param: EntryDetailParam = { entryUuid: entry.uuid }
    appRouter.push(ROUTE_ENTRY_DETAIL, param)
    appViewModel.recordActivity()
  }

  private confirmDeleteEntry(entry: VaultEntry): void {
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
        action: () => this.deleteEntry(entry),
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  private deleteEntry(entry: VaultEntry): void {
    this.app.deleteEntry(entry.uuid).then((deleted: boolean) => {
      if (!deleted) {
        return
      }
      const uiContext: UIContext = this.getUIContext()
      // 出场不依赖移除节点的 transition：先把卡片缩小淡出并把高度收成 0（其余卡片随布局动画上移），
      // 动画结束后再重建快照。高度已为 0，数据移除不会产生可见跳动。
      LogUtil.info(`[动画调试] 删除落盘完成，开始出场动画：uuid=${entry.uuid}`)
      uiContext.animateTo({
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
        onFinish: () => {
          LogUtil.info('[动画调试] 出场动画结束，重建首页快照')
          uiContext.animateTo({
            duration: AnimationTokens.STATE_TRANSITION_DURATION,
            curve: AnimationTokens.STATE_TRANSITION_CURVE,
          }, () => {
            this.app.refreshHomeSnapshot()
            this.removingEntryUuid = ''
          })
        },
      }, () => {
        this.removingEntryUuid = entry.uuid
        LogUtil.info(`[动画调试] removingEntryUuid 已置位：${this.removingEntryUuid}`)
      })
      AppToast.show(uiContext, $r('app.string.entry_moved_to_recycle_bin'))
    })
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
        .onClick(() => this.openNewEntry())
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
  private entryCardSlot(entry: VaultEntry) {
    Row() {
      EntryListRow({
        entry: entry,
        favoriteEnabled: !appViewModel.currentSource().readOnly,
        onEntryClick: (entry: VaultEntry) => this.openEntry(entry),
        onFavoriteToggle: (entry: VaultEntry) => appViewModel.toggleFavorite(entry.uuid),
      })
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
    .height(this.removingEntryUuid === entry.uuid ? 0 : 'auto')
    .opacity(this.removingEntryUuid === entry.uuid ? 0 : 1)
    .scale({
      x: this.removingEntryUuid === entry.uuid ? AnimationTokens.CARD_EXIT_SCALE : 1,
      y: this.removingEntryUuid === entry.uuid ? AnimationTokens.CARD_EXIT_SCALE : 1,
    })
    .clip(this.removingEntryUuid === entry.uuid)
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

      Repeat<VaultEntry>(this.home.entries)
        .each((item: RepeatItem<VaultEntry>) => {
          HdsListItem({
            customItemBuilder: () => {
              this.entryCardSlot(item.item)
            },
            listItemModifier: this.entryCardItemModifier,
            swipeActionOptions: appViewModel.currentSource().readOnly ? undefined : {
              deleteIconOptions: {
                onAction: () => this.confirmDeleteEntry(item.item),
              },
            },
          })
        })
        .key((entry: VaultEntry) => entry.uuid)
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
    .onTouch(() => appViewModel.recordActivity())
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
   * 定位由外层 Stack 的 alignContent 决定：Button 不是 Stack，写在自身上的 align 只作用于按钮内容。
   */
  @LocalBuilder
  private newEntryFab() {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize($r('sys.float.ohos_id_min_circle_button_icon_size'))
        .fontColor([$r('sys.color.icon_on_primary')])
    }
    .width(this.newEntryFabDiameter)
    .height(this.newEntryFabDiameter)
    .backgroundColor($r('sys.color.brand'))
    .shadow(ShadowStyle.OUTER_FLOATING_SM)
    .margin({
      right: $r('sys.float.padding_level8'),
      bottom: this.newEntryFabBottomInset,
    })
    .accessibilityText($r('app.string.new_entry'))
    .onClick(() => this.openNewEntry())
    .transition(this.newEntryFabTransition)
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.home.entries.length > 0) {
        this.entryListBuilder()
      } else {
        this.emptyStateBuilder()
      }

      if (this.showNewEntryFab) {
        this.newEntryFab()
      }

      EntryEditSheet({ state: this.entrySheet })
    }
    .width('100%')
    .height('100%')
  }
}
