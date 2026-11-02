import { ListItemModifier } from '@kit.ArkUI'
import { HdsListItem } from '@kit.UIDesignKit'
import { AnimationTokens, VaultFieldType } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { FIELD_TYPE_DEFINITIONS, FieldTypeDefinition, fieldTypeDefinition } from '../../model/FieldTypeCatalog'
import { EntryEditorViewModel, EntryFieldEditor } from '../../viewmodel/EntryEditorViewModel'
import { DsHalfModalSheet } from '../../components/DsHalfModalSheet'
import { DsPageHeaderAction } from '../../components/DsPageHeader'

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
  @Local private editingFieldId: number = -1
  @Local private editingName: boolean = false
  private pendingDefinition: FieldTypeDefinition | undefined = undefined
  // HdsListItem 不支持通用属性，间距与增删转场经 ListItemModifier 下发。
  // animation 必须挂在组合链首个效果上，否则不会作用于后面的 scale。
  private readonly fieldCardItemModifier: ListItemModifier = new ListItemModifier()
    .margin({ bottom: $r('app.float.ds_space_sm') })
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY
        .animation({
          duration: AnimationTokens.STATE_TRANSITION_DURATION,
          curve: AnimationTokens.STATE_TRANSITION_CURVE,
        })
        .combine(TransitionEffect.scale({
          x: AnimationTokens.CARD_ENTER_SCALE,
          y: AnimationTokens.CARD_ENTER_SCALE,
        })),
      TransitionEffect.OPACITY
        .animation({
          duration: AnimationTokens.STATE_TRANSITION_DURATION,
          curve: AnimationTokens.STATE_TRANSITION_CURVE,
        })
        .combine(TransitionEffect.scale({
          x: AnimationTokens.CARD_EXIT_SCALE,
          y: AnimationTokens.CARD_EXIT_SCALE,
        })),
    ))

  @Monitor('active')
  onActiveChanged(): void {
    if (!this.active) {
      this.typeSheetVisible = false
      this.pendingDefinition = undefined
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
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    }, () => {
      this.editor.addField(definition.type, definition.defaultName)
      this.openCellEdit(this.editor.fields[this.editor.fields.length - 1].id, true)
    })
  }

  private pickType(definition: FieldTypeDefinition): void {
    this.pendingDefinition = definition
    this.onActivity()
    this.closeTypeSheet()
  }

  private deleteField(field: EntryFieldEditor): void {
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    }, () => {
      this.editor.removeField(field)
      if (field.id === this.editingFieldId) {
        this.closeCellEdit()
      }
      if (field.id === this.invalidFieldId) {
        this.onInvalidCleared()
      }
    })
    this.onActivity()
  }

  private openCellEdit(fieldId: number, name: boolean): void {
    this.editingFieldId = fieldId
    this.editingName = name
  }

  private closeCellEdit(): void {
    this.editingFieldId = -1
  }

  private isEditingName(fieldId: number): boolean {
    return this.editingFieldId === fieldId && this.editingName
  }

  private isEditingValue(fieldId: number): boolean {
    return this.editingFieldId === fieldId && !this.editingName
  }

  private displayValue(field: EntryFieldEditor): ResourceStr {
    if (field.type !== VaultFieldType.Password || this.isEditingValue(field.id)) {
      return field.value
    }
    if (field.value.length === 0) {
      return ''
    }
    const maskChar: string = ResUtil.getStringSync($r('app.string.password_mask_char'))
    return maskChar.repeat(Math.min(field.value.length, PASSWORD_MASK_MAX))
  }

  private renameField(field: EntryFieldEditor, name: string): void {
    this.editor.renameField(field, name)
    if (field.id === this.invalidFieldId) {
      this.onInvalidCleared()
    }
  }

  // 留白放在槽位而非卡片外边距：ListItem 保持通栏，左滑才能被屏幕边缘裁切。
  @Builder
  private fieldCardSlot(field: EntryFieldEditor) {
    Row() {
      this.fieldCard(field)
    }
    .width('100%')
    .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })
  }

  @Builder
  private fieldCard(field: EntryFieldEditor) {
    Row({ space: $r('app.float.ds_space_sm') }) {
      Image(fieldTypeDefinition(field.type).icon)
        .draggable(false)
        .width($r('app.float.field_row_icon_size'))
        .height($r('app.float.field_row_icon_size'))
        .objectFit(ImageFit.Contain)
        .alignSelf(ItemAlign.Start)

      Column({ space: $r('app.float.ds_space_2') }) {
        if (this.isEditingName(field.id)) {
          TextInput({ text: field.name })
            .id(`custom_field_name_${field.id}`)
            .width('100%')
            .height($r('sys.float.ohos_id_textfield_content_height'))
            .enterKeyType(EnterKeyType.Done)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.ds_text_primary'))
            .padding(0)
            .backgroundColor(Color.Transparent)
            .clip(false)
            .borderRadius(0)
            .onAppear(() => this.getUIContext().getFocusController()
              .requestFocus(`custom_field_name_${field.id}`))
            .onChange((value: string) => this.renameField(field, value))
            .onSubmit(() => this.closeCellEdit())
            .onBlur(() => {
              if (this.isEditingName(field.id)) {
                this.closeCellEdit()
              }
            })
        } else {
          Row() {
            Text(field.name)
              .width('100%')
              .fontSize($r('sys.float.Body_L'))
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.ds_text_primary'))
              .textAlign(TextAlign.Start)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .width('100%')
          .height($r('sys.float.ohos_id_textfield_content_height'))
          .onClick(() => {
            if (!this.readOnly) {
              this.openCellEdit(field.id, true)
            }
          })
        }

        if (this.isEditingValue(field.id)) {
          TextArea({ text: field.value })
            .id(`custom_field_value_${field.id}`)
            .width('100%')
            .constraintSize({ minHeight: $r('sys.float.ohos_id_textfield_content_height') })
            .enterKeyType(EnterKeyType.Done)
            .fontSize($r('sys.float.Body_M'))
            .fontColor($r('app.color.ds_text_primary'))
            .wordBreak(fieldTypeDefinition(field.type).wordBreak)
            .padding(0)
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .clip(false)
            .onAppear(() => this.getUIContext().getFocusController()
              .requestFocus(`custom_field_value_${field.id}`))
            .onChange((value: string) => this.editor.setFieldValue(field, value))
            .onSubmit(() => this.closeCellEdit())
            .onBlur(() => {
              if (this.isEditingValue(field.id)) {
                this.closeCellEdit()
              }
            })
        } else {
          Row() {
            Text(this.displayValue(field))
              .width('100%')
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('app.color.ds_text_primary'))
              .textAlign(TextAlign.Start)
              .wordBreak(fieldTypeDefinition(field.type).wordBreak)
          }
          .width('100%')
          .constraintSize({ minHeight: $r('sys.float.ohos_id_textfield_content_height') })
          .onClick(() => {
            if (!this.readOnly) {
              this.openCellEdit(field.id, false)
            }
          })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('app.string.symbol_chevron_right'))
        .fontSize($r('sys.float.Title_S'))
        .fontColor([$r('app.color.ds_text_secondary')])
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Center)
    }
    .width('100%')
    .id(`field_${field.id}`)
    .alignItems(VerticalAlign.Top)
    .padding($r('app.float.ds_space_sm'))
    .backgroundColor($r('app.color.ds_surface_high'))
    .borderRadius($r('sys.float.ohos_id_corner_radius_text_field'))
    .border({
      width: $r('sys.float.border_width'),
      color: field.id === this.invalidFieldId
        ? $r('app.color.ds_warning') : Color.Transparent,
    })
    .animation({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    })
  }

  @LocalBuilder
  private addFieldBuilder() {
    Row() {
      Button() {
        Row({ space: $r('app.float.ds_space_xs') }) {
          SymbolGlyph($r('app.string.symbol_add'))
            .fontSize($r('sys.float.chip_normal_icon_size'))
            .fontColor([$r('app.color.ds_text_primary')])

          Text($r('app.string.add'))
            .fontSize($r('sys.float.chip_normal_font_size'))
            .fontColor($r('app.color.ds_text_primary'))
        }
      }
      .width('100%')
      .height($r('sys.float.chip_normal_height'))
      .buttonStyle(ButtonStyleMode.NORMAL)
      .type(ButtonType.Capsule)
      .padding({ left: $r('sys.float.chip_normal_text_padding'), right: $r('sys.float.chip_normal_text_padding') })
      .onClick(() => this.openTypeSheet())
    }
    .width('100%')
    .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private fieldTypeCard(definition: FieldTypeDefinition) {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Column({ space: $r('app.float.ds_space_xs') }) {
        Image(definition.icon)
          .draggable(false)
          .width($r('app.float.field_type_icon_size'))
          .height($r('app.float.field_type_icon_size'))
          .objectFit(ImageFit.Contain)

        Text(definition.label)
          .width('100%')
          .fontSize($r('sys.float.Body_L'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.ds_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(definition.description)
          .width('100%')
          .fontSize($r('sys.float.Body_S'))
          .fontColor($r('app.color.ds_text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height($r('app.float.field_type_card_height'))
    .padding($r('app.float.ds_space_sm'))
    .backgroundColor($r('app.color.ds_surface_high'))
    .borderRadius($r('app.float.ds_radius_none'))
    .onClick(() => this.pickType(definition))
  }

  @LocalBuilder
  private typeSheetBody() {
    Scroll() {
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
              this.fieldTypeCard(definition)
            }
          }, (definition: FieldTypeDefinition) => definition.type)
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding({
        top: $r('app.float.ds_space_lg'),
        bottom: this.bottomOffset,
        left: $r('app.float.ds_space_sm'),
        right: $r('app.float.ds_space_sm'),
      })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
    .clip(false)
  }

  @Builder
  private typeSheet() {
    DsHalfModalSheet({
      title: $r('app.string.select_type'),
      actions: this.typeSheetActions(),
      bodyBuilder: this.typeSheetBody,
    })
  }

  private typeSheetActions(): DsPageHeaderAction[] {
    return [{ icon: $r('app.string.symbol_close'), label: $r('app.string.close'), onTap: () => this.closeTypeSheet() }]
  }

  build() {
    Column() {
      if (this.customFields.length > 0) {
        List() {
          ForEach(this.customFields, (field: EntryFieldEditor) => {
            HdsListItem({
              customItemBuilder: () => {
                this.fieldCardSlot(field)
              },
              listItemModifier: this.fieldCardItemModifier,
              swipeActionOptions: this.readOnly ? undefined : {
                deleteIconOptions: {
                  onAction: () => this.deleteField(field),
                },
              },
            })
          }, (field: EntryFieldEditor) => `${field.id}`)
        }
        .width('100%')
        .height('auto')
        .padding(0)
        .backgroundColor(Color.Transparent)
        .scrollBar(BarState.Off)
        // List 默认裁剪且高度随内容变化，不关掉裁剪会看不到卡片删除时的淡出动画。
        .clip(false)
      }

      if (!this.readOnly) {
        this.addFieldBuilder()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .bindSheet($$this.typeSheetVisible, this.typeSheet(), {
      dragBar: true,
      showClose: false,
      backgroundColor: $r('app.color.ds_surface_lowest'),
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      // 默认 FOLLOW_DETENT 只在跟手结束后重排内容，多挡位拖动时会看到内容截断与松手跳变。
      scrollSizeMode: ScrollSizeMode.CONTINUOUS,
      onDisappear: () => this.onTypeSheetDisappear(),
    })
  }
}
