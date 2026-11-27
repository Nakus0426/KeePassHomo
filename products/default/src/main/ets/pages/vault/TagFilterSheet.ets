import { LengthMetrics } from '@kit.ArkUI'
import { measureVp } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { DsBottomActionBar, dsBottomActionBarHeight } from '../../components/DsBottomActionBar'
import { DsButton, DsButtonTone, DsButtonVariant } from '../../components/DsButton'
import { DsControlSize } from '../../components/DsControlSize'
import { DsHalfModalSheet } from '../../components/DsHalfModalSheet'
import { DsNotice, DsNoticeTone } from '../../components/DsNotice'
import { DsTag, dsTagMetrics, DsTagSize } from '../../components/DsTag'
import { VaultTagOption } from '../../model/StageOneVaultStore'

const CHIP_GAP: LengthMetrics = LengthMetrics.resource($r('app.float.ds_space_sm'))
// 段头一行 11/600 的固定行高，以及段头与 chip 流的间距。
const SECTION_HEADER_HEIGHT_VP: number = 13
const SECTION_GAP_VP: number = 16

// 面板按内容定高：chip 几何取自 DsTag 的同一份 metrics，底栏高度取自 DsBottomActionBar。
export function dsTagFilterSheetHeight(uiContext: UIContext, tags: string[], sheetWidthVp: number): number {
  const metrics = dsTagMetrics(DsTagSize.Medium)
  const chipHeight: number = metrics.lineHeight + measureVp(uiContext, metrics.padVertical) * 2
  const chipPad: number = measureVp(uiContext, metrics.padHorizontal) * 2
  const gap: number = measureVp(uiContext, $r('app.float.ds_space_sm'))
  const available: number = sheetWidthVp - measureVp(uiContext, $r('app.float.ds_gutter')) * 2
  let rows: number = 1
  let line: number = 0
  for (const tag of tags) {
    const textWidth: number = uiContext.px2vp(uiContext.getMeasureUtils().measureText({
      textContent: tag,
      fontSize: metrics.fontSize,
      fontWeight: 600,
      letterSpacing: measureVp(uiContext, $r('app.float.ds_tracking_wide_md')),
    }))
    const chip: number = textWidth + chipPad + 1
    if (line > 0 && line + gap + chip > available) {
      rows++
      line = chip
    } else {
      line += (line > 0 ? gap : 0) + chip
    }
  }
  const body: number = measureVp(uiContext, $r('app.float.ds_space_sm')) + SECTION_HEADER_HEIGHT_VP
    + SECTION_GAP_VP + rows * chipHeight + (rows - 1) * gap
  const footer: number = dsBottomActionBarHeight(uiContext, measureVp(uiContext, $r('app.float.ds_button_height')))
  const titleBar: number = measureVp(uiContext, $r('app.float.ds_page_header_height_sm'))
  return titleBar + body + footer
}

// 标签筛选半模态：草稿态选择，应用后由宿主写回首页筛选。
@ComponentV2
export struct TagFilterSheet {
  @Param tags: VaultTagOption[] = []
  @Param initialTags: string[] = []
  @Event onApply: (tags: string[]) => void = () => {
  }
  @Event onClose: () => void = () => {
  }
  @Local private draft: string[] = []
  @Local private footerHeight: number = 0

  // 选中判定走集合，避免每个 chip 每次构建都线性扫描 draft。
  @Computed
  get selectedSet(): Set<string> {
    return new Set(this.draft)
  }

  aboutToAppear(): void {
    this.draft = this.initialTags.slice()
  }

  @Computed
  get sectionLabel(): string {
    const label: string = ResUtil.getStringSync($r('app.string.tag_filter_section_label'))
    return `${label} · ${this.tags.length}`
  }

  private toggle(tag: string): void {
    this.draft = this.draft.includes(tag)
      ? this.draft.filter((item: string) => item !== tag)
      : this.draft.concat(tag)
  }

  @Builder
  private chips() {
    Flex({ wrap: FlexWrap.Wrap, space: { main: CHIP_GAP, cross: CHIP_GAP } }) {
      ForEach(this.tags, (option: VaultTagOption) => {
        DsTag({
          tagSize: DsTagSize.Medium,
          text: option.tag,
          interactive: true,
          selected: this.selectedSet.has(option.tag),
          onTap: () => this.toggle(option.tag),
        })
      }, (option: VaultTagOption) => option.tag)
    }
    .width('100%')
  }

  @LocalBuilder
  private bodyContent() {
    Column({ space: $r('app.float.ds_space_16') }) {
      Text(this.sectionLabel)
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_tertiary'))

      if (this.tags.length === 0) {
        DsNotice({ tone: DsNoticeTone.Default, title: $r('app.string.tag_filter_empty') })
      } else {
        this.chips()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
      top: $r('app.float.ds_space_sm'),
      bottom: this.footerHeight,
    })
  }

  @LocalBuilder
  private actions() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      Row() {
        DsButton({
          label: $r('app.string.tag_filter_reset'),
          variant: DsButtonVariant.Filled,
          tone: DsButtonTone.Default,
          buttonSize: DsControlSize.Medium,
          fullWidth: true,
          onTap: () => {
            this.draft = []
          },
        })
      }
      .layoutWeight(1)

      Row() {
        DsButton({
          label: $r('app.string.tag_filter_apply'),
          variant: DsButtonVariant.Filled,
          tone: DsButtonTone.Primary,
          buttonSize: DsControlSize.Medium,
          fullWidth: true,
          onTap: () => this.onApply(this.draft.slice()),
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }

  @LocalBuilder
  private footerBar() {
    DsBottomActionBar({
      surfaceColor: $r('app.color.ds_surface_lowest'),
      fadeColor: $r('app.color.ds_surface_lowest_transparent'),
      contentBuilder: this.actions,
      onHeightChange: (height: number) => {
        this.footerHeight = height
      },
    })
  }

  build() {
    DsHalfModalSheet({
      title: $r('app.string.tag_filter_sheet_title'),
      // 高度由宿主按内容算好且不可拖拽，不画拖拽条。
      showHandle: false,
      onClose: () => this.onClose(),
      bodyBuilder: this.bodyContent,
      bottomBarBuilder: this.footerBar,
    })
  }
}
