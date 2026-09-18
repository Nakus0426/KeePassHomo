import { SymbolGlyphModifier, uiMaterial } from '@kit.ArkUI'
import { hdsMaterial, HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit'
import { AnimationTokens, AppToast, BounceAnimator } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { GeneratorContent, GeneratorContentController } from '../generator/GeneratorComponents'
import { FormItem, Status } from '../../components/FormItem'
import { FormTextArea } from '../../components/FormTextArea'
import { FormTextField, FormTextFieldStatus } from '../../components/FormTextField'
import { PasswordStrengthIndicator } from '../../components/PasswordStrengthIndicator'
import { PasswordVisibilityToggle } from '../../components/PasswordVisibilityToggle'
import { AppSessionState, appSessionState } from '../../state/AppSessionState'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { EntryEditorViewModel } from '../../viewmodel/EntryEditorViewModel'
import { EntryAvatarPicker } from './EntryAvatarPicker'
import { EntryCustomFields } from './EntryCustomFields'
import { EntryTagEditor } from './EntryTagEditor'

@ObservedV2
export class EntryEditSheetState {
  @Trace visible: boolean = false
  @Trace entryUuid: string = ''
}

@ComponentV2
export struct EntryEditSheet {
  @Param state: EntryEditSheetState = new EntryEditSheetState()
  @Local private session: AppSessionState = appSessionState
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private editor: EntryEditorViewModel = new EntryEditorViewModel()
  @Local private generatorSheetVisible: boolean = false
  @Local private passwordVisible: boolean = false
  /** 保存时字段名为空的卡片 id，-1 表示无。 */
  @Local private invalidFieldId: number = -1
  /** 本次关闭是否由保存成功触发，关闭动画结束后据此给出成功提示。 */
  private justSaved: boolean = false
  private readonly viewModel: AppViewModel = appViewModel
  private readonly generatorController: GeneratorContentController = new GeneratorContentController()
  private readonly fillIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.checkmark'))
    .fontColor([$r('sys.color.confirm')])
    .fontSize($r('sys.float.titlebar_icon_width'))
  private bounce: BounceAnimator = new BounceAnimator()
  private readonly scroller: Scroller = new Scroller()
  private readonly sheetMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
  })
  private readonly saveIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.checkmark'))
    .fontColor([$r('sys.color.confirm')])
    .fontSize($r('sys.float.titlebar_icon_width'))
  private readonly cancelIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.xmark'))
    .fontSize($r('sys.float.titlebar_icon_width'))
    .fontColor([$r('sys.color.icon_primary')])

  @Monitor('state.visible')
  onVisibleChanged(): void {
    if (this.state.visible) {
      this.loadEditor()
      return
    }
    this.releaseEditor()
  }

  @Monitor('session.vaultLocked')
  onVaultLockChanged(): void {
    if (this.session.vaultLocked) {
      this.closeSheet()
    }
  }

  private loadEditor(): void {
    this.passwordVisible = false
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

  private closeSheet(): void {
    this.state.visible = false
  }

  private confirmDiscard(onDiscard: () => void): void {
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
        action: () => onDiscard(),
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  private requestExit(): void {
    if (this.viewModel.busy) {
      return
    }
    if (!this.editor.changed()) {
      this.closeSheet()
      return
    }
    this.confirmDiscard(() => this.closeSheet())
  }

  private saveEntry(): void {
    if (this.viewModel.busy) {
      return
    }
    const invalidFieldKey: string | undefined = this.editor.validate()
    if (invalidFieldKey === undefined) {
      this.viewModel.saveEntry(this.editor).then((saved: boolean) => {
        if (saved) {
          this.justSaved = true
          this.closeSheet()
          return
        }
        // 失败原因由 ViewModel 写入 status（只读来源、字段名非法、写盘失败等），必须让用户看见。
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

  /** 保存失败时半模态不会关闭，默认模式的 Toast 层级低于它，必须用高于弹窗类组件的模式。 */
  private toastStatus(): void {
    if (this.viewModel.status.length === 0) {
      return
    }
    AppToast.showAboveSheets(this.getUIContext(), this.viewModel.status)
  }

  /**
   * 保存成功的提示在半模态收完后再弹：默认模式的 Toast 在主窗内、层级低于弹窗类组件，
   * 半模态还在场时会把它盖住。
   */
  private notifySaved(): void {
    if (!this.justSaved) {
      return
    }
    this.justSaved = false
    AppToast.show(this.getUIContext(), $r('app.string.saved'))
  }

  private scrollToField(fieldKey: string): void {
    const componentUtils = this.getUIContext().getComponentUtils()
    const fieldTopPx: number = componentUtils.getRectangleById(`field_${fieldKey}`).windowOffset.y
    const scrollTopPx: number = componentUtils.getRectangleById('entry_edit_scroll').windowOffset.y
    const targetY: number = this.scroller.currentOffset().yOffset +
      this.getUIContext().px2vp(fieldTopPx - scrollTopPx) - this.contentTopOffset
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

  /**
   * 拖拽或返回键关闭半模态时先拦下：有未保存修改就先确认，确认丢失内容才真正关闭。
   * 保存中不弹确认（保存成功会自动关闭），直接拦下本次关闭。
   */
  private onSheetWillDismiss(action: DismissSheetAction): void {
    if (this.viewModel.busy) {
      return
    }
    if (!this.editor.changed()) {
      action.dismiss()
      return
    }
    this.confirmDiscard(() => this.closeSheet())
  }

  private get readOnly(): boolean {
    return this.viewModel.currentSource().readOnly
  }

  @Computed
  get contentTopOffset(): number {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const gapPx = ResUtil.getNumber($r('sys.float.padding_level16').id)
    return this.getUIContext().px2vp(titlebarHeightPx + gapPx)
  }

  @Computed
  get contentBottomOffset(): number {
    return this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx)
  }

  @Computed
  get sheetTopAvoidAreaHeight(): number {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const paddingHeightPx = ResUtil.getNumber($r('sys.float.padding_level12').id)
    return this.getUIContext().px2vp(titlebarHeightPx + paddingHeightPx)
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
      active: this.state.visible,
      topOffset: this.sheetTopAvoidAreaHeight,
      bottomOffset: this.contentBottomOffset,
      onInvalidCleared: () => this.invalidFieldId = -1,
      onActivity: () => this.viewModel.recordActivity(),
    })
  }

  @LocalBuilder
  tagsBuilder() {
    EntryTagEditor({
      editor: this.editor,
      readOnly: this.readOnly,
      active: this.state.visible,
      onActivity: () => this.viewModel.recordActivity(),
    })
  }

  @Builder
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
        topOffset: this.sheetTopAvoidAreaHeight,
        bottomOffset: this.contentBottomOffset,
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
              label: $r('app.string.copy'),
              action: () => this.generatorController.copyPassword(),
            },
          }, {
            content: {
              icon: this.fillIcon,
              label: $r('app.string.fill_current_entry'),
              action: () => this.fillPasswordFromGenerator(),
            },
          }],
        },
      },
    })
  }

  @Builder
  private sheetContent() {
    HdsNavigation() {
      Scroll(this.scroller) {
        Column() {
          EntryAvatarPicker({
            title: this.editor.title,
            avatarData: this.editor.avatarData,
            readOnly: this.readOnly,
            onPicked: (data: ArrayBuffer) => {
              if (this.state.visible) {
                this.editor.setAvatar(data)
              }
            },
            onReset: () => this.editor.clearAvatar(),
          })
            .margin({ bottom: $r('sys.float.padding_level12') })

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
          top: this.contentTopOffset,
          bottom: this.contentBottomOffset,
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
        systemMaterial: new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
        }),
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
          value: [{
            content: {
              icon: this.cancelIcon,
              label: $r('app.string.cancel'),
              action: () => this.requestExit(),
            },
          }, {
            content: {
              icon: this.saveIcon,
              label: this.viewModel.busy ? $r('app.string.saving') : $r('app.string.save'),
              action: () => this.saveEntry(),
            },
          }],
        },
      },
    })
  }

  build() {
    Stack()
      .width(0)
      .height(0)
      .bindSheet(this.state.visible, this.sheetContent(), {
        dragBar: true,
        showClose: false,
        backgroundColor: Color.Transparent,
        systemMaterial: this.sheetMaterial,
        onWillDismiss: (action: DismissSheetAction) => this.onSheetWillDismiss(action),
        onDisappear: () => {
          this.state.visible = false
          this.notifySaved()
        },
      })
  }
}
