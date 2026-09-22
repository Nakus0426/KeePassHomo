import { HdsListItem } from '@kit.UIDesignKit'
import { AppToast, VaultEntry } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
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
    return TAB_BAR_FLOAT_TOP_INSET_VP + gapVp
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
      if (deleted) {
        AppToast.show(this.getUIContext(), $r('app.string.entry_moved_to_recycle_bin'))
      }
    })
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
