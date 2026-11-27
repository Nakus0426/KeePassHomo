import { LengthMetrics } from '@kit.ArkUI'
import { AnimationTokens, VaultFieldType } from '@ohos/common'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { AppSessionState, appSessionState } from '../../state/AppSessionState'
import { ENTRY_FIELD_CARD_NUMBER, PASSWORD_MASK } from '../../viewmodel/EntryPresentation'
import {
  EntryPreviewField, EntrySheetMode, EntrySheetViewModel, entrySheetViewModel,
} from '../../viewmodel/EntrySheetViewModel'
import { EntryAvatar } from '../../components/EntryAvatar'
import { DsTag, DsTagSize } from '../../components/DsTag'
import { fieldTypeDefinition } from '../../model/FieldTypeCatalog'
import { EntryAttachmentList } from './EntryAttachmentList'
import { EntryPreviewBankCard } from './EntryPreviewBankCard'
import { EntrySshKeyList } from './EntrySshKeyList'
import { DeferredAction } from '../../components/DeferredAction'
import { DsButton, DsButtonVariant } from '../../components/DsButton'
import { DsContextMenu, dsContextMenuOptions } from '../../components/DsContextMenu'
import { DsControlSize } from '../../components/DsControlSize'
import { DsMenuGroup } from '../../components/DsMenuGroup'
import { DsMenuItem } from '../../components/DsMenuItem'
import { DsToastHost } from '../../components/DsToast'
import { PASSWORD_FONT_FAMILY } from '../../constants/FontConstants'

const PREVIEW_REVEAL_SECONDS: number = 30
const PROTECTION_TICK_MS: number = AnimationTokens.DURATION_FEEDBACK
const MAX_TEXT_LINES: number = 2147483647

@ObservedV2
class EntryPreviewProtection {
  @Trace revealed: boolean = false
  @Trace remainingSeconds: number = 0
  expiresAt: number = 0
}

@Extend(Text)
function previewValueStyle(fontFamily: string, maxLines: number) {
  .width('100%')
  .fontSize($r('app.float.ds_font_title'))
  .lineHeight($r('app.float.ds_entry_preview_value_line_height'))
  .fontWeight(600)
  .fontFamily(fontFamily)
  .fontFeature('"tnum" 1')
  .fontColor($r('app.color.ds_text_primary'))
  .maxLines(maxLines)
  .textOverflow({ overflow: TextOverflow.Ellipsis })
  .wordBreak(WordBreak.BREAK_ALL)
}

@ComponentV2
struct EntryPreviewFieldCard {
  @Param @Require field: EntryPreviewField
  @Param maskedValue: string = PASSWORD_MASK
  @Param protection: EntryPreviewProtection | undefined = undefined
  @Param expanded: boolean = false
  @Event onCopy: (field: EntryPreviewField) => void = (_field: EntryPreviewField) => {}
  @Event onOpen: (field: EntryPreviewField) => void = (_field: EntryPreviewField) => {}
  @Event onReveal: () => void = () => {}
  @Event onExpand: () => void = () => {}
  @Local private valueWidth: number = 0
  @Local private singleLineHeight: number = 0
  @Local private fullTextHeight: number = 0
  private readonly deferred: DeferredAction = new DeferredAction()

  @Computed
  get isLink(): boolean {
    return !this.field.protectedValue && this.field.type === VaultFieldType.Url
  }

  @Computed
  private get isPasswordField(): boolean {
    return this.field.protectedValue && this.field.type === VaultFieldType.Password &&
      this.field.key !== ENTRY_FIELD_CARD_NUMBER
  }

  @Computed
  get expandable(): boolean {
    if (this.field.protectedValue || this.isLink || this.field.value.length === 0) {
      return false
    }
    if (this.field.value.includes('\n')) {
      return true
    }
    if (this.valueWidth <= 0) {
      return false
    }
    const context: UIContext = this.getUIContext()
    const textWidth: number = context.getMeasureUtils().measureText({
      textContent: this.field.value,
      fontSize: $r('app.float.ds_font_title'),
      fontWeight: 600,
    })
    return textWidth > context.vp2px(this.valueWidth)
  }

  @Computed
  private get revealed(): boolean {
    return this.protection?.revealed === true
  }

  @Computed
  get displayValue(): string {
    const text: string = this.field.value
    if (text.length === 0) {
      return ' '
    }
    if (this.field.protectedValue && !this.revealed) {
      return this.maskedValue
    }
    const newline: number = text.indexOf('\n')
    if (newline < 0) {
      return text
    }
    return text.substring(0, text[newline - 1] === '\r' ? newline - 1 : newline)
  }

  @Computed
  private get valueViewportHeight(): Length {
    if (this.expanded && this.fullTextHeight > 0) {
      return this.fullTextHeight
    }
    return this.singleLineHeight || $r('app.float.ds_entry_preview_value_line_height')
  }

  @Computed
  get expandLabel(): Resource {
    return this.expanded ? $r('app.string.entry_preview_collapse') : $r('app.string.entry_preview_expand')
  }

  @Computed
  get expandIcon(): Resource {
    return this.expanded ? $r('app.string.symbol_chevron_up') : $r('app.string.symbol_chevron_down')
  }

  @Computed
  get copyLabel(): Resource {
    if (this.isPasswordField) {
      return $r('app.string.entry_menu_copy_password')
    }
    if (this.isLink) {
      return $r('app.string.entry_preview_copy_url')
    }
    return this.expandable ? $r('app.string.entry_preview_copy_content') : $r('app.string.copy_field_value')
  }

  private quickAction(): void {
    if (this.isLink) {
      this.onOpen(this.field)
    } else if (this.expandable) {
      this.toggleExpanded()
    } else {
      this.onCopy(this.field)
    }
  }

  private toggleExpanded(): void {
    this.getUIContext().animateTo(AnimationTokens.FEEDBACK_ANIMATION, () => this.onExpand())
  }

  @Computed
  private get fieldMenuOptions(): ContextMenuOptions {
    const options: ContextMenuOptions = dsContextMenuOptions(() => this.deferred.run(), Placement.BottomRight)
    // 菜单截图不会随倒计时更新，明文状态下禁用截图预览。
    if (this.revealed) {
      options.preview = MenuPreviewMode.NONE
    }
    return options
  }

  @LocalBuilder
  private menuHeader() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      Text(this.field.label)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .fontSize($r('app.float.ds_font_body'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))
      DsTag({ tagSize: DsTagSize.Small, text: fieldTypeDefinition(this.field.type).label })
    }
    .width('100%')
    .padding({
      top: $r('app.float.ds_space_md'), bottom: $r('app.float.ds_space_md'),
      left: $r('app.float.ds_gutter'), right: $r('app.float.ds_gutter'),
    })
    .backgroundColor($r('app.color.ds_surface_low'))
  }

  @LocalBuilder
  private menuItems() {
    DsMenuItem({ icon: $r('app.string.symbol_copy'), label: this.copyLabel, onAction: () => this.onCopy(this.field) })
    if (this.field.protectedValue) {
      DsMenuItem({
        icon: this.revealed ? $r('app.string.symbol_eye_off') : $r('app.string.symbol_eye'),
        label: this.isPasswordField
          ? (this.revealed ? $r('app.string.hide_password') : $r('app.string.show_password'))
          : (this.revealed ? $r('app.string.hide') : $r('app.string.show')),
        onAction: () => this.deferred.defer(() => this.onReveal()),
      })
    } else if (this.isLink) {
      DsMenuItem({
        icon: $r('app.string.symbol_open_in_new'), label: $r('app.string.entry_preview_open_url'),
        onAction: () => this.deferred.defer(() => this.onOpen(this.field)),
      })
    } else if (this.expandable) {
      DsMenuItem({
        icon: this.expandIcon, label: this.expandLabel,
        onAction: () => this.deferred.defer(() => this.toggleExpanded()),
      })
    }
  }

  @LocalBuilder
  private menuContent() {
    DsMenuGroup({ content: this.menuItems })
  }

  @LocalBuilder
  private fieldMenu(_response: ResponseType) {
    DsContextMenu({ header: this.menuHeader, content: this.menuContent })
  }

  @LocalBuilder
  private expandableValue() {
    // 内层只负责裁剪。全文按自然高度排版，折叠时也能从顶部逐行收回。
    Scroll() {
      Stack({ alignContent: Alignment.TopStart }) {
        Text(this.field.value)
          .previewValueStyle('HarmonyOS Sans SC', MAX_TEXT_LINES)
          .accessibilityLevel(this.expanded ? 'auto' : 'no')
          .onSizeChange((_old: SizeOptions, size: SizeOptions) => {
            this.fullTextHeight = size.height as number
          })
        Text(this.displayValue)
          .previewValueStyle('HarmonyOS Sans SC', 1)
          .backgroundColor($r('app.color.ds_surface_low'))
          .opacity(this.expanded ? 0 : 1)
          .accessibilityLevel(this.expanded ? 'no' : 'auto')
          .onSizeChange((_old: SizeOptions, size: SizeOptions) => {
            this.singleLineHeight = size.height as number
          })
      }
      .width('100%')
    }
    .width('100%')
    .height(this.valueViewportHeight)
    .align(Alignment.TopStart)
    .renderFit(RenderFit.TOP_LEFT)
    .scrollBar(BarState.Off)
    .enableScrollInteraction(false)
    .hitTestBehavior(HitTestMode.None)
    .accessibilityLevel('no')
    .clip(true)
  }

  @LocalBuilder
  private expandChevron() {
    if (this.expandable) {
      SymbolGlyph($r('app.string.symbol_chevron_down'))
        .fontSize($r('app.float.ds_icon_sm'))
        .fontColor([$r('app.color.ds_text_primary')])
        .foregroundColor($r('app.color.ds_text_primary'))
        .rotate({ angle: this.expanded ? 180 : 0 })
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomStart }) {
      Row({ space: $r('app.float.ds_space_md') }) {
        if (this.field.iconImage !== undefined) {
          Image(this.field.iconImage)
            .draggable(false)
            .width($r('app.float.ds_icon_md'))
            .height($r('app.float.ds_icon_md'))
            .objectFit(ImageFit.Contain)
        } else {
          SymbolGlyph(this.field.icon ?? $r('app.string.symbol_notes'))
            .fontSize($r('app.float.ds_icon_md'))
            .fontColor([$r('app.color.ds_text_secondary')])
            .foregroundColor($r('app.color.ds_text_secondary'))
        }

        Column({ space: $r('app.float.ds_space_2') }) {
          Text(this.field.label)
            .fontSize($r('app.float.ds_font_label_md'))
            .lineHeight($r('app.float.ds_entry_preview_label_line_height'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ds_text_secondary'))
          if (this.expandable) {
            this.expandableValue()
          } else {
            Text(this.displayValue)
              .previewValueStyle(this.field.protectedValue ? PASSWORD_FONT_FAMILY : 'HarmonyOS Sans SC', 1)
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .onSizeChange((oldValue: SizeOptions, newValue: SizeOptions) => {
          if (newValue.width !== oldValue.width) {
            this.valueWidth = newValue.width as number
          }
        })

        DsButton({
          variant: DsButtonVariant.Text,
          buttonSize: DsControlSize.Small,
          iconOnly: true,
          leadingIcon: this.expandable ? undefined
            : (this.isLink ? $r('app.string.symbol_open_in_new') : $r('app.string.symbol_copy')),
          iconSizeOverride: $r('app.float.ds_icon_sm'),
          iconColorOverride: $r('app.color.ds_text_primary'),
          contentBuilder: this.expandChevron,
          accessibilityLabelResource: this.expandable ? this.expandLabel
            : (this.isLink ? $r('app.string.entry_preview_open_url') : this.copyLabel),
          disabled: this.field.value.length === 0,
          onTap: () => this.quickAction(),
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
      .padding({
        top: $r('app.float.ds_space_14'), bottom: $r('app.float.ds_space_14'),
        left: $r('app.float.ds_gutter'), right: $r('app.float.ds_gutter'),
      })

      if ((this.protection?.remainingSeconds ?? 0) > 0) {
        Row() {
          Row()
            .width('100%')
            .height('100%')
            .backgroundColor($r('app.color.ds_primary'))
            .scale({ x: (this.protection?.remainingSeconds ?? 0) / PREVIEW_REVEAL_SECONDS, centerX: 0 })
            .animation({ duration: PROTECTION_TICK_MS, curve: Curve.Linear })
        }
        .width('100%')
        .height($r('app.float.ds_space_2'))
        .backgroundColor($r('app.color.ds_surface_highest'))
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .backgroundColor($r('app.color.ds_surface_low'))
    .bindContextMenuWithResponse(this.field.value.length > 0 ? this.fieldMenu : undefined, this.fieldMenuOptions)
  }
}

@ComponentV2
export struct EntryPreviewView {
  @Param sheet: EntrySheetViewModel = entrySheetViewModel
  @Param bottomOffset: number = 0
  @Require @Param scroller: Scroller
  @Param initialScrollOffset: number = 0
  @Param avatarTransitionKey: string = ''
  @Param avatarEntranceScale: number = 1
  @Event onAvatarVisibilityChange: (visible: boolean) => void = (_visible: boolean) => {}
  @Local private session: AppSessionState = appSessionState
  @Local private protectedFields: Map<string, EntryPreviewProtection> = new Map<string, EntryPreviewProtection>()
  private protectionTimer: number = -1
  private previewEpoch: number = 0
  private readonly viewModel: AppViewModel = appViewModel

  aboutToDisappear(): void {
    this.clearProtection()
  }

  @Monitor('session.sensitiveEpoch', 'sheet.entryUuid', 'sheet.visible', 'sheet.mode')
  onPreviewChanged(): void {
    this.clearProtection()
  }

  private stopProtectionTimer(): void {
    clearInterval(this.protectionTimer)
    this.protectionTimer = -1
  }

  private clearProtection(): void {
    this.previewEpoch++
    this.stopProtectionTimer()
    this.protectedFields.clear()
  }

  private tickProtection(): void {
    const now: number = Date.now()
    for (const entry of this.protectedFields.entries()) {
      const state: EntryPreviewProtection = entry[1]
      const remaining: number = (state.expiresAt - now) / 1000
      if (remaining > 0) {
        state.remainingSeconds = remaining
      } else {
        state.revealed = false
        state.remainingSeconds = 0
        this.protectedFields.delete(entry[0])
      }
    }
    if (this.protectedFields.size === 0) {
      this.stopProtectionTimer()
    }
  }

  private startProtectionTimer(key: string, revealed: boolean): void {
    let state: EntryPreviewProtection | undefined = this.protectedFields.get(key)
    if (state === undefined) {
      state = new EntryPreviewProtection()
      this.protectedFields.set(key, state)
    }
    state.expiresAt = Date.now() + PREVIEW_REVEAL_SECONDS * 1000
    state.revealed = revealed
    state.remainingSeconds = PREVIEW_REVEAL_SECONDS
    if (this.protectionTimer < 0) {
      this.protectionTimer = setInterval(() => this.tickProtection(), PROTECTION_TICK_MS)
    }
  }

  private isRevealed(key: string): boolean {
    const state: EntryPreviewProtection | undefined = this.protectedFields.get(key)
    return state !== undefined && state.revealed && state.expiresAt > Date.now()
  }

  private toggleReveal(key: string): void {
    if (!this.isRevealed(key)) {
      this.startProtectionTimer(key, true)
      return
    }
    this.protectedFields.delete(key)
    if (this.protectedFields.size === 0) {
      this.stopProtectionTimer()
    }
  }

  private async copy(value: string, protectedKey: string = ''): Promise<void> {
    const epoch: number = this.previewEpoch
    const sensitiveEpoch: number = this.session.sensitiveEpoch
    const uuid: string = this.sheet.entryUuid
    if (!(await this.viewModel.copyValue(value)) || epoch !== this.previewEpoch ||
      sensitiveEpoch !== this.session.sensitiveEpoch || uuid !== this.sheet.entryUuid ||
      !this.sheet.visible || this.sheet.mode !== EntrySheetMode.Preview) {
      return
    }
    if (protectedKey.length > 0) {
      this.startProtectionTimer(protectedKey, this.isRevealed(protectedKey))
    }
    DsToastHost.show(this.getUIContext(), $r('app.string.copy_completed'))
  }

  @LocalBuilder
  private identity() {
    Row({ space: $r('app.float.ds_space_md') }) {
      Stack() {
        EntryAvatar({
          title: this.sheet.title,
          avatarData: this.sheet.avatarData,
          avatarSize: $r('app.float.ds_entry_preview_avatar_size'),
          initialsFontSize: $r('app.float.ds_font_title_md'),
          initialsFontWeight: 600,
          entranceScale: this.avatarEntranceScale,
          square: true,
        })
      }
      .geometryTransition(this.avatarTransitionKey)
      .transition(TransitionEffect.OPACITY)
      .onVisibleAreaChange([1], (visible: boolean, ratio: number) => {
        this.onAvatarVisibilityChange(visible && ratio >= 1)
      }, true)
      Column() {
        Row({ space: $r('app.float.ds_space_sm') }) {
          SymbolGlyph($r('app.string.symbol_folder'))
            .fontSize($r('app.float.ds_icon_tiny'))
            .fontColor([$r('app.color.ds_text_secondary')])
            .foregroundColor($r('app.color.ds_text_secondary'))
          Text(this.sheet.groupPath)
            .layoutWeight(1)
            .fontSize($r('app.float.ds_font_body'))
            .fontColor($r('app.color.ds_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        DsTag({
          tagSize: DsTagSize.Small,
          text: this.sheet.templateLabel,
        })
      }
      .height($r('app.float.ds_entry_preview_avatar_size'))
      .layoutWeight(1)
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }

  @LocalBuilder
  private fieldCards() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      ForEach(this.sheet.previewFields, (field: EntryPreviewField) => {
        EntryPreviewFieldCard({
          field,
          maskedValue: this.sheet.showBankCard && field.key === ENTRY_FIELD_CARD_NUMBER ? this.sheet.cardNumberMask : PASSWORD_MASK,
          protection: this.protectedFields.get(field.key),
          expanded: this.sheet.expandedFields.has(field.key),
          onCopy: (copied: EntryPreviewField) => this.copy(copied.value, copied.protectedValue ? copied.key : ''),
          onOpen: (opened: EntryPreviewField) => this.viewModel.openFieldAction(opened.value, opened.type),
          onReveal: () => this.toggleReveal(field.key),
          onExpand: () => this.sheet.toggleFieldExpanded(field.key),
        })
      }, (field: EntryPreviewField) => this.sheet.entryUuid + ':' + field.key)
    }
    .width('100%')
  }

  @LocalBuilder
  private tags() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      Text($r('app.string.tags'))
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_tertiary'))
      Flex({ wrap: FlexWrap.Wrap, space: {
        main: LengthMetrics.resource($r('app.float.ds_space_sm')),
        cross: LengthMetrics.resource($r('app.float.ds_space_sm')),
      } }) {
        ForEach(this.sheet.tags, (tag: string) => {
          DsTag({ tagSize: DsTagSize.Medium, text: tag })
        }, (tag: string) => tag)
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: $r('app.float.ds_space_24') }) {
        this.identity()

        if (this.sheet.showBankCard) {
          EntryPreviewBankCard({
            numberMask: this.sheet.cardNumberMask,
            numberDigits: this.sheet.cardNumberDigits,
            numberRevealed: this.sheet.cardNumberDigits.length > 0 && this.isRevealed(ENTRY_FIELD_CARD_NUMBER),
            holder: this.sheet.cardHolder,
            expiry: this.sheet.cardExpiry,
            logo: this.sheet.cardLogo,
            onCopy: (value: string) => this.copy(value),
          })
        }
        if (this.sheet.sshKeys.length > 0) {
          EntrySshKeyList({
            keys: this.sheet.sshKeys,
            onActivity: () => this.viewModel.recordActivity(),
          })
        }
        if (this.sheet.attachments.length > 0) {
          EntryAttachmentList({ entryUuid: this.sheet.entryUuid, attachments: this.sheet.attachments })
        }

        this.fieldCards()
        if (this.sheet.tags.length > 0) {
          this.tags()
        }
        if (this.sheet.lastModified.length > 0) {
          Text($r('app.string.entry_menu_last_modified', this.sheet.lastModified))
            .fontSize($r('app.float.ds_font_label_md'))
            .fontColor($r('app.color.ds_text_tertiary'))
        }
      }
      .width('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .alignItems(HorizontalAlign.Start)
      .padding({
        top: $r('app.float.ds_space_sm'),
        bottom: this.bottomOffset,
        left: $r('app.float.ds_gutter'),
        right: $r('app.float.ds_gutter'),
      })
      .onTouch(() => this.viewModel.recordActivity())
    }
    .width('100%')
    .height('100%')
    .initialOffset({ xOffset: 0, yOffset: this.initialScrollOffset })
    .align(Alignment.Top)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .clip(false)
  }
}
