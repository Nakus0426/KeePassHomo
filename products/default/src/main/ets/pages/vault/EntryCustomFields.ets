import { LengthMetrics } from '@kit.ArkUI'
import { AnimationTokens, VaultFieldType } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { FIELD_TYPE_DEFINITIONS, FieldTypeDefinition, fieldTypeDefinition } from '../../model/FieldTypeCatalog'
import { PASSWORD_FONT_FAMILY } from '../../constants/FontConstants'
import { EntryEditorViewModel, EntryFieldEditor } from '../../viewmodel/EntryEditorViewModel'
import { appViewModel, AppViewModel } from '../../viewmodel/AppViewModel'
import { DsHalfModalSheet } from '../../components/DsHalfModalSheet'
import { dsSheetOptions } from '../../components/DsSheetOptions'
import { DsInput, DsInputVariant } from '../../components/DsInput'
import { IconToggleButton } from '../../components/IconToggleButton'
import { DsButton, DsButtonVariant, DsButtonTone } from '../../components/DsButton'
import { DsContextMenu } from '../../components/DsContextMenu'
import { DsPickCard } from '../../components/DsPickCard'
import { DsListRowMotion } from '../../components/DsListRowMotion'
import { LIST_ROW_PUSH_IN } from '../../components/ListRowEnterTransition'

import { DsMenuGroup } from '../../components/DsMenuGroup'
import { DsMenuItem, DsMenuItemTheme } from '../../components/DsMenuItem'
import { DsToastHost } from '../../components/DsToast'

// 窄屏一行 2 个，宽屏一行最多 3 个；与模板选择器同档，按组件宽度切档，宽度由列数均分。
const FIELD_TYPE_CARD_COLUMNS: GridRowColumnOption = {
  xs: 2,
  sm: 2,
  md: 3,
  lg: 3,
  xl: 3,
  xxl: 3,
}
const FIELD_TYPE_CARD_BREAKPOINTS: string[] = ['320vp', '600vp', '840vp']

// 掩码上限：避免撑成多行，也不暴露密码完整长度。
const PASSWORD_MASK_MAX: number = 12
// 名称与值的行高：预览与沉浸编辑共用同一值，进出编辑态卡片高度不变。
const FIELD_NAME_LINE_HEIGHT: number = 18
const FIELD_LINE_HEIGHT: number = 20

// 类型卡与模板卡同构：图标独占首行，标题 / 说明在图标下方占满卡片宽度。
@ComponentV2
struct FieldTypeCard {
  @Require @Param definition: FieldTypeDefinition
  @Event onPick: () => void = () => {
  }

  @LocalBuilder
  private cardContent() {
    Image(this.definition.icon)
      .draggable(false)
      .width($r('app.float.ds_field_type_icon_size'))
      .height($r('app.float.ds_field_type_icon_size'))
      .objectFit(ImageFit.Contain)

    Column({ space: $r('app.float.ds_space_2') }) {
      Text(this.definition.label)
        .width('100%')
        .fontSize($r('app.float.ds_font_title'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.definition.description)
        .width('100%')
        .fontSize($r('app.float.ds_font_body_sm'))
        .fontColor($r('app.color.ds_text_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    DsPickCard({
      onPick: this.onPick,
      contentBuilder: this.cardContent,
    })
  }
}

@ComponentV2
export struct EntryCustomFields {
  @Param editor: EntryEditorViewModel = new EntryEditorViewModel()
  @Param readOnly: boolean = false
  @Param invalidFieldId: number = -1
  @Param active: boolean = false
  @Param bottomOffset: number = 0
  @Event onInvalidCleared: () => void = () => {
  }
  @Event onActivity: () => void = () => {
  }
  @Local private typeSheetVisible: boolean = false
  // 名称与值各自独立编辑：-1 表示该行不在编辑态。
  @Local private editingNameFieldId: number = -1
  @Local private editingValueFieldId: number = -1
  @Local private draftName: string = ''
  @Local private draftValue: string = ''
  // 新建字段的名称需要全选，只在首次取焦的实例上生效。
  @Local private selectAllName: boolean = false
  // 预览态被点开的密码字段：-1 表示全部掩码。
  @Local private visibleFieldId: number = -1
  @Local private pressedFieldId: number = -1
  @Local private hoveredFieldId: number = -1
  // 正在离场的字段：卡片据此收高倒塌，动画结束后才删数据。
  @Local private removingFieldId: number = -1
  // 从菜单点删除时先记下，等菜单退场完再启动离场动画，否则整段动画被菜单遮住。
  private pendingDeleteFieldId: number = -1
  private pendingDefinition: FieldTypeDefinition | undefined = undefined
  private readonly viewModel: AppViewModel = appViewModel
  // 绑定给标题栏渐变模糊：未绑定滚动容器时材质会常驻，内容还没上移就出现模糊带。
  private readonly scroller: Scroller = new Scroller()

  // 会话关闭即作废待删登记：换成另一条目后菜单才收起，会误删同 id 的字段。
  @Monitor('active')
  onActiveChanged(): void {
    if (!this.active) {
      this.typeSheetVisible = false
      this.pendingDefinition = undefined
      this.pendingDeleteFieldId = -1
      this.closeCellEdit()
    }
  }

  // 模板字段由模板区渲染，这里只列用户自定义字段。
  @Computed
  get customFields(): EntryFieldEditor[] {
    return this.editor.customFields()
  }

  private openTypeSheet(): void {
    this.onActivity()
    this.typeSheetVisible = true
  }

  private closeTypeSheet(): void {
    this.typeSheetVisible = false
  }

  // 弹窗在场时会收回焦点并遮挡新增转场，新增与进入字段名编辑态须推迟到弹窗退场后。
  private onTypeSheetDisappear(): void {
    this.typeSheetVisible = false
    const definition: FieldTypeDefinition | undefined = this.pendingDefinition
    if (definition === undefined) {
      return
    }
    this.pendingDefinition = undefined
    this.getUIContext().animateTo(AnimationTokens.FEEDBACK_ANIMATION, () => {
      this.editor.addField(definition.type, definition.defaultName)
      const field: EntryFieldEditor = this.editor.fields[this.editor.fields.length - 1]
      this.openNameEdit(field)
      this.selectAllName = true
    })
  }

  private pickType(definition: FieldTypeDefinition): void {
    this.pendingDefinition = definition
    this.onActivity()
    this.closeTypeSheet()
  }

  // 先在原位收高、后倾倒塌，动画结束后才删数据：卡片始终留在自己的位置，不会浮到其他卡片之上。
  private deleteField(field: EntryFieldEditor): void {
    if (this.removingFieldId !== -1) {
      return
    }
    if (field.id === this.editingNameFieldId || field.id === this.editingValueFieldId) {
      this.closeCellEdit()
    }
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.EASE_EXIT,
      onFinish: () => {
        // 会话已关闭（切条目/收起面板）时不再写回，避免动画结束落在已释放的草稿上。
        if (!this.active) {
          return
        }
        this.editor.removeField(field)
        if (field.id === this.invalidFieldId) {
          this.onInvalidCleared()
        }
        this.removingFieldId = -1
      },
    }, () => {
      this.removingFieldId = field.id
    })
    this.onActivity()
  }

  // 菜单项只登记待删字段：菜单退场动画与预览浮层会遮住卡片，等它消失再开始离场。
  private requestDeleteFromMenu(field: EntryFieldEditor): void {
    this.pendingDeleteFieldId = field.id
  }

  private onFieldMenuDisappear(): void {
    const fieldId: number = this.pendingDeleteFieldId
    if (fieldId === -1) {
      return
    }
    this.pendingDeleteFieldId = -1
    const field: EntryFieldEditor | undefined =
      this.customFields.find((item: EntryFieldEditor) => item.id === fieldId)
    if (field === undefined) {
      return
    }
    this.deleteField(field)
  }

  private openNameEdit(field: EntryFieldEditor): void {
    if (this.readOnly) {
      return
    }
    this.onActivity()
    this.draftName = field.name
    this.selectAllName = false
    this.editingNameFieldId = field.id
  }

  private openValueEdit(field: EntryFieldEditor): void {
    if (this.readOnly) {
      return
    }
    this.onActivity()
    this.draftValue = field.value
    this.editingValueFieldId = field.id
  }

  private closeCellEdit(): void {
    this.editingNameFieldId = -1
    this.editingValueFieldId = -1
    this.draftName = ''
    this.draftValue = ''
    this.selectAllName = false
  }

  // 输入即写回，所见即所得；失焦只负责退出编辑态。空名保留上次有效名称，由保存校验拦截新建空名。
  private changeName(field: EntryFieldEditor, value: string): void {
    this.draftName = value
    const name: string = value.trim()
    if (name.length === 0) {
      return
    }
    this.editor.renameField(field, name)
    if (field.id === this.invalidFieldId) {
      this.onInvalidCleared()
    }
  }

  private exitNameEdit(field: EntryFieldEditor): void {
    if (this.editingNameFieldId !== field.id) {
      return
    }
    const empty: boolean = this.draftName.trim().length === 0
    this.editingNameFieldId = -1
    this.selectAllName = false
    this.draftName = ''
    if (empty) {
      DsToastHost.show(this.getUIContext(), $r('app.string.field_name_required'))
    }
    this.onActivity()
  }

  private changeValue(field: EntryFieldEditor, value: string): void {
    this.draftValue = value
    this.editor.setFieldValue(field, value)
  }

  private exitValueEdit(field: EntryFieldEditor): void {
    if (this.editingValueFieldId !== field.id) {
      return
    }
    this.editingValueFieldId = -1
    this.draftValue = ''
    this.onActivity()
  }

  private isEditingName(field: EntryFieldEditor): boolean {
    return this.editingNameFieldId === field.id
  }

  private isEditingValue(field: EntryFieldEditor): boolean {
    return this.editingValueFieldId === field.id
  }

  private nameFocusKey(field: EntryFieldEditor): string {
    return `field_name_${field.id}`
  }

  private valueFocusKey(field: EntryFieldEditor): string {
    return `field_value_${field.id}`
  }

  // 预览态点卡片切换掩码；掩码只影响展示，不改字段值。
  private displayValue(field: EntryFieldEditor): ResourceStr {
    if (this.showPlainValue(field)) {
      return field.value
    }
    if (field.value.length === 0) {
      return ''
    }
    const maskChar: string = ResUtil.getStringSync($r('app.string.password_mask_char'))
    return maskChar.repeat(Math.min(field.value.length, PASSWORD_MASK_MAX))
  }

  private toggleValue(field: EntryFieldEditor): void {
    if (this.readOnly || field.type !== VaultFieldType.Password) {
      return
    }
    this.visibleFieldId = this.visibleFieldId === field.id ? -1 : field.id
    if (this.isEditingValue(field)) {
      this.getUIContext().getFocusController().requestFocus(this.valueFocusKey(field))
    }
    this.onActivity()
  }

  private copy(text: string): void {
    if (text.length === 0) {
      return
    }
    this.viewModel.copyValue(text).then((copied: boolean) => {
      if (copied) {
        DsToastHost.show(this.getUIContext(), $r('app.string.copy_completed'))
      }
    })
  }

  // 菜单内容必须落在 @Builder 方法里：@BuilderParam 传箭头函数会报 class constructor 错误。
  @LocalBuilder
  private copyMenuItems(field: EntryFieldEditor) {
    DsMenuItem({
      icon: $r('app.string.symbol_copy'),
      label: $r('app.string.copy_field_name'),
      onAction: () => this.copy(field.name),
    })
    DsMenuItem({
      icon: $r('app.string.symbol_copy'),
      label: $r('app.string.copy_field_value'),
      onAction: () => this.copy(field.value),
    })
  }

  @LocalBuilder
  private deleteMenuItem(field: EntryFieldEditor) {
    DsMenuItem({
      icon: $r('app.string.symbol_delete'),
      label: $r('app.string.delete_field'),
      theme: DsMenuItemTheme.Error,
      onAction: () => this.requestDeleteFromMenu(field),
    })
  }

  @LocalBuilder
  private menuContent(field: EntryFieldEditor) {
    DsMenuGroup({
      dividerTop: false,
      content: () => {
        this.copyMenuItems(field)
      },
    })
    if (!this.readOnly) {
      DsMenuGroup({
        dividerTop: true,
        content: () => {
          this.deleteMenuItem(field)
        },
      })
    }
  }

  // 头部单行：类型图标与字段名给出对象身份，右侧标签说明字段类型。
  @LocalBuilder
  private menuHeader(field: EntryFieldEditor) {
    Row() {
      Row({ space: $r('app.float.ds_space_xs') }) {
        Image(fieldTypeDefinition(field.type).icon)
          .draggable(false)
          .syncLoad(true)
          .width($r('app.float.ds_icon_md'))
          .height($r('app.float.ds_icon_md'))
          .objectFit(ImageFit.Contain)

        Text(field.name)
          .fontSize($r('app.float.ds_font_body'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)

      Row() {
        Text(fieldTypeDefinition(field.type).label)
          .fontSize($r('app.float.ds_font_label_md'))
          .fontWeight(600)
          .letterSpacing($r('app.float.ds_tracking_wide_md'))
          .fontColor($r('app.color.ds_text_primary'))
          .maxLines(1)
      }
      .height($r('app.float.ds_context_menu_tag_height'))
      .padding({ left: $r('app.float.ds_space_xs'), right: $r('app.float.ds_space_sm') })
      .backgroundColor($r('app.color.ds_surface_high'))
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({
      top: $r('app.float.ds_space_md'),
      bottom: $r('app.float.ds_space_md'),
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
    })
    .backgroundColor($r('app.color.ds_surface_low'))
  }

  // 菜单挂在卡片上：长按由系统截图浮起并压暗页面，卡片自身不重绘。
  @LocalBuilder
  private fieldMenu(field: EntryFieldEditor) {
    DsContextMenu({
      header: () => {
        this.menuHeader(field)
      },
      content: () => {
        this.menuContent(field)
      },
    })
  }

  @LocalBuilder
  private typeIcon(field: EntryFieldEditor) {
    Image(fieldTypeDefinition(field.type).icon)
      .draggable(false)
      // 进出编辑态会重建卡片子树，异步解码会让图标闪一帧空白。
      .syncLoad(true)
      .width($r('app.float.ds_icon_md'))
      .height($r('app.float.ds_icon_md'))
      .objectFit(ImageFit.Contain)
  }

  // 密码值用等宽字体，掩码与明文切换时字宽不跳。
  @LocalBuilder
  private valueText(field: EntryFieldEditor) {
    Text(this.displayValue(field))
      .fontSize($r('app.float.ds_font_body'))
      .fontFamily(field.type === VaultFieldType.Password ? PASSWORD_FONT_FAMILY : undefined)
      .lineHeight(FIELD_LINE_HEIGHT)
      .fontColor($r('app.color.ds_text_secondary'))
      .wordBreak(WordBreak.BREAK_ALL)
      .layoutWeight(1)
  }

  // 密码值在预览与编辑中都按掩码显示，眼睛只切当前字段的展示。
  private showPlainValue(field: EntryFieldEditor): boolean {
    return field.type !== VaultFieldType.Password || field.id === this.visibleFieldId
  }

  @LocalBuilder
  private eyeButton(field: EntryFieldEditor) {
    IconToggleButton({
      symbol: $r('app.string.symbol_eye_off'),
      symbolChecked: $r('app.string.symbol_eye'),
      checked: this.showPlainValue(field),
      symbolColor: $r('app.color.ds_text_tertiary'),
      boxSize: FIELD_LINE_HEIGHT,
      iconSizeOverride: $r('app.float.ds_icon_sm'),
      accessibilityLabel: this.showPlainValue(field) ? $r('app.string.hide') : $r('app.string.show'),
      onToggle: () => this.toggleValue(field),
    })
      .margin({ left: $r('app.float.ds_space_xs') })
  }

  // 名称行：单行输入，溢出横向滚动；预览态即只读文本。
  @LocalBuilder
  private nameRow(field: EntryFieldEditor) {
    if (this.isEditingName(field)) {
      DsInput({
        text: this.draftName,
        placeholder: $r('app.string.field_name'),
        variant: DsInputVariant.Inline,
        fontSizeOverride: $r('app.float.ds_font_title'),
        fontWeightOverride: 600,
        lineHeightOverride: FIELD_NAME_LINE_HEIGHT,
        focusKey: this.nameFocusKey(field),
        autoFocus: true,
        selectAll: this.selectAllName,
        onChange: (value: string) => this.changeName(field, value),
        onSubmit: () => this.exitNameEdit(field),
        onFocusChange: (focused: boolean) => {
          if (!focused) {
            this.exitNameEdit(field)
          }
        },
      })
    } else {
      Text(field.name)
        .width('100%')
        .fontSize($r('app.float.ds_font_title'))
        .fontWeight(600)
        .lineHeight(FIELD_NAME_LINE_HEIGHT)
        .fontColor($r('app.color.ds_text_primary'))
        .maxLines(1)
        .constraintSize({ minHeight: FIELD_NAME_LINE_HEIGHT })
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .onClick(() => this.openNameEdit(field))
    }
  }

  // 值行：预览与编辑都按内容行数展开，行高一致，切换不跳。
  @LocalBuilder
  private valueRow(field: EntryFieldEditor) {
    Row() {
      if (this.isEditingValue(field)) {
        Column() {
          // TextArea 不支持密码输入类型，密码值改用单行输入以保留掩码。
          DsInput({
            text: this.draftValue,
            placeholder: $r('app.string.text_input_placeholder'),
            variant: DsInputVariant.Inline,
            multiline: field.type !== VaultFieldType.Password,
            minLines: 1,
            type: this.showPlainValue(field) ? InputType.Normal : InputType.Password,
            showPassword: this.showPlainValue(field),
            fontSizeOverride: $r('app.float.ds_font_body'),
            fontFamilyOverride: field.type === VaultFieldType.Password ? PASSWORD_FONT_FAMILY : undefined,
            lineHeightOverride: FIELD_LINE_HEIGHT,
            focusKey: this.valueFocusKey(field),
            autoFocus: true,
            enterKeyType: EnterKeyType.Done,
            onChange: (value: string) => this.changeValue(field, value),
            onSubmit: () => this.exitValueEdit(field),
            onFocusChange: (focused: boolean) => {
              if (!focused) {
                this.exitValueEdit(field)
              }
            },
          })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      } else {
        this.valueText(field)
      }

      if (field.type === VaultFieldType.Password) {
        this.eyeButton(field)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: FIELD_LINE_HEIGHT })
    .alignItems(VerticalAlign.Top)
    .onClick(() => {
      if (!this.isEditingValue(field)) {
        this.openValueEdit(field)
      }
    })
  }

  // 常态 → 悬停 → 按下只换底色阶；编辑中抬一档，与设计稿的沉浸编辑卡片一致。
  private cardFill(field: EntryFieldEditor): ResourceColor {
    if (this.pressedFieldId === field.id) {
      return $r('app.color.ds_surface_highest')
    }
    if (this.hoveredFieldId === field.id || this.isEditingName(field) || this.isEditingValue(field)) {
      return $r('app.color.ds_surface_high')
    }
    return $r('app.color.ds_surface_low')
  }

  @LocalBuilder
  private cardBody(field: EntryFieldEditor) {
    Row({ space: $r('app.float.ds_space_sm') }) {
      this.typeIcon(field)

      Column({ space: $r('app.float.ds_space_6') }) {
        this.nameRow(field)
        this.valueRow(field)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .padding($r('app.float.ds_space_md'))
    .backgroundColor(this.cardFill(field))
    .borderRadius($r('app.float.ds_radius_none'))
    .animation(AnimationTokens.FEEDBACK_ANIMATION)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedFieldId = field.id
        return
      }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedFieldId = -1
      }
    })
    .onHover((isHover: boolean) => {
      this.hoveredFieldId = isHover ? field.id : -1
    })
  }

  // 编辑中不挂菜单：长按留给文本选择，避免菜单与输入焦点互抢。删除前已退出编辑态，离场样式只挂在常态分支。
  @LocalBuilder
  private fieldCard(field: EntryFieldEditor) {
    if (this.isEditingName(field) || this.isEditingValue(field)) {
      Column() {
        this.cardBody(field)
      }
      .width('100%')
      .id(`field_${field.id}`)
      .transition(LIST_ROW_PUSH_IN)
    } else {
      // 外层 Column 只承载 id 与长按菜单：组件带尾随 Builder 时无法在调用处继续链属性。
      Column() {
        DsListRowMotion({
          leaving: field.id === this.removingFieldId,
          enterTransition: LIST_ROW_PUSH_IN,
        }) {
          Column() {
            this.cardBody(field)
          }
          .width('100%')
        }
      }
      .width('100%')
      .id(`field_${field.id}`)
      .bindContextMenu(this.fieldMenu(field), ResponseType.LongPress, {
        preview: MenuPreviewMode.IMAGE,
        previewBorderRadius: $r('app.float.ds_radius_none'),
        borderRadius: $r('app.float.ds_radius_none'),
        backgroundColor: $r('app.color.ds_surface_lowest'),
        backgroundBlurStyle: BlurStyle.NONE,
        targetSpace: LengthMetrics.vp(4),
        hapticFeedbackMode: HapticFeedbackMode.ENABLED,
        mask: {
          color: $r('app.color.ds_scrim'),
          backgroundBlurStyle: BlurStyle.NONE,
        },
        onDisappear: () => this.onFieldMenuDisappear(),
      })
    }
  }

  @LocalBuilder
  private addFieldBuilder() {
    DsButton({
      label: $r('app.string.add_field'),
      variant: DsButtonVariant.Dashed,
      tone: DsButtonTone.Default,
      leadingIcon: $r('app.string.symbol_add'),
      fullWidth: true,
      onTap: () => this.openTypeSheet(),
    })
  }

  @LocalBuilder
  private typeSheetBody() {
    Scroll(this.scroller) {
      Column() {
        GridRow({
          columns: FIELD_TYPE_CARD_COLUMNS,
          gutter: { x: $r('app.float.ds_space_sm'), y: $r('app.float.ds_space_sm') },
          breakpoints: {
            value: FIELD_TYPE_CARD_BREAKPOINTS,
            reference: BreakpointsReference.ComponentSize,
          },
        }) {
          ForEach(FIELD_TYPE_DEFINITIONS, (definition: FieldTypeDefinition) => {
            GridCol({ span: 1 }) {
              FieldTypeCard({
                definition: definition,
                onPick: () => this.pickType(definition),
              })
            }
          }, (definition: FieldTypeDefinition) => definition.type)
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding({
        top: $r('app.float.ds_space_16'),
        bottom: this.bottomOffset > 0 ? this.bottomOffset : $r('app.float.ds_space_16'),
        left: $r('app.float.ds_space_16'),
        right: $r('app.float.ds_space_16'),
      })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    // alwaysEnabled：内容不足一屏时也由滚动容器接管竖向手势，避免上下滑动拖动整个半模态。
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true, effectEdge: EffectEdge.START | EffectEdge.END })
    .align(Alignment.Top)
    .clip(false)
  }

  @LocalBuilder
  private typeSheet() {
    DsHalfModalSheet({
      title: $r('app.string.select_type'),
      actions: [{ icon: $r('app.string.symbol_close'), label: $r('app.string.close'), onTap: () => this.closeTypeSheet() }],
      scrollableScroller: this.scroller,
      bodyBuilder: this.typeSheetBody,
    })
  }

  build() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      ForEach(this.customFields, (field: EntryFieldEditor) => {
        this.fieldCard(field)
      }, (field: EntryFieldEditor) => `${field.id}`)

      if (!this.readOnly) {
        this.addFieldBuilder()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .bindSheet($$this.typeSheetVisible, this.typeSheet(), dsSheetOptions({
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      // 默认 FOLLOW_DETENT 只在跟手结束后重排内容，多挡位拖动时会看到内容截断与松手跳变。
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      // 系统控制条样式与设计不符，保留 DsHalfModalSheet 自绘拖拽条。
      dragBar: false,
      onDisappear: () => this.onTypeSheetDisappear(),
    }))
  }
}
