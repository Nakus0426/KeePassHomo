import { LengthMetrics, promptAction } from '@kit.ArkUI'
import { AnimationTokens, BounceAnimator, DelayedVisibility, VaultGroup } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { GeneratorContent, GeneratorContentController } from '../generator/GeneratorComponents'
import { DsBottomActionBar } from '../../components/DsBottomActionBar'
import { DsHalfModalSheet } from '../../components/DsHalfModalSheet'
import { DsButton, DsButtonTone, DsButtonVariant } from '../../components/DsButton'
import { DsControlSize } from '../../components/DsControlSize'
import { DsContextMenu } from '../../components/DsContextMenu'
import { dsDatePickerSheetHeight, DsDatePickerMode, DsDatePickerSheet } from '../../components/DsDatePickerSheet'
import { DsDialog, DsDialogTone, dsDialogOptions } from '../../components/DsDialog'
import { DsField } from '../../components/DsField'
import { DsInput, DsInputTone } from '../../components/DsInput'
import { LIST_ROW_FADE_IN } from '../../components/ListRowEnterTransition'
import { DsMenuGroup } from '../../components/DsMenuGroup'
import { DsMenuItem, DsMenuItemTheme } from '../../components/DsMenuItem'
import { DsNotice, DsNoticeTone } from '../../components/DsNotice'
import { DsStrengthMeter } from '../../components/DsStrengthMeter'
import { dsSheetOptions } from '../../components/DsSheetOptions'
import { Status } from '../../components/FormItem'
import { IconToggleButton } from '../../components/IconToggleButton'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { EntryEditorViewModel, EntryFieldEditor } from '../../viewmodel/EntryEditorViewModel'
import { EntrySheetMode, EntrySheetViewModel, entrySheetViewModel } from '../../viewmodel/EntrySheetViewModel'
import {
  definitionFor,
  ItemTemplateDefinition,
  TemplateFieldDefinition,
  TemplateFieldOption,
} from '../../model/EntryTemplateCatalog'
import { EntryAvatarPicker } from './EntryAvatarPicker'
import { EntryAttachmentField } from './EntryAttachmentField'
import { EntryCustomFields } from './EntryCustomFields'
import { DsGroupPicker, GroupPickerSource } from '../../components/DsGroupPicker'
import { createGroupFromPicker } from './GroupPickerActions'
import { EntrySshKeysField } from './EntrySshKeysField'
import { EntryTagEditor } from './EntryTagEditor'
import { DsToastHost } from '../../components/DsToast'

// 头像与标题输入井同高，两者在标题行里顶部对齐。
const TITLE_ROW_GAP: number = 12
const ADVANCED_HEADER_HEIGHT: number = 44
// 头像对齐的是输入井而不是字段标签：标签行 16vp + 字段间距 4vp。
const TITLE_LABEL_OFFSET: number = 20
// 菜单与按钮的间距，设计稿的 8。
const MENU_TARGET_SPACE: number = 8
const EDITOR_SCROLL_ID: string = 'entry_edit_scroll'
// 银行卡有效期：模板字段键，走 MM/YY 文本 + 年月选择器。
const EXPIRY_FIELD_KEY: string = 'Expiry'

export interface EntryEditorActions {
  draft: EntryEditorViewModel
  saveGate: DelayedVisibility
  save: () => void
  requestExit: () => void
  toggleFavorite: () => Promise<void>
}

@ComponentV2
export struct EntryEditorView {
  @Param sheet: EntrySheetViewModel = entrySheetViewModel
  @Param bottomOffset: number = 0
  @Require @Param scroller: Scroller
  @Param avatarTransitionKey: string = ''
  @Param avatarEntranceScale: number = 1
  @Event onAvatarVisibilityChange: (visible: boolean) => void = (_visible: boolean) => {}
  @Event onReady: (actions: EntryEditorActions) => void = (_actions: EntryEditorActions) => {}
  @Event onCancel: () => void = () => {
  }
  @Event onSaved: () => void = () => {
  }
  @Local private editor: EntryEditorViewModel = new EntryEditorViewModel()
  @Local private passwordVisible: boolean = false
  // 受保护模板字段（如卡号）的明文预览，同一时刻只展开一个。
  @Local private protectedFieldVisibleKey: string = ''
  @Local private generatorSheetVisible: boolean = false
  @Local private generatorBottomBarHeight: number = 0
  @Local private groupPickerVisible: boolean = false
  @Local private advancedExpanded: boolean = false
  // 返回 true 表示本次返回已被消费，半模态不收起。
  private groupPickerBackHandler: (() => boolean) | undefined = undefined
  @Local private invalidFieldId: number = -1
  @Local private titleShake: number = 0
  private readonly viewModel: AppViewModel = appViewModel
  private readonly generatorController: GeneratorContentController = new GeneratorContentController()
  private readonly discardDialogController: promptAction.DialogController = new promptAction.DialogController()
  private bounce: BounceAnimator = new BounceAnimator()
  // 保存加载态延时门：超过 400ms 才显示脉冲，快速保存不闪烁。
  private readonly saveGate: DelayedVisibility = new DelayedVisibility()

  aboutToAppear(): void {
    this.passwordVisible = false
    this.invalidFieldId = -1
    this.loadEditor()
    // 已有自定义字段或标签时默认展开，避免用户找不到自己的内容。
    this.advancedExpanded = this.editor.customFields().length > 0 || this.editor.tags.length > 0
    this.onReady({
      draft: this.editor,
      saveGate: this.saveGate,
      save: () => this.saveEntry(),
      requestExit: () => this.requestExit(),
      toggleFavorite: () => this.toggleFavorite(),
    })
  }

  // 草稿与敏感状态要等转场结束、节点销毁后再清：官方禁止在转场过程中更新消失节点的属性。
  aboutToDisappear(): void {
    this.saveGate.dispose()
    this.releaseEditor()
  }

  private loadEditor(): void {
    if (this.sheet.entryUuid.length > 0) {
      this.viewModel.loadEntryForEdit(this.editor, this.sheet.entryUuid)
      return
    }
    this.viewModel.loadNewEntry(this.editor, this.sheet.newEntryTemplate, this.sheet.newEntryGroupUuid)
  }

  @Computed
  get definition(): ItemTemplateDefinition {
    return definitionFor(this.editor.template)
  }

  @Computed
  get credentialFields(): TemplateFieldDefinition[] {
    return this.definition.fields.filter((field: TemplateFieldDefinition) => field.reservedField !== 'Notes')
  }

  @Computed
  get notesField(): TemplateFieldDefinition | undefined {
    return this.definition.fields.find((field: TemplateFieldDefinition) => field.reservedField === 'Notes')
  }

  @Computed
  get advancedMeta(): Resource {
    const count: number = this.editor.customFields().length + this.editor.tags.length
    if (count === 0) {
      return $r('app.string.advanced_meta_placeholder')
    }
    return $r('app.string.advanced_item_count', count)
  }

  @Computed
  get isNewEntry(): boolean {
    return this.editor.entryUuid.length === 0
  }

  private releaseEditor(): void {
    this.invalidFieldId = -1
    this.passwordVisible = false
    this.protectedFieldVisibleKey = ''
    this.editor.reset()
  }

  // 页头关闭与下滑/遮罩/返回走同一条退出路径；保存中转场一律不生效。
  private requestExit(): void {
    if (this.viewModel.busy) {
      return
    }
    if (!this.editor.changed()) {
      this.onCancel()
      return
    }
    this.confirmDiscard()
  }

  // 关闭确认与删除确认走同一个设计系统弹窗：左「放弃」次按钮、右「继续编辑」主按钮。
  private confirmDiscard(): void {
    this.getUIContext()
      .getPromptAction()
      .presentCustomDialog(() => this.discardDialog(), this.discardDialogController, dsDialogOptions())
  }

  @LocalBuilder
  private discardDialog() {
    DsDialog({
      title: $r('app.string.unsaved_title'),
      message: $r('app.string.unsaved_message'),
      cancelLabel: $r('app.string.discard'),
      confirmLabel: $r('app.string.continue_editing'),
      onCancel: () => {
        this.discardDialogController.close()
        this.onCancel()
      },
      onConfirm: () => this.discardDialogController.close(),
    })
  }

  private saveEntry(): void {
    if (this.viewModel.busy) {
      return
    }
    const invalidFieldKey: string | undefined = this.editor.validate()
    if (invalidFieldKey === undefined) {
      this.saveGate.setActive(true)
      this.viewModel.saveEntry(this.editor).then((saved: boolean) => {
        this.saveGate.setActive(false)
        if (saved) {
          DsToastHost.show(this.getUIContext(), $r('app.string.saved'))
          this.onSaved()
          return
        }
        this.toastStatus()
      })
      return
    }
    if (invalidFieldKey === 'title') {
      this.titleShake++
    } else {
      this.invalidFieldId = Number(invalidFieldKey)
      DsToastHost.show(this.getUIContext(), $r('app.string.field_name_required'))
      this.advancedExpanded = true
    }
    this.scrollToField(invalidFieldKey)
  }

  private toastStatus(): void {
    if (this.viewModel.status.length === 0) {
      return
    }
    DsToastHost.show(this.getUIContext(), this.viewModel.status)
  }

  private scrollToField(fieldKey: string): void {
    const componentUtils = this.getUIContext().getComponentUtils()
    const fieldTopPx: number = componentUtils.getRectangleById(`field_${fieldKey}`).windowOffset.y
    const scrollTopPx: number = componentUtils.getRectangleById(EDITOR_SCROLL_ID).windowOffset.y
    const targetY: number = this.scroller.currentOffset().yOffset +
      this.getUIContext().px2vp(fieldTopPx - scrollTopPx)
    this.scroller.scrollTo({
      xOffset: 0,
      yOffset: Math.max(targetY, 0),
      animation: {
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
      },
    })
  }

  private openGeneratorSheet(): void {
    this.viewModel.prepareGenerator()
    this.generatorSheetVisible = true
  }

  private closeGeneratorSheet(): void {
    this.generatorSheetVisible = false
    this.viewModel.generator.clearSensitiveState()
  }

  private fillPasswordFromGenerator(): void {
    const password: string = this.generatorController.getCurrentPassword()
    if (password.length === 0) {
      return
    }
    this.editor.setPassword(password)
    this.viewModel.recordActivity()
    this.closeGeneratorSheet()
  }

  private get readOnly(): boolean {
    return this.viewModel.currentSource().readOnly
  }

  private async toggleFavorite(): Promise<void> {
    this.editor.favorite = !this.editor.favorite
    // 新建条目没有可写入的 uuid，收藏只改草稿，保存时随条目一起落库。
    if (this.isNewEntry) {
      return
    }
    const uuid: string = this.editor.entryUuid
    await this.viewModel.toggleFavorite(uuid)
    if (this.editor.entryUuid === uuid) {
      this.editor.favorite = this.viewModel.entry(uuid).favorite
    }
  }

  @Computed
  get titleFeedback(): ResourceStr | undefined {
    return this.editor.titleController.status === Status.Invalid
      ? this.editor.titleController.message : undefined
  }

  @LocalBuilder
  private titleInput() {
    DsInput({
      text: this.editor.title,
      placeholder: $r('app.string.entry_title_placeholder'),
      tone: this.editor.titleController.status === Status.Invalid ? DsInputTone.Error : DsInputTone.Default,
      readOnly: this.readOnly,
      onChange: (value: string) => this.editor.setTitle(value),
    })
  }

  @LocalBuilder
  private usernameInput() {
    DsInput({
      text: this.editor.username,
      placeholder: $r('app.string.username_placeholder'),
      readOnly: this.readOnly,
      onChange: (value: string) => this.editor.setUsername(value),
    })
  }

  // 显隐眼睛：主密码与受保护模板字段共用同一套图标与无障碍文案。
  @LocalBuilder
  private eyeToggle(checked: boolean, onToggle: () => void) {
    IconToggleButton({
      symbol: $r('app.string.symbol_eye_off'),
      symbolChecked: $r('app.string.symbol_eye'),
      checked: checked,
      symbolColor: $r('app.color.ds_text_secondary'),
      accessibilityLabel: checked ? $r('app.string.hide') : $r('app.string.show'),
      clickable: !this.readOnly,
      onToggle: onToggle,
    })
  }

  @LocalBuilder
  private passwordTrailing() {
    Row({ space: $r('app.float.ds_space_xs') }) {
      this.eyeToggle(this.passwordVisible, () => this.passwordVisible = !this.passwordVisible)

      IconToggleButton({
        symbol: $r('app.string.symbol_generate'),
        symbolColor: $r('app.color.ds_primary'),
        accessibilityLabel: $r('app.string.generate_password'),
        clickable: !this.readOnly,
        onToggle: () => this.bounce.play(this.getUIContext(), () => this.openGeneratorSheet()),
      })
    }
  }

  @LocalBuilder
  private passwordInput() {
    DsInput({
      text: this.editor.password,
      placeholder: $r('app.string.password_placeholder'),
      type: InputType.Password,
      showPassword: this.passwordVisible,
      readOnly: this.readOnly,
      trailingBuilder: this.passwordTrailing,
      onChange: (value: string) => this.editor.setPassword(value),
    })
  }

  @LocalBuilder
  private urlInput() {
    DsInput({
      text: this.editor.url,
      placeholder: $r('app.string.website_placeholder'),
      readOnly: this.readOnly,
      onChange: (value: string) => this.editor.setUrl(value),
    })
  }

  @LocalBuilder
  private notesInput() {
    DsInput({
      text: this.editor.notes,
      placeholder: $r('app.string.notes_placeholder'),
      multiline: true,
      minLines: 4,
      readOnly: this.readOnly,
      onChange: (value: string) => this.editor.setNotes(value),
    })
  }

  private fieldPlaceholder(definition: TemplateFieldDefinition): ResourceStr {
    return definition.placeholder ?? $r('app.string.text_input_placeholder')
  }

  @LocalBuilder
  private templateFieldInput(field: EntryFieldEditor, definition: TemplateFieldDefinition) {
    if (definition.multiline) {
      DsInput({
        text: field.value,
        placeholder: this.fieldPlaceholder(definition),
        multiline: true,
        minLines: 4,
        readOnly: this.readOnly,
        onChange: (value: string) => this.editor.setFieldValue(field, value),
      })
    } else if (definition.protected) {
      DsInput({
        text: field.value,
        placeholder: this.fieldPlaceholder(definition),
        type: InputType.Password,
        showPassword: this.protectedFieldVisibleKey === definition.key,
        readOnly: this.readOnly,
        trailingBuilder: () => {
          this.protectedFieldTrailing(definition.key)
        },
        onChange: (value: string) => this.editor.setFieldValue(field, value),
      })
    } else if (definition.key === EXPIRY_FIELD_KEY) {
      TemplateExpiryField({
        text: field.value,
        placeholder: this.fieldPlaceholder(definition),
        readOnly: this.readOnly,
        onChange: (value: string) => this.editor.setFieldValue(field, value),
      })
    } else if (definition.options.length > 0) {
      DsInput({
        text: field.value,
        placeholder: this.fieldPlaceholder(definition),
        readOnly: this.readOnly,
        trailingBuilder: () => {
          this.optionMenuButton(field, definition)
        },
        onChange: (value: string) => this.editor.setFieldValue(field, value),
      })
    } else {
      DsInput({
        text: field.value,
        placeholder: this.fieldPlaceholder(definition),
        readOnly: this.readOnly,
        onChange: (value: string) => this.editor.setFieldValue(field, value),
      })
    }
  }

  // 受保护模板字段只有显隐，没有生成器。
  @LocalBuilder
  private protectedFieldTrailing(fieldKey: string) {
    this.eyeToggle(this.protectedFieldVisibleKey === fieldKey, () => {
      this.protectedFieldVisibleKey = this.protectedFieldVisibleKey === fieldKey ? '' : fieldKey
    })
  }

  // 卡类型等固定取值：下拉只做快捷填入，选项文案仍可手动编辑。
  @LocalBuilder
  private optionMenuButton(field: EntryFieldEditor, definition: TemplateFieldDefinition) {
    TemplateOptionMenuButton({
      definition: definition,
      onSelect: (value: string) => this.editor.setFieldValue(field, value),
    })
  }

  @LocalBuilder
  private templateFieldRow(definition: TemplateFieldDefinition) {
    DsField({
      label: definition.label,
      contentBuilder: () => {
        this.templateFieldInput(this.editor.templateField(definition.key)!, definition)
      },
    })
      .id(`field_${definition.key}`)
  }

  // 组件必须在 @Builder 作用域内创建：直接写进 contentBuilder 的箭头参数里不会被编译成组件创建
  @LocalBuilder
  private attachmentField() {
    EntryAttachmentField({
      editor: this.editor,
      entryUuid: this.sheet.entryUuid,
      readOnly: this.readOnly,
      active: this.sheet.mode === EntrySheetMode.Edit,
      onActivity: () => this.viewModel.recordActivity(),
    })
  }

  @LocalBuilder
  private sshKeysField() {
    EntrySshKeysField({
      editor: this.editor,
      readOnly: this.readOnly,
      active: this.sheet.mode === EntrySheetMode.Edit,
      onActivity: () => this.viewModel.recordActivity(),
    })
  }

  @LocalBuilder
  private attachmentRow(definition: TemplateFieldDefinition) {
    DsField({
      label: definition.label,
      contentBuilder: this.attachmentField,
    })
      .id('field_attachments')
  }

  @LocalBuilder
  private sshKeysRow(definition: TemplateFieldDefinition) {
    DsField({
      label: definition.label,
      contentBuilder: this.sshKeysField,
    })
      .id(`field_${definition.key}`)
  }

  @LocalBuilder
  customFieldsBuilder() {
    EntryCustomFields({
      editor: this.editor,
      readOnly: this.readOnly,
      invalidFieldId: this.invalidFieldId,
      active: this.sheet.mode === EntrySheetMode.Edit,
      bottomOffset: this.bottomOffset,
      onInvalidCleared: () => this.invalidFieldId = -1,
      onActivity: () => this.viewModel.recordActivity(),
    })
  }

  @LocalBuilder
  tagsBuilder() {
    EntryTagEditor({
      editor: this.editor,
      readOnly: this.readOnly,
      active: this.sheet.mode === EntrySheetMode.Edit,
      onActivity: () => this.viewModel.recordActivity(),
    })
  }

  // 头像与标题输入井对齐：字段标签行占 19，头像下沉同样高度后与输入井同顶。
  @LocalBuilder
  private titleRow() {
    Row({ space: TITLE_ROW_GAP }) {
      Column() {
        EntryAvatarPicker({
          title: this.editor.title,
          avatarData: this.editor.avatarData,
          avatarTransitionKey: this.avatarTransitionKey,
          avatarEntranceScale: this.avatarEntranceScale,
          onAvatarVisibilityChange: (visible: boolean) => this.onAvatarVisibilityChange(visible),
          readOnly: this.readOnly,
          onPicked: (data: ArrayBuffer) => this.editor.setAvatar(data),
          onReset: () => this.editor.clearAvatar(),
        })
      }
      .padding({ top: TITLE_LABEL_OFFSET })

      Column() {
        DsField({
          label: $r('app.string.entry_title'),
          required: true,
          feedback: this.titleFeedback,
          reserveFeedbackSpace: true,
          shakeTrigger: this.titleShake,
          contentBuilder: this.titleInput,
        })
          .id('field_title')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @LocalBuilder
  private groupRow() {
    Column({ space: $r('app.float.ds_space_md') }) {
      Text($r('app.string.group'))
        .fontSize($r('app.float.ds_font_label_md'))
        .fontWeight(600)
        .letterSpacing($r('app.float.ds_tracking_wide_md'))
        .fontColor($r('app.color.ds_text_primary'))

      Row({ space: $r('app.float.ds_space_md') }) {
        SymbolGlyph($r('app.string.symbol_folder_filled'))
          .fontSize($r('app.float.ds_icon_md'))
          .fontColor([$r('app.color.ds_text_primary')])
          .foregroundColor($r('app.color.ds_text_primary'))

        Column({ space: $r('app.float.ds_space_2') }) {
          Text(this.editor.groupName)
            .fontSize($r('app.float.ds_font_title'))
            .fontWeight(600)
            .fontColor($r('app.color.ds_text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.editor.groupPath)
            .fontSize($r('app.float.ds_font_body_sm'))
            .fontColor($r('app.color.ds_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (!this.readOnly) {
          SymbolGlyph($r('app.string.symbol_chevron_right'))
            .fontSize($r('app.float.ds_icon_md'))
            .fontColor([$r('app.color.ds_text_secondary')])
            .foregroundColor($r('app.color.ds_text_secondary'))
        }
      }
      .width('100%')
      .height(64)
      .padding($r('app.float.ds_space_md'))
      .backgroundColor($r('app.color.ds_surface_low'))
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        if (!this.readOnly) {
          this.groupPickerVisible = true
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @LocalBuilder
  private basicBlock() {
    Column({ space: $r('app.float.ds_space_md') }) {
      this.titleRow()
      this.groupRow()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @LocalBuilder
  private credentialBlock() {
    Column({ space: $r('app.float.ds_space_16') }) {
      Text(this.definition.name)
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontWeight(600)
        .letterSpacing($r('app.float.ds_tracking_wide_2xl'))
        .fontColor($r('app.color.ds_text_tertiary'))

      ForEach(this.credentialFields, (definition: TemplateFieldDefinition) => {
        if (definition.reservedField === 'UserName') {
          DsField({
            label: definition.label,
            contentBuilder: this.usernameInput,
          })
            .id('field_username')
        } else if (definition.reservedField === 'Password') {
          Column({ space: $r('app.float.ds_space_6') }) {
            DsField({
              label: definition.label,
              contentBuilder: this.passwordInput,
            })
              .id('field_password')

            // 空密码也占住这块，输入时不会把下方字段整体顶下去。
            Column({ space: $r('app.float.ds_space_6') }) {
              Text($r('app.string.password_strength_label'))
                .fontSize($r('app.float.ds_font_label_sm'))
                .fontColor($r('app.color.ds_text_tertiary'))
              DsStrengthMeter({ password: this.editor.password })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        } else if (definition.reservedField === 'URL') {
          DsField({
            label: definition.label,
            contentBuilder: this.urlInput,
          })
            .id('field_url')
        } else if (definition.attachments) {
          this.attachmentRow(definition)
        } else if (definition.sshKeys) {
          this.sshKeysRow(definition)
        } else {
          this.templateFieldRow(definition)
        }
      }, (definition: TemplateFieldDefinition) => definition.key)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @LocalBuilder
  private notesBlock() {
    if (this.notesField !== undefined) {
      DsField({
        label: this.notesField.label,
        contentBuilder: this.notesInput,
      })
        .id('field_notes')
    }
  }

  @LocalBuilder
  private advancedHeader() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      Text($r('app.string.advanced'))
        .fontSize($r('app.float.ds_font_label_md'))
        .fontWeight(600)
        .letterSpacing($r('app.float.ds_tracking_wide_md'))
        .fontColor($r('app.color.ds_text_primary'))

      Text(this.advancedMeta)
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontColor($r('app.color.ds_text_tertiary'))
        .layoutWeight(1)

      SymbolGlyph(this.advancedExpanded ? $r('app.string.symbol_chevron_up') : $r('app.string.symbol_chevron_down'))
        .fontSize($r('app.float.ds_icon_md'))
        .fontColor([$r('app.color.ds_text_tertiary')])
        .foregroundColor($r('app.color.ds_text_tertiary'))
    }
    .width('100%')
    .height(ADVANCED_HEADER_HEIGHT)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.getUIContext().animateTo({
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
      }, () => {
        this.advancedExpanded = !this.advancedExpanded
      })
    })
  }

  @LocalBuilder
  private advancedContent() {
    Column({ space: $r('app.float.ds_space_md') }) {
      this.customFieldsBuilder()

      if (!this.readOnly || this.editor.tags.length > 0) {
        DsField({
          label: $r('app.string.tags'),
          contentBuilder: this.tagsBuilder,
        })
          .id('field_tags')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    // 展开与折叠都走同一条过渡，折叠时不会只有淡出。
    .transition(LIST_ROW_FADE_IN)
  }

  @LocalBuilder
  private advancedBlock() {
    Column({ space: $r('app.float.ds_space_md') }) {
      this.advancedHeader()

      if (this.advancedExpanded) {
        this.advancedContent()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @LocalBuilder
  private readOnlyNotice() {
    if (this.readOnly) {
      DsNotice({
        tone: DsNoticeTone.Default,
        title: $r('app.string.read_only'),
        body: $r('app.string.read_only_notice_body'),
      })
    }
  }

  @LocalBuilder
  private generatorBottomActions() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      Row() {
        DsButton({
          label: $r('app.string.regenerate_password'),
          tone: DsButtonTone.Default,
          trailingIcon: $r('app.string.symbol_refresh'),
          fullWidth: true,
          onTap: () => this.viewModel.generator.regenerate(),
        })
      }
      .layoutWeight(1)

      Row() {
        DsButton({
          label: $r('app.string.fill_current_entry'),
          trailingIcon: $r('app.string.symbol_check'),
          fullWidth: true,
          onTap: () => this.fillPasswordFromGenerator(),
        })
      }
      .layoutWeight(1)
    }
    .width('100%')
  }

  // 预览底色上探到标题栏底部：内容绘制到标题栏下方，标题栏悬浮其上。
  @Computed
  get sheetTitleBarHeightVp(): number {
    const titleBarPx: number = ResUtil.getNumber($r('app.float.ds_page_header_height_sm').id)
    return this.getUIContext().px2vp(titleBarPx)
  }

  @LocalBuilder
  private generatorBody() {
    Stack() {
      GeneratorContent({
        viewModel: this.viewModel.generator,
        controller: this.generatorController,
        topOffset: this.sheetTitleBarHeightVp,
        bottomOffset: this.generatorBottomBarHeight,
        onSheet: true,
        onActivity: () => this.viewModel.recordActivity(),
      })
    }
    .width('100%')
    .height('100%')
  }

  @LocalBuilder
  private generatorBottomBar() {
    DsBottomActionBar({
      surfaceColor: $r('app.color.ds_surface_lowest'),
      fadeColor: $r('app.color.ds_surface_lowest_transparent'),
      onHeightChange: (height: number) => {
        this.generatorBottomBarHeight = height
      },
      contentBuilder: () => {
        this.generatorBottomActions()
      },
    })
  }

  @LocalBuilder
  private generatorSheet() {
    DsHalfModalSheet({
      title: $r('app.string.generate_password'),
      onClose: () => this.closeGeneratorSheet(),
      bodyBuilder: this.generatorBody,
      bottomBarBuilder: this.generatorBottomBar,
      contentBehindTitleBar: true,
    })
  }

  // 选择器自带标题栏与菜单，半模态壳只配容器参数；与编辑半模态同高，故不设挡位。
  @LocalBuilder
  private groupPickerSheet() {
    DsGroupPicker({
      groupSource: (): GroupPickerSource => {
        const allGroups: VaultGroup[] = this.viewModel.groups()
        return {
          rootGroup: allGroups[0],
          topLevelGroups: this.viewModel.topLevelGroups(),
          allGroups,
        }
      },
      initialGroupUuid: this.editor.groupUuid,
      busy: this.viewModel.busy,
      onPicked: (groupUuid: string) => {
        this.editor.setGroup(this.viewModel.requireGroup(groupUuid))
        this.groupPickerVisible = false
      },
      onClose: () => this.groupPickerVisible = false,
      onCreateGroup: (parentUuid: string, name: string) =>
      createGroupFromPicker(this.getUIContext(), this.viewModel, parentUuid, name),
      onActivity: () => this.viewModel.recordActivity(),
      onBackHandler: (handler: () => boolean) => this.groupPickerBackHandler = handler,
    })
  }

  // 返回键、边缘返回手势、导航栏返回都归入 PRESS_BACK，先交给选择器消费；其余原因按默认关闭。
  private onGroupPickerWillDismiss(action: DismissSheetAction): void {
    const backHandler: (() => boolean) | undefined = this.groupPickerBackHandler
    if (action.reason === DismissReason.PRESS_BACK && backHandler !== undefined && backHandler()) {
      return
    }
    action.dismiss()
  }

  @LocalBuilder
  private editorBody() {
    Scroll(this.scroller) {
      Column({ space: $r('app.float.ds_space_24') }) {
        this.readOnlyNotice()
        this.basicBlock()
        this.credentialBlock()
        this.notesBlock()
        this.advancedBlock()
      }
      .width('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding({
        top: $r('app.float.ds_space_sm'),
        // 底部固定操作栏浮在内容上，按实测高度避让，否则「高级」区永远滚不出来。
        bottom: this.bottomOffset,
        left: $r('app.float.ds_gutter'),
        right: $r('app.float.ds_gutter'),
      })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .id(EDITOR_SCROLL_ID)
    .scrollBar(BarState.Off)
    // alwaysEnabled：内容不足一屏时也由滚动容器接管竖向手势，避免上下滑动拖动整个半模态。
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true, effectEdge: EffectEdge.START | EffectEdge.END })
    .onTouch(() => this.viewModel.recordActivity())
    .bindSheet($$this.generatorSheetVisible, this.generatorSheet(), dsSheetOptions({
      onDisappear: () => this.closeGeneratorSheet(),
    }))
    .clip(false)
    // 内容不足一屏时按首部对齐，默认居中会让表单悬在面板中部。
    .align(Alignment.Top)
  }

  build() {
    Stack() {
      this.editorBody()
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.groupPickerVisible, this.groupPickerSheet(), dsSheetOptions({
      onWillDismiss: (action: DismissSheetAction) => this.onGroupPickerWillDismiss(action),
      onDisappear: () => {
        this.groupPickerVisible = false
        this.groupPickerBackHandler = undefined
      },
    }))
  }
}

// 固定取值字段的下拉：自绘菜单与卡片长按菜单共用皮肤，选项带品牌标识。
@ComponentV2
struct TemplateOptionMenuButton {
  @Require @Param definition: TemplateFieldDefinition
  @Event onSelect: (value: string) => void = () => {
  }

  @Computed
  private get menuOptions(): MenuOptions {
    return {
      placement: Placement.BottomRight,
      targetSpace: LengthMetrics.vp(MENU_TARGET_SPACE),
      borderRadius: $r('app.float.ds_radius_none'),
      backgroundColor: $r('app.color.ds_surface_lowest'),
      backgroundBlurStyle: BlurStyle.NONE,
      mask: {
        color: $r('app.color.ds_scrim'),
        backgroundBlurStyle: BlurStyle.NONE,
      },
    }
  }

  @LocalBuilder
  private menuHeader() {
    Column({ space: $r('app.float.ds_space_2') }) {
      Text($r('app.string.card_type_menu_title'))
        .fontSize($r('app.float.ds_font_body'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))
      Text($r('app.string.card_type_menu_hint'))
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontColor($r('app.color.ds_text_secondary'))
    }
    .width('100%')
    .padding({
      top: $r('app.float.ds_space_md'),
      bottom: $r('app.float.ds_space_md'),
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
    })
    .backgroundColor($r('app.color.ds_surface_low'))
    .alignItems(HorizontalAlign.Start)
  }

  @LocalBuilder
  private menuContent() {
    ForEach(this.definition.options, (option: TemplateFieldOption) => {
      DsMenuItem({
        iconImage: option.icon,
        label: option.value,
        onAction: () => this.onSelect(option.value),
      })
    }, (option: TemplateFieldOption) => option.value)
  }

  @LocalBuilder
  private menu() {
    DsContextMenu({
      header: this.menuHeader,
      content: this.menuContent,
    })
  }

  build() {
    DsButton({
      variant: DsButtonVariant.Text,
      tone: DsButtonTone.Default,
      iconOnly: true,
      // 与密码行的显隐、生成按钮同尺寸，四周留出输入井内距。
      buttonSize: DsControlSize.Small,
      leadingIcon: $r('app.string.symbol_chevron_down'),
      iconSizeOverride: $r('app.float.ds_icon_sm'),
      iconColorOverride: $r('app.color.ds_on_surface_variant'),
      accessibilityLabelResource: $r('app.string.select_type'),
      menuBuilder: this.menu,
      menuOptions: this.menuOptions,
      onTap: () => {
      },
    })
  }
}

// 有效期：保留 MM/YY 手输，尾部提供清除与年月选择入口。
@ComponentV2
struct TemplateExpiryField {
  @Param text: string = ''
  @Param placeholder: ResourceStr = ''
  @Param readOnly: boolean = false
  @Event onChange: (value: string) => void = () => {
  }
  @Local private sheetVisible: boolean = false
  @Local private pickerValue: string = ''

  private expiryToPickerValue(): string {
    const match: RegExpMatchArray | null = this.text.trim().match(/^(\d{1,2})\s*\/\s*(\d{2})$/)
    if (match === null) {
      return ''
    }
    return `20${match[2]}-${match[1].padStart(2, '0')}`
  }

  private pickerValueToExpiry(value: string): string {
    const parts: string[] = value.split('-')
    return parts.length < 2 ? value : `${parts[1]}/${parts[0].slice(2)}`
  }

  private openPicker(): void {
    this.pickerValue = this.expiryToPickerValue()
    this.sheetVisible = true
  }

  @LocalBuilder
  private trailing() {
    if (!this.readOnly) {
      Row({ space: $r('app.float.ds_space_xs') }) {
        DsButton({
          variant: DsButtonVariant.Text,
          tone: DsButtonTone.Default,
          buttonSize: DsControlSize.Small,
          iconOnly: true,
          leadingIcon: $r('app.string.symbol_calendar'),
          iconSizeOverride: $r('app.float.ds_icon_sm'),
          iconColorOverride: $r('app.color.ds_on_surface_variant'),
          accessibilityLabelResource: $r('app.string.card_expiry_picker_title'),
          onTap: () => this.openPicker(),
        })
      }
    }
  }

  @LocalBuilder
  private pickerSheet() {
    DsDatePickerSheet({
      mode: DsDatePickerMode.YearMonth,
      value: this.pickerValue,
      pickerTitle: $r('app.string.card_expiry_picker_title'),
      onConfirm: (value: string) => {
        this.sheetVisible = false
        this.onChange(this.pickerValueToExpiry(value))
      },
      onClose: () => this.sheetVisible = false,
    })
  }

  build() {
    DsInput({
      text: this.text,
      placeholder: this.placeholder,
      readOnly: this.readOnly,
      clearable: !this.readOnly,
      clearLabel: $r('app.string.card_expiry_clear'),
      onClear: () => this.onChange(''),
      trailingBuilder: this.trailing,
      onChange: (value: string) => this.onChange(value),
    })
      .bindSheet($$this.sheetVisible, this.pickerSheet(), dsSheetOptions({
        detents: [dsDatePickerSheetHeight(this.getUIContext())],
        onDisappear: () => this.sheetVisible = false,
      }))
  }
}
