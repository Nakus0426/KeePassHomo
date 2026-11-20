import { LengthMetrics } from '@kit.ArkUI'
import { AnimationTokens } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { EntryEditorViewModel, TagAddResult } from '../../viewmodel/EntryEditorViewModel'
import { DsTag, DsTagSize } from '../../components/DsTag'
import { DsToastHost } from '../../components/DsToast'

const TAG_INPUT_ID: string = 'entry_tag_input'
// 输入井最小宽度按标签字号的 10 倍，与设计稿一致。
const TAG_INPUT_CHARS: number = 10
// 标签过长会顶掉尾部 ×，超出即截断。
const TAG_LABEL_MAX_CHARS: number = 200

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

  @Monitor('active')
  onActiveChanged(): void {
    if (!this.active) {
      this.closeInput()
    }
  }

  @Computed
  get tagGap(): number {
    return this.getUIContext().px2vp(ResUtil.getNumber($r('app.float.ds_space_sm').id))
  }

  @Computed
  get tagFontSize(): number {
    return this.getUIContext().px2vp(ResUtil.getNumber($r('app.float.ds_font_label_md').id))
  }

  @Computed
  get inputWidth(): number {
    return this.tagFontSize * TAG_INPUT_CHARS
  }

  @Computed
  get chipHeight(): number {
    const padY: number = this.getUIContext().px2vp(ResUtil.getNumber($r('app.float.ds_space_3').id))
    const lineHeight: number = this.getUIContext().px2vp(ResUtil.getNumber($r('app.float.ds_line_height_micro').id))
    return padY * 2 + lineHeight
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
      this.onActivity()
      this.closeInput()
      return
    }
    this.invalid = true
    DsToastHost.show(this.getUIContext(), result === TagAddResult.Duplicate
      ? $r('app.string.tag_duplicate') : $r('app.string.tag_separator_forbidden'))
  }

  private remove(tag: string): void {
    this.editor.removeTag(tag)
    this.onActivity()
  }

  @LocalBuilder
  private tagContent(tag: string) {
    Row({ space: $r('app.float.ds_space_xs') }) {
      Text(tag.length > TAG_LABEL_MAX_CHARS ? `${tag.slice(0, TAG_LABEL_MAX_CHARS)}…` : tag)
        .fontSize($r('app.float.ds_font_label_md'))
        .fontWeight(600)
        .letterSpacing($r('app.float.ds_tracking_wide_md'))
        .fontColor($r('app.color.ds_text_primary'))
        .maxLines(1)

      Row() {
        SymbolGlyph($r('app.string.symbol_close'))
          .fontSize($r('app.float.ds_font_label_sm'))
          .fontColor([$r('app.color.ds_text_secondary')])
          .foregroundColor($r('app.color.ds_text_secondary'))
      }
      .width($r('app.float.ds_font_label_md'))
      .height($r('app.float.ds_font_label_md'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => this.remove(tag))
    }
  }

  @LocalBuilder
  private tagChip(tag: string, index: number) {
    DsTag({
      tagSize: DsTagSize.Medium,
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

  @LocalBuilder
  private addButton() {
    Row() {
      SymbolGlyph($r('app.string.symbol_add'))
        .fontSize($r('app.float.ds_font_label_sm'))
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
      TextInput({ placeholder: $r('app.string.add_tag'), text: this.draft })
        .id(TAG_INPUT_ID)
        .enterKeyType(EnterKeyType.Done)
        .fontSize($r('app.float.ds_font_label_md'))
        .fontWeight(600)
        .letterSpacing($r('app.float.ds_tracking_wide_md'))
        .fontColor($r('app.color.ds_text_primary'))
        .caretColor($r('app.color.ds_primary'))
        .padding(0)
        .height('100%')
        .layoutWeight(1)
        .backgroundColor(Color.Transparent)
        .onAppear(() => this.getUIContext().getFocusController().requestFocus(TAG_INPUT_ID))
        .onChange((value: string) => {
          this.draft = value
          this.invalid = false
        })
        .onSubmit(() => this.commit())
        .onBlur(() => this.commit())
    }
    .width(this.inputWidth)
    .height(this.chipHeight)
    .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })
    .backgroundColor($r('app.color.ds_surface_canvas'))
    .border({
      width: $r('app.float.ds_border_width'),
      color: this.invalid ? $r('app.color.ds_error') : $r('app.color.ds_primary'),
    })
    .animation(AnimationTokens.FEEDBACK_ANIMATION)
  }

  build() {
    Flex({
      wrap: FlexWrap.Wrap,
      space: { main: LengthMetrics.vp(this.tagGap), cross: LengthMetrics.vp(this.tagGap) },
    }) {
      ForEach(this.editor.tags, (tag: string, index: number) => {
        if (this.editingIndex === index) {
          this.tagInput()
        } else {
          this.tagChip(tag, index)
        }
      }, (tag: string, index: number) => `${index}_${tag}`)

      if (this.editingIndex === this.editor.tags.length) {
        this.tagInput()
      } else if (!this.readOnly) {
        this.addButton()
      }
    }
    .width('100%')
  }
}
