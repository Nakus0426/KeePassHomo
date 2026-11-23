import { LengthMetrics, UIContext } from '@kit.ArkUI'
import { AnimationTokens, measureVp } from '@ohos/common'
import { EntryEditorViewModel, TagAddResult } from '../../viewmodel/EntryEditorViewModel'
import { dsTagMetrics, DsTag, DsTagSize, TagMetrics } from '../../components/DsTag'
import { DsInput, DsInputVariant } from '../../components/DsInput'
import { DsToastHost } from '../../components/DsToast'

const TAG_INPUT_ID: string = 'entry_tag_input'
// 输入井最小宽度按标签字号的 10 倍，与设计稿一致。
const TAG_INPUT_CHARS: number = 10
// 标签过长会顶掉尾部 ×，超出即截断。
const TAG_LABEL_MAX_CHARS: number = 200
// 标签在换行流里，只做透明度 + 4vp 位移；缩放或改宽会让同一行的标签跟着抖动。
const TAG_ENTER_OFFSET: number = 4
const TAG_ENTER_TRANSITION: TransitionEffect = TransitionEffect.OPACITY
  .combine(TransitionEffect.translate({ y: TAG_ENTER_OFFSET }))
  .animation(AnimationTokens.FEEDBACK_ANIMATION)

// 可编辑标签：点标签改名、点 × 删除、点 + 追加，同一时刻只有一个输入井。
@ComponentV2
export struct EntryTagEditor {
  @Param editor: EntryEditorViewModel = new EntryEditorViewModel()
  @Param readOnly: boolean = false
  // 宿主编辑会话是否打开：会话关闭时丢弃未提交的草稿与输入态。
  @Param active: boolean = false
  @Event onActivity: () => void = () => {
  }
  // -1 表示未在编辑；否则为被替换的标签下标，等于标签数时表示新增。
  @Local private editingIndex: number = -1
  @Local private draft: string = ''
  @Local private invalid: boolean = false
  // 正在离场的标签：淡出结束后才删数据，避免半透明标签先跳位。
  @Local private leavingTag: string = ''
  // 进场动画只给刚新增/改名的标签：其余标签若因删改重挂，不会重播淡入。
  @Local private enteringTags: Set<string> = new Set()
  // 每个槽位的实测宽度（含右侧间距）：离场时从实测值收到 0，同行标签才会跟着平滑左移。
  @Local private slotWidths: Map<string, number> = new Map()
  // 首帧宽度估算不参与界面失效：只读缓存，写它不需要触发重排。
  private readonly estimatedWidths: Map<string, number> = new Map()
  // 与 DsTag 同一份几何：输入井与 × 方块必须与标签同高。
  private readonly metrics: TagMetrics = dsTagMetrics(DsTagSize.Medium)

  @Monitor('active')
  onActiveChanged(): void {
    if (!this.active) {
      this.closeInput()
      this.leavingTag = ''
    }
  }

  @Computed
  get tagGap(): number {
    return measureVp(this.getUIContext(), $r('app.float.ds_space_sm'))
  }

  @Computed
  get tagFontSize(): number {
    return measureVp(this.getUIContext(), this.metrics.fontSize)
  }

  @Computed
  get inputWidth(): number {
    return this.tagFontSize * TAG_INPUT_CHARS
  }

  @Computed
  get chipHeight(): number {
    return measureVp(this.getUIContext(), this.metrics.padVertical) * 2 + this.metrics.lineHeight
  }

  private openInput(index: number): void {
    this.draft = index < this.editor.tags.length ? this.editor.tags[index] : ''
    this.invalid = false
    this.editingIndex = index
  }

  private closeInput(): void {
    this.editingIndex = -1
    this.draft = ''
    this.invalid = false
  }

  private commit(): void {
    const value: string = this.draft.trim()
    const index: number = this.editingIndex
    if (index < 0) {
      return
    }
    if (value.length === 0) {
      this.closeInput()
      return
    }
    const result: TagAddResult = index < this.editor.tags.length
      ? this.editor.renameTag(this.editor.tags[index], value)
      : this.editor.addTag(value)
    if (result === TagAddResult.Added) {
      this.markEntering(value)
      this.onActivity()
      this.closeInput()
      return
    }
    this.invalid = true
    DsToastHost.show(this.getUIContext(), result === TagAddResult.Duplicate
      ? $r('app.string.tag_duplicate') : $r('app.string.tag_separator_forbidden'))
  }

  // 进场动画的开关只保留一个动画周期：之后的删改重挂不再播放。
  private markEntering(tag: string): void {
    const next: Set<string> = new Set(this.enteringTags)
    next.add(tag)
    this.enteringTags = next
    setTimeout(() => {
      if (!this.enteringTags.has(tag)) {
        return
      }
      const cleared: Set<string> = new Set(this.enteringTags)
      cleared.delete(tag)
      this.enteringTags = cleared
    }, AnimationTokens.DURATION_FEEDBACK + 100)
  }

  private remove(tag: string): void {
    if (this.leavingTag !== '') {
      return
    }
    // 收窄用减速曲线：EASE_EXIT 末段在加速，收起时会「啪」地合上；减速到静止才有回弹后的安定感。
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.EASE_STATE,
      onFinish: () => {
        if (this.leavingTag !== tag) {
          return
        }
        this.editor.removeTag(tag)
        const widths: Map<string, number> = new Map(this.slotWidths)
        widths.delete(tag)
        this.slotWidths = widths
        this.estimatedWidths.delete(tag)
        this.leavingTag = ''
        this.onActivity()
      },
    }, () => {
      this.leavingTag = tag
    })
  }

  @LocalBuilder
  private tagContent(tag: string) {
    Row({ space: this.metrics.gap }) {
      Text(this.displayedTag(tag))
        .fontSize(this.metrics.fontSize)
        .fontWeight(600)
        .letterSpacing($r('app.float.ds_tracking_wide_md'))
        .lineHeight(this.metrics.lineHeight)
        .fontColor($r('app.color.ds_text_primary'))
        .maxLines(1)

      // 字形自身的行盒高于字形，容器给足整行高才与文字基线对齐；给字号高度会把它顶到偏上。
      Row() {
        SymbolGlyph($r('app.string.symbol_close'))
          .fontSize(this.metrics.fontSize)
          .fontColor([$r('app.color.ds_text_secondary')])
          .foregroundColor($r('app.color.ds_text_secondary'))
      }
      .width(this.metrics.fontSize)
      .height(this.metrics.lineHeight)
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => this.remove(tag))
    }
    .alignItems(VerticalAlign.Center)
  }

  private displayedTag(tag: string): string {
    return tag.length > TAG_LABEL_MAX_CHARS ? `${tag.slice(0, TAG_LABEL_MAX_CHARS)}…` : tag
  }

  // 首帧还没有实测值：按同一套字号与字距先量出槽宽，之后 width 一直是数值，才能逐帧插值。
  // 结果按标签缓存：每次写入 slotWidths 都会让所有槽位重算 width，不缓存就重复塑形文本。
  private estimateSlotWidth(tag: string): number {
    const cached: number | undefined = this.estimatedWidths.get(tag)
    if (cached !== undefined) {
      return cached
    }
    const ui: UIContext = this.getUIContext()
    const textWidth: number = ui.px2vp(ui.getMeasureUtils().measureText({
      textContent: this.displayedTag(tag),
      fontSize: this.metrics.fontSize,
      fontWeight: 600,
      letterSpacing: measureVp(ui, $r('app.float.ds_tracking_wide_md')),
    }))
    const padX: number = measureVp(ui, this.metrics.padHorizontal)
    const gap: number = measureVp(ui, this.metrics.gap)
    // 布局按整数像素取整，多留 1vp 保证首帧槽宽不小于实际字形宽。
    const width: number = textWidth + padX * 2 + gap + this.tagFontSize + this.tagGap + 1
    this.estimatedWidths.set(tag, width)
    return width
  }

  private slotWidth(tag: string): number {
    if (this.leavingTag === tag) {
      return 0
    }
    const measured: number | undefined = this.slotWidths.get(tag)
    return measured !== undefined ? measured : this.estimateSlotWidth(tag)
  }

  @LocalBuilder
  private tagChip(tag: string, index: number) {
    DsTag({
      contentBuilder: () => {
        this.tagContent(tag)
      },
    })
      .onClick(() => {
        if (!this.readOnly) {
          this.openInput(index)
        }
      })
  }

  // 槽位承担动画：离场时实测宽度收到 0 且淡出，同一行的标签才会跟着平滑左移；
  // 组件本身不重挂，避免剩余标签重播进场。
  @LocalBuilder
  private tagSlot(tag: string, index: number) {
    Row() {
      // 间距放在内层：外层若带 padding，宽度收到 0 时也会被 padding 撑住，最小的那几 vp 会留到删除时才跳掉。
      Row() {
        this.tagChip(tag, index)
      }
      .padding({ right: this.tagGap })
    }
    .clip(this.leavingTag === tag)
    // width 是 ArkUI 会逐帧插值的布局属性；constraintSize 不会，收到 0 只能整段跳变。
    .width(this.slotWidth(tag))
    .opacity(this.leavingTag === tag ? 0 : 1)
    .transition(this.enteringTags.has(tag) ? TAG_ENTER_TRANSITION : TransitionEffect.IDENTITY)
    .onAreaChange((_old: Area, area: Area) => {
      const width: number = Number(area.width)
      if (this.leavingTag === tag) {
        return
      }
      if (width > 0 && Math.abs((this.slotWidths.get(tag) ?? -1) - width) > 0.5) {
        const next: Map<string, number> = new Map(this.slotWidths)
        next.set(tag, width)
        this.slotWidths = next
      }
    })
  }

  @LocalBuilder
  private addButton() {
    Row() {
      SymbolGlyph($r('app.string.symbol_add'))
        .fontSize(this.metrics.fontSize)
        .fontColor([$r('app.color.ds_text_secondary')])
        .foregroundColor($r('app.color.ds_text_secondary'))
    }
    .width(this.chipHeight)
    .height(this.chipHeight)
    .backgroundColor($r('app.color.ds_surface_low'))
    .borderRadius($r('app.float.ds_radius_none'))
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => this.openInput(this.editor.tags.length))
  }

  @LocalBuilder
  private tagInput() {
    Row() {
      // 与字段卡就地编辑同一实现：DsInput 内部已归零圆角、锁行高并单独设 placeholderFont，
      // 直接手写 TextInput 会吃到平台默认圆角与行高，光标被输入井裁掉。
      DsInput({
        text: this.draft,
        placeholder: $r('app.string.add_tag'),
        variant: DsInputVariant.Inline,
        fontSizeOverride: this.metrics.fontSize,
        fontWeightOverride: 600,
        lineHeightOverride: this.metrics.lineHeight,
        focusKey: TAG_INPUT_ID,
        autoFocus: true,
        enterKeyType: EnterKeyType.Done,
        onChange: (value: string) => {
          this.draft = value
          this.invalid = false
        },
        onSubmit: () => this.commit(),
        onFocusChange: (focused: boolean) => {
          if (!focused) {
            this.commit()
          }
        },
      })
        .layoutWeight(1)
    }
    .width(this.inputWidth)
    .height(this.chipHeight)
    .padding({ left: this.metrics.padHorizontal, right: this.metrics.padHorizontal })
    .alignItems(VerticalAlign.Center)
    .backgroundColor($r('app.color.ds_surface_canvas'))
    .border({
      width: $r('app.float.ds_border_width'),
      color: this.invalid ? $r('app.color.ds_error') : $r('app.color.ds_primary'),
    })
    .animation(AnimationTokens.FEEDBACK_ANIMATION)
  }

  // 输入井与 + 也走槽位：行内间距统一由槽位右内距给出，收起时才能连间距一起收掉。
  @LocalBuilder
  private inputSlot() {
    Row() {
      this.tagInput()
    }
    .padding({ right: this.tagGap })
  }

  @LocalBuilder
  private addSlot() {
    Row() {
      this.addButton()
    }
    .padding({ right: this.tagGap })
  }

  build() {
    Flex({
      wrap: FlexWrap.Wrap,
      space: { main: LengthMetrics.vp(0), cross: LengthMetrics.vp(this.tagGap) },
    }) {
      ForEach(this.editor.tags, (tag: string, index: number) => {
        if (this.editingIndex === index) {
          this.inputSlot()
        } else {
          this.tagSlot(tag, index)
        }
      }, (tag: string) => tag)

      if (this.editingIndex === this.editor.tags.length) {
        this.inputSlot()
      } else if (!this.readOnly) {
        this.addSlot()
      }
    }
    .width('100%')
  }
}
