import { uiMaterial } from '@kit.ArkUI'
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { AnimationTokens } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { EntryCard } from '../../components/EntryCard'
import { ROUTE_SEARCH } from '../../constants/RouteConstants'
import { registerFadeDestination, unregisterFadeDestination } from '../../navigation/NavFadeTransition'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { entrySheetViewModel } from '../../viewmodel/EntrySheetViewModel'
import { EntryRowModel } from '../../viewmodel/HomeEntryListViewModel'
import { SearchEntryListViewModel } from '../../viewmodel/SearchEntryListViewModel'
import { EntrySheet } from './EntrySheet'

// 与卡片内边距同档，保持纵向节奏一致。
const CARD_SPACING_VP: number = 8

// 一屏约 7 张卡片，官方长列表最佳实践建议预加载一屏条数的 1/2。
const CARD_CACHED_COUNT: number = 3

@ComponentV2
export struct SearchPage {
  @Local private pageOpacity: number = 1
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private app: AppViewModel = appViewModel
  // 搜索词与结果都归页面所有：弹出本页即释放，不留在全局状态里。
  @Local private list: SearchEntryListViewModel = new SearchEntryListViewModel()
  // 卡片转场与首页同参；搜索页无左滑动作，原生 ListItem 可直接挂通用属性。
  private readonly entryCardTransition: TransitionEffect = TransitionEffect.asymmetric(
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
  // 列表与空态整屏切换只做交叉淡化，缩放留给卡片本身。
  private readonly stateSwitchTransition: TransitionEffect = TransitionEffect.OPACITY
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })

  aboutToAppear(): void {
    registerFadeDestination(ROUTE_SEARCH, {
      onFadeStart: (isEnter: boolean) => {
        this.pageOpacity = isEnter ? 0 : 1
      },
      onFadeFinish: (isEnter: boolean) => {
        this.pageOpacity = isEnter ? 1 : 0
      },
    })
    // 首屏装填不带动画：进出本页的转场由导航淡入淡出负责。
    this.list.refresh()
  }

  aboutToDisappear(): void {
    unregisterFadeDestination(ROUTE_SEARCH)
  }

  // 预览半模态里的编辑、删除、收藏都会推进 revision，行数据必须跟着重建（删除行要播退出转场）。
  @Monitor('app.revision')
  onRevisionChanged(): void {
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    }, () => this.list.refresh())
  }

  @Computed
  private get searchPaddingLeft() {
    const backButtonMarginLeftPx = ResUtil.getNumber($r('sys.float.titlebar_backbutton_margin_left').id)
    const backButtonWidthPx = ResUtil.getNumber($r('sys.float.titlebar_icon_background_width').id)
    const paddingLeftPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
    return this.getUIContext().px2vp(backButtonMarginLeftPx + backButtonWidthPx + paddingLeftPx)
  }

  // 沉浸式标题栏之下：状态栏 + 标题栏 + 同档间距。本页压在首页之上，无 tab 栏与悬浮按钮。
  @Computed
  private get contentTopOffset(): number {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const gapPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
    return this.getUIContext().px2vp(this.immersiveLayout.topAvoidAreaHeightPx + titlebarHeightPx + gapPx)
  }

  @Computed
  private get contentBottomOffset(): number {
    const gapPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
    return this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx + gapPx)
  }

  // 行数据替换必须落在动画上下文里，命中集合变化时卡片才能播出入场转场。
  private applyQuery(value: string): void {
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    }, () => this.list.setQuery(value))
  }

  @Builder
  private searchBuilder() {
    Row() {
      Search({ placeholder: $r('app.string.search_vault'), value: this.list.query })
        .height($r('sys.float.titlebar_icon_background_width'))
        .searchButton($r('app.string.search'))
        // 只声明默认焦点：本页被淡出时会重建标题栏节点，命令式 requestFocus 会在不可获焦的祖先下抛 150002。
        .defaultFocus(true)
        .systemMaterial(
          new uiMaterial.ImmersiveMaterial({ style: uiMaterial.ImmersiveStyle.ULTRA_THIN, interactive: true }))
        .onChange((value: string) => this.applyQuery(value))
        .onSubmit(() => this.app.recordActivity())
    }
    .width('100%')
    .padding({
      left: this.searchPaddingLeft,
      right: $r('sys.float.padding_level8'),
    })
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
      })
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
  }

  @Builder
  private entryListBuilder() {
    List({ space: CARD_SPACING_VP }) {
      ListItem() {
        Column()
          .width('100%')
          .height(this.contentTopOffset - CARD_SPACING_VP)
      }

      Repeat<EntryRowModel>(this.list.rows)
        .each((item: RepeatItem<EntryRowModel>) => {
          ListItem() {
            this.entryCardSlot(item)
          }
          .transition(this.entryCardTransition)
        })
        .key((row: EntryRowModel) => row.uuid)
        .virtualScroll({
          memoryOptimizationStrategy: RepeatMemOptStrategy.ENABLE_AUTO_CACHE_OPTIMIZATION,
        })

      ListItem() {
        Column()
          .width('100%')
          .height(this.contentBottomOffset - CARD_SPACING_VP)
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

  // 空态只有占位图标：库为空与否都不提供新建入口，搜索页不承担新建职责。
  @Builder
  private emptyStateBuilder() {
    Scroll() {
      Column() {
        Image($r('app.media.entry_search_empty'))
          .width($r('app.float.vault_empty_icon_size'))
          .height($r('app.float.vault_empty_icon_size'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .padding({
      top: this.contentTopOffset,
      left: $r('sys.float.padding_level8'),
      right: $r('sys.float.padding_level8'),
      bottom: this.contentBottomOffset,
    })
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .transition(this.stateSwitchTransition)
  }

  build() {
    HdsNavDestination() {
      RelativeContainer() {
        if (this.list.rows.length > 0) {
          this.entryListBuilder()
        } else {
          this.emptyStateBuilder()
        }

        EntrySheet({ sheet: entrySheetViewModel })
      }
      .width('100%')
      .height('100%')
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
        },
      },
      content: {
        backIcon: {},
        stackBuilder: () => this.searchBuilder(),
      },
    })
    .opacity(this.pageOpacity)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}

@Builder
export function searchPageBuilder() {
  SearchPage()
}
