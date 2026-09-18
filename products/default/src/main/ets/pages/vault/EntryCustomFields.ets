import { ListItemModifier, SymbolGlyphModifier, uiMaterial } from '@kit.ArkUI'
import { HdsListItem, hdsMaterial, HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit'
import { AnimationTokens, ColorUtil, VaultFieldType } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { Cell } from '../../components/Cell'
import { EntryEditorViewModel, EntryFieldEditor } from '../../viewmodel/EntryEditorViewModel'

interface FieldPreset {
  type: VaultFieldType
  label: Resource
  defaultName: string
  icon: Resource
  color: Resource
  wordBreak: WordBreak
}

const FIELD_PRESETS: FieldPreset[] = [
  {
    type: VaultFieldType.Text,
    label: $r('app.string.field_type_text'),
    defaultName: '文本',
    icon: $r('sys.symbol.textformat'),
    color: $r('sys.color.multi_color_01'),
    wordBreak: WordBreak.NORMAL,
  },
  {
    type: VaultFieldType.Url,
    label: $r('app.string.website'),
    defaultName: '网址',
    icon: $r('sys.symbol.link'),
    color: $r('sys.color.multi_color_02'),
    wordBreak: WordBreak.BREAK_ALL,
  },
  {
    type: VaultFieldType.Email,
    label: $r('app.string.field_type_email'),
    defaultName: '邮箱',
    icon: $r('sys.symbol.envelope'),
    color: $r('sys.color.multi_color_03'),
    wordBreak: WordBreak.NORMAL,
  },
  {
    type: VaultFieldType.Phone,
    label: $r('app.string.field_type_phone'),
    defaultName: '电话',
    icon: $r('sys.symbol.phone'),
    color: $r('sys.color.multi_color_04'),
    wordBreak: WordBreak.NORMAL,
  },
  {
    type: VaultFieldType.Address,
    label: $r('app.string.field_type_address'),
    defaultName: '地址',
    icon: $r('sys.symbol.map'),
    color: $r('sys.color.multi_color_05'),
    wordBreak: WordBreak.NORMAL,
  },
  {
    type: VaultFieldType.Date,
    label: $r('app.string.field_type_date'),
    defaultName: '日期',
    icon: $r('sys.symbol.calendar'),
    color: $r('sys.color.multi_color_06'),
    wordBreak: WordBreak.NORMAL,
  },
  {
    type: VaultFieldType.Password,
    label: $r('app.string.password'),
    defaultName: '密码',
    icon: $r('sys.symbol.key'),
    color: $r('sys.color.multi_color_07'),
    wordBreak: WordBreak.BREAK_ALL,
  },
]

const CUSTOM_FIELD_PRESET: FieldPreset = {
  type: VaultFieldType.Custom,
  label: $r('app.string.field_type_custom'),
  defaultName: '',
  icon: $r('sys.symbol.circle_grid_2x2'),
  color: $r('sys.color.multi_color_08'),
  wordBreak: WordBreak.BREAK_ALL,
}

/** 类型弹窗的内置类型顺序：7 个预置类型在前，自定义在最后。 */
const FIELD_TYPE_OPTIONS: FieldPreset[] = FIELD_PRESETS.concat([CUSTOM_FIELD_PRESET])

/** 类型标识圆的背景透明度，与 FileSummaryPage 只读横幅同一取值。 */
const TYPE_CIRCLE_OPACITY: number = 0.2

/** 密码字段预览掩码的最大字符数：避免长密码把预览撑成多行，也不暴露完整长度。 */
const PASSWORD_MASK_MAX: number = 12

/** 卡片入场/出场转场的缩放起点：出场更小，形成"收起"感。 */
const CARD_ENTER_SCALE: number = 0.9
const CARD_EXIT_SCALE: number = 0.8

@ComponentV2
export struct EntryCustomFields {
  @Param editor: EntryEditorViewModel = new EntryEditorViewModel()
  @Param readOnly: boolean = false
  /** 保存校验失败的自定义字段 id，-1 表示无。 */
  @Param invalidFieldId: number = -1
  /** 宿主编辑会话是否打开：会话关闭时复位未提交的输入态与弹窗。 */
  @Param active: boolean = false
  /** 类型弹窗的上下避让高度，由宿主按 sheet 布局传入。 */
  @Param topOffset: number = 0
  @Param bottomOffset: number = 0
  /** 字段被改名或删除后，宿主复位校验失败高亮。 */
  @Event onInvalidCleared: () => void = () => {
  }
  @Event onActivity: () => void = () => {
  }
  @Local private typeSheetVisible: boolean = false
  /** 处于行内编辑态的字段 id，-1 表示无；editingName 区分编辑字段名还是字段值。 */
  @Local private editingFieldId: number = -1
  @Local private editingName: boolean = false
  /** 类型弹窗选中后待新增的字段类型，undefined 表示本次没有选择。 */
  private pendingPreset: FieldPreset | undefined = undefined
  /**
   * 卡片项样式：HdsListItem 不支持通用属性，间距与增删转场都通过 ListItemModifier 下发。
   * 转场配合新增/删除处的 animateTo 使用：入场由小放大淡入，出场缩小淡出并由布局动画收起高度。
   * animation 写在组合链的首个效果上，按官方规则会同时作用于后面的 scale 效果。
   */
  private readonly fieldCardItemModifier: ListItemModifier = new ListItemModifier()
    .margin({ bottom: $r('sys.float.padding_level8') })
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.OPACITY
        .animation({
          duration: AnimationTokens.STATE_TRANSITION_DURATION,
          curve: AnimationTokens.STATE_TRANSITION_CURVE,
        })
        .combine(TransitionEffect.scale({ x: CARD_ENTER_SCALE, y: CARD_ENTER_SCALE })),
      TransitionEffect.OPACITY
        .animation({
          duration: AnimationTokens.STATE_TRANSITION_DURATION,
          curve: AnimationTokens.STATE_TRANSITION_CURVE,
        })
        .combine(TransitionEffect.scale({ x: CARD_EXIT_SCALE, y: CARD_EXIT_SCALE })),
    ))
  private readonly sheetMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
  })
  private readonly cancelIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.xmark'))
    .fontSize($r('sys.float.titlebar_icon_width'))
    .fontColor([$r('sys.color.icon_primary')])

  @Monitor('active')
  onActiveChanged(): void {
    if (!this.active) {
      this.typeSheetVisible = false
      this.pendingPreset = undefined
      this.closeCellEdit()
    }
  }

  private openTypeSheet(): void {
    this.onActivity()
    this.typeSheetVisible = true
  }

  private closeTypeSheet(): void {
    this.typeSheetVisible = false
  }

  /**
   * 类型弹窗退场后再新增字段：弹窗在场时申请的焦点会被弹窗收回、失焦又会立刻退出编辑态，
   * 且新增转场也会被弹窗挡住，因此新增与进入字段名编辑态都推迟到这里。
   */
  private onTypeSheetDisappear(): void {
    this.typeSheetVisible = false
    const preset: FieldPreset | undefined = this.pendingPreset
    if (preset === undefined) {
      return
    }
    this.pendingPreset = undefined
    // 新增放在弹窗退场后：卡片入场转场要在弹窗收走后可见，随即进入字段名编辑态。
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    }, () => {
      this.editor.addField(preset.type, preset.defaultName)
      this.openCellEdit(this.editor.fields[this.editor.fields.length - 1].id, true)
    })
  }

  private pickType(preset: FieldPreset): void {
    this.pendingPreset = preset
    this.onActivity()
    this.closeTypeSheet()
  }

  /**
   * 删除字段卡片。删除动作放在 animateTo 里，卡片按 transition 缩小淡出、其余卡片平滑上移；
   * 被删字段若正在编辑或已被标记校验错误，一并复位。
   */
  private deleteField(field: EntryFieldEditor, index: number): void {
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    }, () => {
      this.editor.removeField(index)
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

  /** 密码字段非编辑态按值长度生成掩码（上限 PASSWORD_MASK_MAX），空值则什么都不显示。 */
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

  /** 类型只可能来自 FIELD_TYPE_OPTIONS，查不到即类型表与枚举不同步。 */
  private presetOf(type: VaultFieldType): FieldPreset {
    return FIELD_TYPE_OPTIONS.find((preset: FieldPreset) => preset.type === type)!
  }

  private renameField(field: EntryFieldEditor, index: number, name: string): void {
    this.editor.renameField(index, name)
    if (field.id === this.invalidFieldId) {
      this.onInvalidCleared()
    }
  }

  /**
   * 卡片槽位：把卡片的左右留白放在这里而不是卡片自身的外边距，
   * ListItem 保持通栏，左滑时卡片才能被屏幕边缘裁切、删除按钮才能从屏幕边缘划出。
   */
  @Builder
  private fieldCardSlot(field: EntryFieldEditor, index: number) {
    Row() {
      this.fieldCard(field, index)
    }
    .width('100%')
    .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
  }

  @Builder
  private fieldCard(field: EntryFieldEditor, index: number) {
    Row({ space: $r('sys.float.padding_level8') }) {
      Row() {
        this.typeIcon(this.presetOf(field.type))
      }
      .alignSelf(ItemAlign.Start)

      Column({ space: $r('sys.float.padding_level2') }) {
        if (this.isEditingName(field.id)) {
          TextInput({ text: field.name })
            .id(`custom_field_name_${field.id}`)
            .width('100%')
            .height($r('sys.float.ohos_id_textfield_content_height'))
            .enterKeyType(EnterKeyType.Done)
            .fontSize($r('sys.float.Body_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .padding(0)
            .backgroundColor(Color.Transparent)
            .clip(false)
            .borderRadius(0)
            .onAppear(() => this.getUIContext().getFocusController()
              .requestFocus(`custom_field_name_${field.id}`))
            .onChange((value: string) => this.renameField(field, index, value))
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
              .fontColor($r('sys.color.font_primary'))
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
            .fontColor($r('sys.color.font_primary'))
            .wordBreak(this.presetOf(field.type).wordBreak)
            .padding(0)
            .backgroundColor(Color.Transparent)
            .borderRadius(0)
            .clip(false)
            .onAppear(() => this.getUIContext().getFocusController()
              .requestFocus(`custom_field_value_${field.id}`))
            .onChange((value: string) => this.editor.setFieldValue(index, value))
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
              .fontColor($r('sys.color.font_primary'))
              .textAlign(TextAlign.Start)
              .wordBreak(this.presetOf(field.type).wordBreak)
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

      SymbolGlyph($r('sys.symbol.chevron_forward'))
        .fontSize($r('sys.float.Title_S'))
        .fontColor([$r('sys.color.font_secondary')])
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Center)
    }
    .width('100%')
    .id(`field_${field.id}`)
    .alignItems(VerticalAlign.Top)
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.ohos_id_corner_radius_text_field'))
    .border({
      width: $r('sys.float.border_width'),
      color: field.id === this.invalidFieldId
        ? $r('sys.color.warning') : $r('sys.color.comp_background_secondary'),
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
        Row({ space: $r('sys.float.padding_level4') }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize($r('sys.float.chip_normal_icon_size'))
            .fontColor([$r('sys.color.font_emphasize')])

          Text($r('app.string.add'))
            .fontSize($r('sys.float.chip_normal_font_size'))
            .fontColor($r('sys.color.font_emphasize'))
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
    .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private typeLabel(preset: FieldPreset) {
    Text(preset.label)
      .fontColor($r('sys.color.font_primary'))
      .fontSize($r('sys.float.Body_L'))
  }

  @Builder
  private typeIcon(preset: FieldPreset) {
    Stack() {
      SymbolGlyph(preset.icon)
        .fontSize($r('sys.float.Subtitle_L'))
        .fontColor([preset.color])
    }
    .padding($r('sys.float.padding_level4'))
    .borderRadius('50%')
    .backgroundColor(ColorUtil.withAlpha(preset.color, TYPE_CIRCLE_OPACITY))
  }

  @Builder
  private typeSheet() {
    HdsNavigation() {
      Scroll() {
        Column() {
          List() {
            ForEach(FIELD_TYPE_OPTIONS, (preset: FieldPreset) => {
              Cell({
                showArrow: true,
                labelBuilder: () => {
                  this.typeLabel(preset)
                },
                prefixBuilder: () => {
                  this.typeIcon(preset)
                },
                onCellClick: () => this.pickType(preset),
              })
            }, (preset: FieldPreset) => `${preset.type}_${preset.defaultName}`)
          }
          .width('100%')
          .height('auto')
          .padding({ left: 0, right: 0 })
          .backgroundColor(Color.Transparent)
          .divider({
            strokeWidth: 1,
            color: $r('sys.color.grid_menu_divider_color'),
            startMargin: $r('sys.float.padding_level8'),
            endMargin: $r('sys.float.padding_level8'),
          })
          .scrollBar(BarState.Off)
        }
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius($r('sys.float.corner_radius_level10'))
        .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({
        top: this.topOffset,
        bottom: this.bottomOffset,
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
      })
      .align(Alignment.Top)
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
          mainTitle: $r('app.string.select_type'),
        },
        menu: {
          value: [{
            content: {
              icon: this.cancelIcon,
              label: $r('app.string.close'),
              action: () => this.closeTypeSheet(),
            },
          }],
        },
      },
    })
  }

  build() {
    Column() {
      if (this.editor.fields.length > 0) {
        List() {
          ForEach(this.editor.fields, (field: EntryFieldEditor, index: number) => {
            HdsListItem({
              customItemBuilder: () => {
                this.fieldCardSlot(field, index)
              },
              listItemModifier: this.fieldCardItemModifier,
              swipeActionOptions: this.readOnly ? undefined : {
                deleteIconOptions: {
                  onAction: () => this.deleteField(field, index),
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
      backgroundColor: Color.Transparent,
      systemMaterial: this.sheetMaterial,
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      onDisappear: () => this.onTypeSheetDisappear(),
    })
  }
}
