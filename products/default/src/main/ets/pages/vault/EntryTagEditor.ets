import {
  ChipV2,
  ChipV2Label,
  ChipV2Options,
  ChipV2PrefixSymbolIcon,
  LengthMetrics,
  SymbolGlyphModifier,
} from '@kit.ArkUI'
import { AnimationTokens, AppToast } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { EntryEditorViewModel, TagAddResult } from '../../viewmodel/EntryEditorViewModel'

const TAG_INPUT_ID: string = 'entry_tag_input'
/** 标签输入态宽度：按 chip 字号的 10 个字符估算，与 VaultTabChrome 的 chip 文案宽度算法一致。 */
const TAG_INPUT_CHARS: number = 10

/**
 * 标签编辑器：chip 列表 + 行内输入。
 * 输入态、草稿与拒绝提示都封在这里，宿主只在标签实际变化时刷新活跃时间。
 */
@ComponentV2
export struct EntryTagEditor {
  @Param editor: EntryEditorViewModel = new EntryEditorViewModel()
  @Param readOnly: boolean = false
  /** 宿主编辑会话是否打开：会话关闭时丢弃未提交的草稿与输入态。 */
  @Param active: boolean = false
  @Event onActivity: () => void = () => {
  }
  @Local private editing: boolean = false
  @Local private draft: string = ''
  @Local private warning: boolean = false

  @Monitor('active')
  onActiveChanged(): void {
    if (!this.active) {
      this.closeInput()
    }
  }

  @Computed
  get tagGap(): number {
    return this.getUIContext().px2vp(ResUtil.getNumber($r('sys.float.padding_level8').id))
  }

  @Computed
  get inputWidth(): number {
    const fontSize: number = ResUtil.getNumber($r('sys.float.chip_normal_font_size').id)
    return this.getUIContext().px2vp(fontSize) * TAG_INPUT_CHARS
  }

  private openInput(): void {
    this.draft = ''
    this.warning = false
    this.editing = true
  }

  private closeInput(): void {
    this.editing = false
    this.draft = ''
    this.warning = false
  }

  private commit(): void {
    const value: string = this.draft.trim()
    if (value.length === 0) {
      this.closeInput()
      return
    }
    const result: TagAddResult = this.editor.addTag(value)
    if (result === TagAddResult.Added) {
      this.onActivity()
      this.closeInput()
      return
    }
    this.warning = true
    // 标签编辑在条目编辑半模态内，默认模式提示会被半模态压住。
    AppToast.showAboveSheets(this.getUIContext(), result === TagAddResult.Duplicate
      ? $r('app.string.tag_duplicate') : $r('app.string.tag_separator_forbidden'))
  }

  private remove(tag: string): void {
    this.editor.removeTag(tag)
    this.onActivity()
  }

  build() {
    Flex({
      wrap: FlexWrap.Wrap,
      space: { main: LengthMetrics.vp(this.tagGap), cross: LengthMetrics.vp(this.tagGap) },
    }) {
      ForEach(this.editor.tags, (tag: string) => {
        ChipV2({
          chipV2Options: new ChipV2Options({
            label: new ChipV2Label({ text: tag }),
            allowClose: !this.readOnly,
            onClose: () => this.remove(tag),
          }),
        })
      }, (tag: string) => tag)

      if (!this.readOnly && !this.editing) {
        ChipV2({
          chipV2Options: new ChipV2Options({
            prefixIcon: new ChipV2PrefixSymbolIcon({ normal: new SymbolGlyphModifier($r('sys.symbol.plus')) }),
            label: new ChipV2Label({ text: ResUtil.getStringSync($r('app.string.add_tag')) }),
            allowClose: false,
            onClicked: () => this.openInput(),
          }),
        })
      }

      if (this.editing) {
        Row() {
          TextInput({ placeholder: $r('app.string.text_input_placeholder'), text: this.draft })
            .id(TAG_INPUT_ID)
            .enterKeyType(EnterKeyType.Done)
            .fontSize($r('sys.float.chip_normal_font_size'))
            .padding(0)
            .height('100%')
            .layoutWeight(1)
            .backgroundColor(Color.Transparent)
            .onAppear(() => this.getUIContext().getFocusController().requestFocus(TAG_INPUT_ID))
            .onChange((value: string) => {
              this.draft = value
              this.warning = false
            })
            .onSubmit(() => this.commit())
            .onBlur(() => this.commit())
        }
        .width(this.inputWidth)
        .height($r('sys.float.chip_normal_height'))
        .padding({
          left: $r('sys.float.chip_normal_text_padding'),
          right: $r('sys.float.chip_normal_text_padding'),
        })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius($r('sys.float.chip_border_radius_normal'))
        .border({
          width: $r('sys.float.border_width'),
          color: this.warning ? $r('sys.color.warning') : $r('sys.color.brand'),
        })
        .animation({
          duration: AnimationTokens.STATE_TRANSITION_DURATION,
          curve: AnimationTokens.STATE_TRANSITION_CURVE,
        })
      }
    }
    .width('100%')
  }
}
