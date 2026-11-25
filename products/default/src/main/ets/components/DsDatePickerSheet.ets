import { UIContext } from '@kit.ArkUI'
import { immersiveLayoutState } from '../state/ImmersiveLayoutState'
import { DsBottomActionBar } from './DsBottomActionBar'
import { DsButton, DsButtonTone, DsButtonVariant } from './DsButton'
import { DsHalfModalSheet } from './DsHalfModalSheet'

// 设计稿三档滚轮文本：边缘 14、邻近 16、选中 20/600。
const PICKER_EDGE_FONT_SIZE: number = 14
const PICKER_TEXT_FONT_SIZE: number = 16
const PICKER_SELECTED_FONT_SIZE: number = 20
const PICKER_HEIGHT: number = 180
const TIME_PICKER_WIDTH: number = 110
// 面板高度按内容取：拖拽行 16 + 标题栏 56 + 滚动区 24+180+24 + 底栏 72。
const DS_DATE_PICKER_SHEET_HEIGHT: number = 372

// 底栏已避让系统安全区，面板高度要把这段一并计入，否则按钮会沉到手势条下方。
export function dsDatePickerSheetHeight(uiContext: UIContext): number {
  return DS_DATE_PICKER_SHEET_HEIGHT + uiContext.px2vp(immersiveLayoutState.bottomAvoidAreaHeightPx)
}

export enum DsDatePickerMode {
  YearMonth = 'yearMonth',
  Date = 'date',
  DateTime = 'dateTime',
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`
}

// 组件统一以字符串进出：年月 YYYY-MM、日期 YYYY-MM-DD、日期时间 YYYY-MM-DD HH:mm。
export function dsFormatDateValue(mode: DsDatePickerMode, date: Date): string {
  const day: string = `${date.getFullYear()}-${pad2(date.getMonth() + 1)}`
  if (mode === DsDatePickerMode.YearMonth) {
    return day
  }
  const withDay: string = `${day}-${pad2(date.getDate())}`
  if (mode === DsDatePickerMode.Date) {
    return withDay
  }
  return `${withDay} ${pad2(date.getHours())}:${pad2(date.getMinutes())}`
}

// 解析失败返回 undefined，由调用方决定回退到今天还是保留原值。
export function dsParseDateValue(mode: DsDatePickerMode, value: string): Date | undefined {
  const match: RegExpMatchArray | null = value.trim().match(
    /^(\d{4})-(\d{2})(?:-(\d{2}))?(?:[ T](\d{2}):(\d{2}))?$/)
  if (match === null) {
    return undefined
  }
  const year: number = Number(match[1])
  const month: number = Number(match[2]) - 1
  if (mode === DsDatePickerMode.YearMonth) {
    return new Date(year, month, 1)
  }
  const day: number = match[3] === undefined ? 1 : Number(match[3])
  if (mode === DsDatePickerMode.Date) {
    return new Date(year, month, day)
  }
  return new Date(year, month, day, Number(match[4] ?? 0), Number(match[5] ?? 0))
}

@ComponentV2
export struct DsDatePickerSheet {
  @Param mode: DsDatePickerMode = DsDatePickerMode.Date
  // 当前值；无法解析时退回今天，不影响字段里的原文本。
  @Param value: string = ''
  @Param pickerTitle: ResourceStr = ''
  @Param minDate: Date = new Date(1970, 0, 1)
  @Param maxDate: Date = new Date(2100, 11, 31)
  @Event onConfirm: (value: string) => void = () => {
  }
  @Event onClose: () => void = () => {
  }
  @Event onActivity: () => void = () => {
  }
  @Local private selected: Date = new Date()
  @Local private time: Date = new Date()

  // 半模态内容可能复用，重新打开时按字段当前值归位。
  @Monitor('value')
  onValueChanged(): void {
    this.resetSelection()
  }

  aboutToAppear(): void {
    this.resetSelection()
  }

  private resetSelection(): void {
    const parsed: Date | undefined = dsParseDateValue(this.mode, this.value)
    const initial: Date = parsed ?? new Date()
    this.selected = initial
    this.time = initial
  }

  private handleDateChange(date: Date): void {
    this.selected = date
    if (this.mode === DsDatePickerMode.DateTime) {
      const merged: Date = new Date(date.getFullYear(), date.getMonth(), date.getDate(),
        this.time.getHours(), this.time.getMinutes())
      this.selected = merged
    }
    this.onActivity()
  }

  private handleTimeChange(result: TimePickerResult): void {
    const time: Date = new Date(this.selected.getFullYear(), this.selected.getMonth(), this.selected.getDate(),
      result.hour, result.minute)
    this.time = time
    this.selected = time
    this.onActivity()
  }

  private confirm(): void {
    const value: Date = this.mode === DsDatePickerMode.DateTime
      ? new Date(this.selected.getFullYear(), this.selected.getMonth(), this.selected.getDate(),
        this.time.getHours(), this.time.getMinutes())
      : this.selected
    this.onConfirm(dsFormatDateValue(this.mode, value))
  }

  @LocalBuilder
  private dateWheel() {
    DatePicker({
      start: this.minDate,
      end: this.maxDate,
      selected: this.selected,
      mode: this.mode === DsDatePickerMode.YearMonth ? DatePickerMode.YEAR_AND_MONTH : DatePickerMode.DATE,
    })
      .width('100%')
      .height(PICKER_HEIGHT)
      .disappearTextStyle({
        color: $r('app.color.ds_text_tertiary'),
        font: { size: PICKER_EDGE_FONT_SIZE },
      })
      .textStyle({
        color: $r('app.color.ds_text_secondary'),
        font: { size: PICKER_TEXT_FONT_SIZE },
      })
      .selectedTextStyle({
        color: $r('app.color.ds_text_primary'),
        font: { size: PICKER_SELECTED_FONT_SIZE, weight: 600 },
      })
      .onDateChange((value: Date) => this.handleDateChange(value))
  }

  @LocalBuilder
  private timeWheel() {
    TimePicker({ selected: this.time })
      .useMilitaryTime(true)
      .width(TIME_PICKER_WIDTH)
      .height(PICKER_HEIGHT)
      .disappearTextStyle({
        color: $r('app.color.ds_text_tertiary'),
        font: { size: PICKER_EDGE_FONT_SIZE },
      })
      .textStyle({
        color: $r('app.color.ds_text_secondary'),
        font: { size: PICKER_TEXT_FONT_SIZE },
      })
      .selectedTextStyle({
        color: $r('app.color.ds_text_primary'),
        font: { size: PICKER_SELECTED_FONT_SIZE, weight: 600 },
      })
      .onChange((value: TimePickerResult) => this.handleTimeChange(value))
  }

  // 内容高度固定且不需要滚动：不放滚动容器，避免滚轮之外再叠一层回弹。
  @LocalBuilder
  private bodyContent() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      Column() {
        this.dateWheel()
      }
      .layoutWeight(1)

      if (this.mode === DsDatePickerMode.DateTime) {
        this.timeWheel()
      }
    }
    .width('100%')
    .padding({
      top: $r('app.float.ds_space_24'),
      bottom: $r('app.float.ds_space_24'),
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onTouch(() => this.onActivity())
  }

  @LocalBuilder
  private bottomBarContent() {
    DsButton({
      label: $r('app.string.confirm'),
      variant: DsButtonVariant.Filled,
      tone: DsButtonTone.Primary,
      fullWidth: true,
      onTap: () => this.confirm(),
    })
  }

  @LocalBuilder
  private bottomBar() {
    DsBottomActionBar({
      contentBuilder: this.bottomBarContent,
    })
  }

  build() {
    DsHalfModalSheet({
      title: this.pickerTitle,
      onClose: () => this.onClose(),
      bodyBuilder: this.bodyContent,
      bottomBarBuilder: this.bottomBar,
    })
  }
}
