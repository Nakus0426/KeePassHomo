import { AnimationTokens, AppToast, BounceAnimator } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { GeneratorContent, GeneratorContentController } from '../generator/GeneratorComponents'
import { DsBottomActionBar } from '../../components/DsBottomActionBar'
import { DsHalfModalSheet } from '../../components/DsHalfModalSheet'
import { DsButton, DsButtonTone } from '../../components/DsButton'
import { DsPageHeaderAction } from '../../components/DsPageHeader'
import { FormItem, Status } from '../../components/FormItem'
import { FormTextArea } from '../../components/FormTextArea'
import { FormTextField, FormTextFieldStatus } from '../../components/FormTextField'
import { PasswordStrengthIndicator } from '../../components/PasswordStrengthIndicator'
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
import { EntryGroupPicker } from './EntryGroupPicker'
import { EntrySshKeysField } from './EntrySshKeysField'
import { EntryTagEditor } from './EntryTagEditor'

@ComponentV2
export struct EntryEditorView {
  @Param sheet: EntrySheetViewModel = entrySheetViewModel
  @Param bottomOffset: number = 0
  @Event onWillDismissCheck: (handler: () => void) => void = () => {
  }
  @Event onCancel: () => void = () => {
  }
  @Event onSaved: () => void = () => {
  }
  @Local private editor: EntryEditorViewModel = new EntryEditorViewModel()
  @Local private passwordVisible: boolean = false
  @Local private generatorSheetVisible: boolean = false
  @Local private generatorBottomBarHeight: number = 0
  @Local private groupPickerVisible: boolean = false
  // 返回 true 表示本次返回已被消费，半模态不收起。
  private groupPickerBackHandler: (() => boolean) | undefined = undefined
  @Local private invalidFieldId: number = -1
  private readonly viewModel: AppViewModel = appViewModel
  private readonly scroller: Scroller = new Scroller()
  private readonly generatorController: GeneratorContentController = new GeneratorContentController()
  private bounce: BounceAnimator = new BounceAnimator()

  aboutToAppear(): void {
    this.passwordVisible = false
    this.invalidFieldId = -1
    this.loadEditor()
    this.onWillDismissCheck(() => this.onExternalDismissRequest())
  }

  // 草稿与敏感状态要等转场结束、节点销毁后再清：官方禁止在转场过程中更新消失节点的属性。
  aboutToDisappear(): void {
    this.releaseEditor()
  }

  private loadEditor(): void {
    if (this.sheet.entryUuid.length > 0) {
      this.viewModel.loadEntryForEdit(this.editor, this.sheet.entryUuid)
      return
    }
    this.viewModel.loadNewEntry(this.editor, this.sheet.newEntryTemplate)
  }

  @Computed
  get definition(): ItemTemplateDefinition {
    return definitionFor(this.editor.template)
  }

  @Computed
  get hasOtherFields(): boolean {
    return this.editor.customFields().length > 0
  }

  private releaseEditor(): void {
    this.invalidFieldId = -1
    this.passwordVisible = false
    this.editor.reset()
  }

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

  private onExternalDismissRequest(): void {
    if (!this.editor.changed()) {
      return
    }
    this.confirmDiscard()
  }

  private confirmDiscard(): void {
    const options: AlertDialogParamWithButtons = {
      title: $r('app.string.unsaved_title'),
      message: $r('app.string.unsaved_message'),
      primaryButton: {
        value: $r('app.string.continue_editing'),
        action: () => {
        },
      },
      secondaryButton: {
        value: $r('app.string.discard'),
        fontColor: $r('app.color.ds_warning'),
        action: () => this.onCancel(),
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  private saveEntry(): void {
    if (this.viewModel.busy) {
      return
    }
    const invalidFieldKey: string | undefined = this.editor.validate()
    if (invalidFieldKey === undefined) {
      this.viewModel.saveEntry(this.editor).then((saved: boolean) => {
        if (saved) {
          AppToast.show(this.getUIContext(), $r('app.string.saved'))
          this.onSaved()
          return
        }
        this.toastStatus()
      })
      return
    }
    if (invalidFieldKey !== 'title') {
      this.invalidFieldId = Number(invalidFieldKey)
      AppToast.showAboveSheets(this.getUIContext(), $r('app.string.field_name_required'))
    }
    this.scrollToField(invalidFieldKey)
  }

  private toastStatus(): void {
    if (this.viewModel.status.length === 0) {
      return
    }
    AppToast.showAboveSheets(this.getUIContext(), this.viewModel.status)
  }

  private scrollToField(fieldKey: string): void {
    const componentUtils = this.getUIContext().getComponentUtils()
    const fieldTopPx: number = componentUtils.getRectangleById(`field_${fieldKey}`).windowOffset.y
    const scrollTopPx: number = componentUtils.getRectangleById('entry_edit_scroll').windowOffset.y
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

  @Computed
  get textInputButtonSize(): number {
    const buttonHeight: number = ResUtil.getNumber($r('app.float.control_height').id)
    const padding: number = ResUtil.getNumber($r('app.float.ds_space_xs').id)
    return this.getUIContext().px2vp(buttonHeight - padding * 2)
  }

  @LocalBuilder
  titleBuilder() {
    FormTextField({
      placeholder: $r('app.string.text_input_placeholder'),
      text: this.editor.title,
      status: this.editor.titleController.status === Status.Invalid
        ? FormTextFieldStatus.Warning : undefined,
      onSheet: true,
      onChange: (value: string) => this.editor.setTitle(value),
    })
  }

  @LocalBuilder
  usernameBuilder() {
    FormTextField({
      placeholder: $r('app.string.text_input_placeholder'),
      text: this.editor.username,
      onSheet: true,
      onChange: (value: string) => this.editor.setUsername(value),
    })
  }

  @LocalBuilder
  passwordBuilder() {
    FormTextField({
      placeholder: $r('app.string.text_input_placeholder'),
      text: this.editor.password,
      type: InputType.Password,
      showPassword: this.passwordVisible,
      onSheet: true,
      onChange: (value: string) => this.editor.setPassword(value),
    }) {
      IconToggleButton({
        symbol: $r('app.string.symbol_eye_off'),
        symbolChecked: $r('app.string.symbol_eye'),
        checked: this.passwordVisible,
        accessibilityLabel: this.passwordVisible ? $r('app.string.hide') : $r('app.string.show'),
        onToggle: () => this.passwordVisible = !this.passwordVisible,
      })

      Divider()
        .vertical(true)
        .margin({ top: $r('app.float.ds_space_6'), bottom: $r('app.float.ds_space_6') })
        .color($r('app.color.ds_outline_variant'))

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('app.string.symbol_generate'))
          .fontSize(22)
          .fontColor([$r('app.color.ds_primary')])
          .scale({ x: this.bounce.scale, y: this.bounce.scale })
      }
      .width(this.textInputButtonSize)
      .height(this.textInputButtonSize)
      .backgroundColor(Color.Transparent)
      .onClick(() => this.bounce.play(this.getUIContext(), () => this.openGeneratorSheet()))
    }
  }

  @LocalBuilder
  urlBuilder() {
    FormTextField({
      placeholder: $r('app.string.text_input_placeholder'),
      text: this.editor.url,
      onSheet: true,
      onChange: (value: string) => this.editor.setUrl(value),
    })
  }

  @LocalBuilder
  notesBuilder() {
    FormTextArea({
      placeholder: $r('app.string.text_input_placeholder'),
      text: this.editor.notes,
      onSheet: true,
      onChange: (value: string) => this.editor.setNotes(value),
    })
  }

  @LocalBuilder
  private templateFieldInput(field: EntryFieldEditor, definition: TemplateFieldDefinition) {
    if (definition.multiline) {
      FormTextArea({
        placeholder: $r('app.string.text_input_placeholder'),
        text: field.value,
        onSheet: true,
        onChange: (value: string) => this.editor.setFieldValue(field, value),
      })
    } else if (definition.options.length > 0) {
      FormTextField({
        placeholder: $r('app.string.text_input_placeholder'),
        text: field.value,
        onSheet: true,
        prefixIcon: this.matchedOptionIcon(field, definition),
        prefixSymbol: $r('app.string.symbol_credit_card'),
        onChange: (value: string) => this.editor.setFieldValue(field, value),
      }) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('app.string.symbol_chevron_down'))
            .fontSize($r('sys.float.Title_S'))
            .fontColor([$r('app.color.ds_on_surface_variant')])
        }
        .width(this.textInputButtonSize)
        .height(this.textInputButtonSize)
        .backgroundColor(Color.Transparent)
        .bindMenu(definition.options.map((option: TemplateFieldOption) => this.optionMenuItem(field, option)))
      }
    } else {
      FormTextField({
        placeholder: $r('app.string.text_input_placeholder'),
        text: field.value,
        onSheet: true,
        onChange: (value: string) => this.editor.setFieldValue(field, value),
      })
    }
  }

  // 取值由菜单快捷填入，也可手打：只有命中枚举才显示图标，不做兜底。
  private matchedOptionIcon(field: EntryFieldEditor, definition: TemplateFieldDefinition): Resource | undefined {
    const matched: TemplateFieldOption | undefined =
      definition.options.find((option: TemplateFieldOption) => option.value === field.value)
    return matched === undefined ? undefined : matched.icon
  }

  private optionMenuItem(field: EntryFieldEditor, option: TemplateFieldOption): MenuElement {
    return {
      value: option.value,
      icon: option.icon,
      action: () => this.editor.setFieldValue(field, option.value),
    }
  }

  // 模板字段的字段名与类型由模板定义，草稿行只承载取值。
  @Builder
  private templateFieldRow(definition: TemplateFieldDefinition) {
    FormItem({
      label: definition.label,
      contentBuilder: () => {
        this.templateFieldInput(this.editor.templateField(definition.key)!, definition)
      },
    })
      .id(`field_${definition.key}`)
      .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })
  }

  // 组件必须在 @Builder 作用域内创建：直接写进 FormItem 的箭头参数里不会被编译成组件创建
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
      onActivity: () => this.viewModel.recordActivity(),
    })
  }

  @Builder
  private attachmentRow(definition: TemplateFieldDefinition) {
    FormItem({
      label: definition.label,
      contentBuilder: this.attachmentField,
    })
      .id('field_attachments')
      .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })
  }

  @Builder
  private sshKeysRow(definition: TemplateFieldDefinition) {
    FormItem({
      label: definition.label,
      contentBuilder: this.sshKeysField,
    })
      .id(`field_${definition.key}`)
      .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })
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

  @LocalBuilder
  private otherFieldLabel() {
    Row() {
      Text($r('app.string.field_other'))
        .fontColor($r('app.color.ds_text_secondary'))
        .fontSize($r('sys.float.Body_M'))
    }
    .width('100%')
    .padding({ left: $r('app.float.ds_space_16') })
  }

  @Builder
  private generatorBottomActions() {
    Row({ space: $r('app.float.ds_space_sm') }) {
      Row() {
        DsButton({
          label: $r('app.string.regenerate_password'),
          tone: DsButtonTone.Default,
          leadingIcon: $r('app.string.symbol_refresh'),
          fullWidth: true,
          onTap: () => this.viewModel.generator.regenerate(),
        })
      }
      .layoutWeight(1)

      Row() {
        DsButton({
          label: $r('app.string.fill_current_entry'),
          leadingIcon: $r('app.string.symbol_check'),
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
      actions: this.generatorActions(),
      bodyBuilder: this.generatorBody,
      bottomBarBuilder: this.generatorBottomBar,
      contentBehindTitleBar: true,
    })
  }

  private generatorActions(): DsPageHeaderAction[] {
    return [{ icon: $r('app.string.symbol_close'), label: $r('app.string.close'), onTap: () => this.closeGeneratorSheet() }]
  }

  @LocalBuilder
  private groupBuilder() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: $r('app.float.ds_space_sm') }) {
        Stack() {
          SymbolGlyph($r('app.string.symbol_folder_filled'))
            .fontSize($r('sys.float.Title_L'))
            .fontColor([$r('app.color.ds_primary')])
        }
        .padding($r('app.float.ds_space_xs'))
        .borderRadius('50%')
        .backgroundColor($r('app.color.ds_surface_high'))

        Column({ space: $r('app.float.ds_space_2') }) {
          Text(this.editor.groupName)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontColor($r('app.color.ds_text_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.editor.groupPath)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('app.color.ds_text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (!this.readOnly) {
          SymbolGlyph($r('app.string.symbol_chevron_right'))
            .fontSize($r('sys.float.Title_S'))
            .fontColor([$r('app.color.ds_text_secondary')])
        }
      }
      .width('100%')
    }
    .padding($r('app.float.ds_space_sm'))
    .backgroundColor($r('app.color.ds_surface_high'))
    .borderRadius($r('app.float.ds_radius_none'))
    .enabled(!this.readOnly)
    .onClick(() => this.groupPickerVisible = true)
  }

  // 选择器自带标题栏与菜单，半模态壳只配容器参数；与编辑半模态同高，故不设挡位。
  @LocalBuilder
  private groupPickerSheet() {
    EntryGroupPicker({
      initialGroupUuid: this.editor.groupUuid,
      bottomOffset: this.bottomOffset,
      onPicked: (groupUuid: string) => {
        this.editor.setGroup(this.viewModel.requireGroup(groupUuid))
        this.groupPickerVisible = false
      },
      onClose: () => this.groupPickerVisible = false,
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
        Column() {
          EntryAvatarPicker({
            title: this.editor.title,
            avatarData: this.editor.avatarData,
            readOnly: this.readOnly,
            onPicked: (data: ArrayBuffer) => {
              if (this.sheet.mode === EntrySheetMode.Edit) {
                this.editor.setAvatar(data)
              }
            },
            onReset: () => this.editor.clearAvatar(),
          })
            .margin({ bottom: $r('app.float.ds_space_md') })

          FormItem({ label: $r('app.string.group'), contentBuilder: this.groupBuilder })
            .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })

          FormItem({
            label: $r('app.string.entry_title'),
            contentBuilder: this.titleBuilder,
            value: this.editor.title,
            schema: this.editor.titleSchema,
            controller: this.editor.titleController,
            reserveFeedbackSpace: true,
            required: true,
          })
            .id('field_title')
            .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })


          ForEach(this.definition.fields, (definition: TemplateFieldDefinition) => {
            if (definition.reservedField === 'UserName') {
              FormItem({
                label: definition.label,
                contentBuilder: this.usernameBuilder,
                value: this.editor.username,
              })
                .id('field_username')
                .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })
            } else if (definition.reservedField === 'Password') {
              FormItem({
                label: definition.label,
                contentBuilder: this.passwordBuilder,
                value: this.editor.password,
              })
                .id('field_password')
                .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })

              Row() {
                PasswordStrengthIndicator({ password: this.editor.password })
              }
              .width('100%')
              .padding({ left: $r('app.float.ds_space_16'), right: $r('app.float.ds_space_16') })
              .margin({ bottom: $r('app.float.ds_space_md') })
            } else if (definition.reservedField === 'URL') {
              FormItem({
                label: definition.label,
                contentBuilder: this.urlBuilder,
                value: this.editor.url,
              })
                .id('field_url')
                .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })
            } else if (definition.reservedField === 'Notes') {
              FormItem({
                label: definition.label,
                contentBuilder: this.notesBuilder,
                value: this.editor.notes,
              })
                .id('field_notes')
                .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })
            } else if (definition.attachments) {
              this.attachmentRow(definition)
            } else if (definition.sshKeys) {
              this.sshKeysRow(definition)
            } else {
              this.templateFieldRow(definition)
            }
          }, (definition: TemplateFieldDefinition) => definition.key)

          if (!this.readOnly || this.hasOtherFields) {
            FormItem({
              labelBuilder: this.otherFieldLabel,
              contentBuilder: this.customFieldsBuilder,
            })
              .id('field_other')
          }

          if (!this.readOnly || this.editor.tags.length > 0) {
            FormItem({
              label: $r('app.string.tags'),
              contentBuilder: this.tagsBuilder,
            })
              .id('field_tags')
              .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .padding({
          top: $r('app.float.ds_space_lg'),
          bottom: this.bottomOffset,
        })
      }
      .width('100%')
      .height('100%')
      .id('entry_edit_scroll')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onTouch(() => this.viewModel.recordActivity())
      .bindSheet($$this.generatorSheetVisible, this.generatorSheet(), {
        dragBar: true,
        backgroundColor: $r('app.color.ds_surface_lowest'),
        showClose: false,
        onDisappear: () => this.closeGeneratorSheet(),
      })
      .clip(false)
  }

  private editorActions(): DsPageHeaderAction[] {
    return [
      {
        icon: $r('app.string.symbol_check'),
        label: this.viewModel.busy ? $r('app.string.saving') : $r('app.string.save'),
        onTap: () => this.saveEntry(),
      },
      { icon: $r('app.string.symbol_close'), label: $r('app.string.cancel'), onTap: () => this.requestExit() },
    ]
  }

  build() {
    Stack() {
      DsHalfModalSheet({
        title: this.sheet.entryUuid.length === 0
          ? $r('app.string.new_entry') : $r('app.string.edit'),
        actions: this.editorActions(),
        bodyBuilder: this.editorBody,
      })
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.groupPickerVisible, this.groupPickerSheet(), {
      dragBar: true,
      backgroundColor: $r('app.color.ds_surface_lowest'),
      showClose: false,
      onWillDismiss: (action: DismissSheetAction) => this.onGroupPickerWillDismiss(action),
      onDisappear: () => {
        this.groupPickerVisible = false
        this.groupPickerBackHandler = undefined
      },
    })
  }
}
