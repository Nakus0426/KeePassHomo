import { ResUtil } from '@pura/harmony-utils'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { EntryEditSheet, EntryEditSheetState } from './EntryEditSheet'

const TITLE_BAR_FILTER_ROW_HEIGHT_VP: number = 56

@ComponentV2
export struct VaultHomePage {
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
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

  @Builder
  private emptyBuilder() {
    Column({ space: $r('sys.float.padding_level6') }) {
      Image($r('app.media.empty'))
        .width($r('app.float.vault_empty_icon_size'))
        .height($r('app.float.vault_empty_icon_size'))

      Button() {
        Row({ space: $r('sys.float.padding_level4') }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize($r('sys.float.Body_M'))
            .fontColor([$r('sys.color.font_emphasize')])

          Text($r('app.string.new_entry'))
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('sys.color.font_emphasize'))
        }
      }
      .buttonStyle(ButtonStyleMode.NORMAL)
      .type(ButtonType.Capsule)
      .padding({
        top: $r('sys.float.padding_level4'),
        bottom: $r('sys.float.padding_level4'),
        left: $r('sys.float.padding_level6'),
        right: $r('sys.float.padding_level6'),
      })
      .onClick(() => this.openNewEntry())
    }
    .alignItems(HorizontalAlign.Center)
    .translate({ y: '-50%' })
  }

  build() {
    Stack() {
      Scroll() {
        Column() {
          this.emptyBuilder()
        }
        .width('100%')
        .height('100%')
        .padding(
          { top: this.topAvoidAreaHeight, left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring)

      EntryEditSheet({ state: this.entrySheet })
    }
    .width('100%')
    .height('100%')
  }
}
