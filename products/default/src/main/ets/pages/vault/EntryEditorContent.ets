import { SymbolGlyphModifier, uiMaterial } from '@kit.ArkUI'
import { hdsMaterial, HdsNavigation, HdsNavigationTitleMode, IconStyleMode, ScrollEffectType } from '@kit.UIDesignKit'
import { AnimationTokens, AppToast, BounceAnimator } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { GeneratorContent, GeneratorContentController } from '../generator/GeneratorComponents'
import { FormItem, Status } from '../../components/FormItem'
import { FormTextArea } from '../../components/FormTextArea'
import { FormTextField, FormTextFieldStatus } from '../../components/FormTextField'
import { PasswordStrengthIndicator } from '../../components/PasswordStrengthIndicator'
import { PasswordVisibilityToggle } from '../../components/PasswordVisibilityToggle'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { EntryEditorViewModel } from '../../viewmodel/EntryEditorViewModel'
import { EntrySheetMode, EntrySheetState } from '../../viewmodel/EntrySheetState'
import { EntryAvatarPicker } from './EntryAvatarPicker'
import { EntryCustomFields } from './EntryCustomFields'
import { EntryGroupPicker } from './EntryGroupPicker'
import { EntryTagEditor } from './EntryTagEditor'

/**
 * 编辑态内容：半模态内的第二种形态，负责表单、校验与保存。
 * 不持有 bindSheet —— 容器由 EntrySheet 宿主管理，本组件只做内容与草稿。
 * 草稿归本组件所有，因此「有未保存改动」只有这里答得出来，宿主靠注册钩子取。
 */
@ComponentV2
export struct EntryEditorContent {
  @Param state: EntrySheetState = new EntrySheetState()
  /** 标题栏与内容区的避让尺寸，由宿主按半模态测量结果下发。 */
  @Param topOffset: number = 0
  @Param bottomOffset: number = 0
  /** 把「请求放弃改动」的钩子交给宿主：宿主在拖拽收起前调用它弹确认。 */
  @Event onWillDismissCheck: (handler: () => void) => void = () => {
  }
  @Event onCancel: () => void = () => {
  }
  @Event onSaved: () => void = () => {
  }
  @Local private editor: EntryEditorViewModel = new EntryEditorViewModel()
  @Local private passwordVisible: boolean = false
  @Local private generatorSheetVisible: boolean = false
  @Local private groupPickerVisible: boolean = false
  /** 选择器注册的返回消费者：返回 true 表示这次返回已用于回退层级，半模态不收起。 */
  private groupPickerBackHandler: (() => boolean) | undefined = undefined
  /** 保存时字段名为空的卡片 id，-1 表示无。 */
  @Local private invalidFieldId: number = -1
  private readonly viewModel: AppViewModel = appViewModel
  private readonly scroller: Scroller = new Scroller()
  private readonly generatorController: GeneratorContentController = new GeneratorContentController()
  private readonly fillIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.checkmark'))
    .fontColor([$r('sys.color.confirm')])
  private bounce: BounceAnimator = new BounceAnimator()
  private readonly saveIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.checkmark'))
    .fontColor([$r('sys.color.confirm')])
  private readonly cancelIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.xmark'))
    .fontColor([$r('sys.color.icon_primary')])
  private readonly sheetMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
  })

  aboutToAppear(): void {
    this.passwordVisible = false
    this.invalidFieldId = -1
    this.loadEditor()
    this.onWillDismissCheck(() => this.onExternalDismissRequest())
  }

  /**
   * 半模态离开编辑态时丢弃草稿：取消、保存后回预览、拖拽收起都走这里。
   * 不重置就无法区分「草稿」与「已保存内容」，下次进入会带着上一次的残留。
   */
  @Monitor('state.mode')
  onModeChanged(): void {
    if (this.state.mode === EntrySheetMode.Edit) {
      return
    }
    this.releaseEditor()
  }

  private loadEditor(): void {
    if (this.state.entryUuid.length > 0) {
      this.viewModel.loadEntryForEdit(this.editor, this.state.entryUuid)
      return
    }
    this.viewModel.loadNewEntry(this.editor)
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

  /**
   * 宿主在拖拽收起前调用：只有存在未保存改动才需要确认。
   * 无改动时保持静默，由宿主自己收起半模态。
   */
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
        fontColor: $r('sys.color.warning'),
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
      this.getUIContext().px2vp(fieldTopPx - scrollTopPx) - this.topOffset
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
    const padding: number = ResUtil.getNumber($r('sys.float.padding_level4').id)
    return this.getUIContext().px2vp(buttonHeight - padding * 2)
  }

  @LocalBuilder
  titleBuilder() {
    FormTextField({
      placeholder: $r('app.string.text_input_placeholder'),
      text: this.editor.title,
      status: this.editor.titleController.status === Status.Invalid
        ? FormTextFieldStatus.Warning : undefined,
      onChange: (value: string) => this.editor.setTitle(value),
    })
  }

  @LocalBuilder
  usernameBuilder() {
    FormTextField({
      placeholder: $r('app.string.text_input_placeholder'),
      text: this.editor.username,
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
      onChange: (value: string) => this.editor.setPassword(value),
    }) {
      PasswordVisibilityToggle({
        visible: this.passwordVisible,
        onChange: (visible: boolean) => this.passwordVisible = visible,
      })

      Divider()
        .vertical(true)
        .margin({ top: $r('sys.float.padding_level6'), bottom: $r('sys.float.padding_level6') })
        .color($r('sys.color.comp_divider'))

      Button({ type: ButtonType.Circle, stateEffect: true }) {
        SymbolGlyph($r('sys.symbol.wand_and_stars'))
          .fontSize(22)
          .fontColor([$r('sys.color.brand')])
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
      onChange: (value: string) => this.editor.setUrl(value),
    })
  }

  @LocalBuilder
  notesBuilder() {
    FormTextArea({
      placeholder: $r('app.string.text_input_placeholder'),
      text: this.editor.notes,
      onChange: (value: string) => this.editor.setNotes(value),
    })
  }

  @LocalBuilder
  customFieldsBuilder() {
    EntryCustomFields({
      editor: this.editor,
      readOnly: this.readOnly,
      invalidFieldId: this.invalidFieldId,
      active: this.state.mode === EntrySheetMode.Edit,
      topOffset: this.topOffset,
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
      active: this.state.mode === EntrySheetMode.Edit,
      onActivity: () => this.viewModel.recordActivity(),
    })
  }

  @LocalBuilder
  private otherFieldLabel() {
    Row() {
      Text($r('app.string.field_other'))
        .fontColor($r('sys.color.font_secondary'))
        .fontSize($r('sys.float.Body_M'))
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level16') })
  }

  @LocalBuilder
  private generatorSheet() {
    HdsNavigation() {
      GeneratorContent({
        viewModel: this.viewModel.generator,
        controller: this.generatorController,
        topOffset: this.topOffset,
        bottomOffset: this.bottomOffset,
        onActivity: () => this.viewModel.recordActivity(),
      })
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      content: {
        title: {
          mainTitle: $r('app.string.password_generator'),
        },
        menu: {
          value: [{
            content: {
              icon: $r('sys.symbol.doc_text_on_doc_text'),
              type: IconStyleMode.SMALL,
              label: $r('app.string.copy'),
              action: () => this.generatorController.copyPassword(),
            },
          }, {
            content: {
              icon: this.fillIcon,
              type: IconStyleMode.SMALL,
              label: $r('app.string.fill_current_entry'),
              action: () => this.fillPasswordFromGenerator(),
            },
          }],
        },
      },
    })
  }

  @LocalBuilder
  private groupBuilder() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: $r('sys.float.padding_level8') }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.folder_fill'))
            .fontSize($r('sys.float.Title_L'))
            .fontColor([$r('sys.color.brand')])
        }
        .padding($r('sys.float.padding_level4'))
        .borderRadius('50%')
        .backgroundColor($r('sys.color.comp_emphasize_secondary'))

        Column({ space: $r('sys.float.padding_level2') }) {
          Text(this.editor.groupName)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontColor($r('sys.color.font_primary'))
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.editor.groupPath)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (!this.readOnly) {
          SymbolGlyph($r('sys.symbol.chevron_forward'))
            .fontSize($r('sys.float.Title_S'))
            .fontColor([$r('sys.color.font_secondary')])
        }
      }
      .width('100%')
    }
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
    .borderRadius($r('sys.float.corner_radius_level10'))
    .enabled(!this.readOnly)
    .onClick(() => this.groupPickerVisible = true)
  }

  /** 分组选择器自带标题栏与菜单，半模态壳只配容器参数；高度与编辑半模态一致，不设挡位。 */
  @LocalBuilder
  private groupPickerSheet() {
    EntryGroupPicker({
      editor: this.editor,
      bottomOffset: this.bottomOffset,
      onPicked: () => this.groupPickerVisible = false,
      onClose: () => this.groupPickerVisible = false,
      onActivity: () => this.viewModel.recordActivity(),
      onBackHandler: (handler: () => boolean) => this.groupPickerBackHandler = handler,
    })
  }

  /**
   * 选择器半模态的返回拦截：返回键、屏幕边缘返回手势、导航栏返回都归入 PRESS_BACK，
   * 先交给选择器，它还能回退（退出搜索或上一层）就消费掉；其余原因（下拉收起、点遮罩）按默认关闭。
   */
  private onGroupPickerWillDismiss(action: DismissSheetAction): void {
    const backHandler: (() => boolean) | undefined = this.groupPickerBackHandler
    if (action.reason === DismissReason.PRESS_BACK && backHandler !== undefined && backHandler()) {
      return
    }
    action.dismiss()
  }

  build() {
    HdsNavigation() {
      Scroll(this.scroller) {
        Column() {
          EntryAvatarPicker({
            title: this.editor.title,
            avatarData: this.editor.avatarData,
            readOnly: this.readOnly,
            onPicked: (data: ArrayBuffer) => {
              if (this.state.mode === EntrySheetMode.Edit) {
                this.editor.setAvatar(data)
              }
            },
            onReset: () => this.editor.clearAvatar(),
          })
            .margin({ bottom: $r('sys.float.padding_level12') })

          FormItem({ label: $r('app.string.group'), contentBuilder: this.groupBuilder })
            .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

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
            .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })


          FormItem({
            label: $r('app.string.username'),
            contentBuilder: this.usernameBuilder,
            value: this.editor.username,
          })
            .id('field_username')
            .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

          FormItem({
            label: $r('app.string.password'),
            contentBuilder: this.passwordBuilder,
            value: this.editor.password,
          })
            .id('field_password')
            .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

          Row() {
            PasswordStrengthIndicator({ password: this.editor.password })
          }
          .width('100%')
          .padding({ left: $r('sys.float.padding_level16'), right: $r('sys.float.padding_level16') })
          .margin({ bottom: $r('sys.float.padding_level12') })

          FormItem({
            label: $r('app.string.website'),
            contentBuilder: this.urlBuilder,
            value: this.editor.url,
          })
            .id('field_url')
            .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

          FormItem({
            label: $r('app.string.notes'),
            contentBuilder: this.notesBuilder,
            value: this.editor.notes,
          })
            .id('field_notes')
            .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

          if (!this.readOnly || this.editor.fields.length > 0) {
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
              .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
          }
        }
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .padding({
          top: this.topOffset,
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
        backgroundColor: Color.Transparent,
        systemMaterial: this.sheetMaterial,
        showClose: false,
        onDisappear: () => this.closeGeneratorSheet(),
      })
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      content: {
        title: {
          mainTitle: this.state.entryUuid.length === 0
            ? $r('app.string.new_entry') : $r('app.string.edit'),
        },
        menu: {
          // 数组顺序即从左往右的渲染顺序：取消放末位，永远落在最右侧。
          value: [{
            content: {
              icon: this.saveIcon,
              type: IconStyleMode.SMALL,
              label: this.viewModel.busy ? $r('app.string.saving') : $r('app.string.save'),
              action: () => this.saveEntry(),
            },
          }, {
            content: {
              icon: this.cancelIcon,
              type: IconStyleMode.SMALL,
              label: $r('app.string.cancel'),
              action: () => this.requestExit(),
            },
          }],
        },
      },
    })
    .bindSheet($$this.groupPickerVisible, this.groupPickerSheet(), {
      dragBar: true,
      backgroundColor: Color.Transparent,
      systemMaterial: this.sheetMaterial,
      showClose: false,
      onWillDismiss: (action: DismissSheetAction) => this.onGroupPickerWillDismiss(action),
      onDisappear: () => {
        this.groupPickerVisible = false
        this.groupPickerBackHandler = undefined
      },
    })
  }
}
