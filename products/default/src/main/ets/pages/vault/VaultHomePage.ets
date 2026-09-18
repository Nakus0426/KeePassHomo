import { VaultEntry } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { EntryCard } from '../../components/EntryCard'
import { ROUTE_ENTRY_DETAIL } from '../../constants/RouteConstants'
import { appRouter } from '../../navigation/AppRouter'
import { EntryDetailParam } from '../../navigation/RouteParams'
import { AppSessionState, appSessionState } from '../../state/AppSessionState'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { appViewModel } from '../../viewmodel/AppViewModel'
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
  @Local private entrySheet: EntryEditSheetState = new EntryEditSheetState()

  @Computed
  get topAvoidAreaHeight(): number {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const gapPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
    const systemOffsetVp = this.getUIContext()
      .px2vp(this.immersiveLayout.topAvoidAreaHeightPx + titlebarHeightPx + gapPx)
    return systemOffsetVp + TITLE_BAR_FILTER_ROW_HEIGHT_VP
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

  @Builder
  private emptyBuilder() {
    Column({ space: $r('sys.float.padding_level6') }) {
      Image($r('app.media.empty'))
        .width($r('app.float.vault_empty_icon_size'))
        .height($r('app.float.vault_empty_icon_size'))

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
  private entryListBuilder() {
    List({ space: CARD_SPACING_VP }) {
      Repeat<VaultEntry>(this.home.entries)
        .each((item: RepeatItem<VaultEntry>) => {
          ListItem() {
            EntryListRow({
              entry: item.item,
              favoriteEnabled: !appViewModel.currentSource().readOnly,
              onEntryClick: (entry: VaultEntry) => this.openEntry(entry),
              onFavoriteToggle: (entry: VaultEntry) => appViewModel.toggleFavorite(entry.uuid),
            })
          }
          .margin({
            top: item.index === 0 ? this.topAvoidAreaHeight : 0,
            bottom: item.index === this.home.entries.length - 1
              ? $r('app.float.module_content_bottom_padding') : 0,
          })
        })
        .key((entry: VaultEntry) => entry.uuid)
        .virtualScroll({
          memoryOptimizationStrategy: RepeatMemOptStrategy.ENABLE_AUTO_CACHE_OPTIMIZATION,
        })
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
    .cachedCount(CARD_CACHED_COUNT)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .onTouch(() => appViewModel.recordActivity())
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
      bottom: $r('app.float.module_content_bottom_padding'),
    })
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  build() {
    Stack() {
      if (this.home.entries.length > 0) {
        this.entryListBuilder()
      } else {
        this.emptyStateBuilder()
      }

      EntryEditSheet({ state: this.entrySheet })
    }
    .width('100%')
    .height('100%')
  }
}
