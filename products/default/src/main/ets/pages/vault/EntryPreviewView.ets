import { ChipV2, ChipV2Label, ChipV2Options, LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI'
import {
  hdsMaterial,
  HdsNavigation,
  HdsNavigationIconOptions,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleMode,
  IconStyleMode,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { AppSessionState, appSessionState } from '../../state/AppSessionState'
import { EntrySheetViewModel, entrySheetViewModel } from '../../viewmodel/EntrySheetViewModel'
import { EntryAvatar } from '../../components/EntryAvatar'
import { IconToggleButton } from '../../components/IconToggleButton'
import { PasswordVisibilityToggle } from '../../components/PasswordVisibilityToggle'
import { AppToast, RESERVED_FIELD_NAMES, VaultAttachmentMeta, VaultField, VaultFieldType } from '@ohos/common'
import { FileUtil, ResUtil } from '@pura/harmony-utils'
import {
  definitionFor,
  isTemplateFieldKey,
  ItemTemplateDefinition,
  TemplateFieldDefinition,
} from '../../model/EntryTemplateCatalog'
import { parseSshKeys, SSH_KEYS_FIELD, SshKeyDraft } from '../../model/SshKeyPayload'
import { EntrySshKeyList } from './EntrySshKeyList'

const PREVIEW_MENU_MAX_COUNT: number = 4
const PASSWORD_MASK: string = '••••••••'
// 与详情页既有显示时长一致；B04 统一切换到 PASSWORD_REVEAL_SECONDS 时改这一处。
const PREVIEW_REVEAL_SECONDS: number = 30

@ComponentV2
struct Cell {
  @Require @Param icon: Resource
  @Require @Param label: ResourceStr
  @Param value: string = ''
  @Param valueExpanded: boolean = false
  @Param clickable: boolean = true
  @Param showTrailingButton: boolean = false
  @Param trailingSymbol: Resource = $r('sys.symbol.chevron_down')
  @Param showExpandedContent: boolean = false
  @Param expandedContent: string = ''
  @Event onTrailingClick: () => void = () => {
  }
  @Event onCellClick: () => void = () => {
  }
  @BuilderParam trailingBuilder?: () => void
  @BuilderParam extraBuilder?: () => void

  build() {
    ListItem() {
      Column() {
        Row({ space: $r('sys.float.padding_level4') }) {
          SymbolGlyph(this.icon)
            .width($r('sys.float.ohos_id_min_circle_button_icon_size'))
            .fontSize($r('sys.float.ohos_id_textfield_icon_size'))
            .fontColor([$r('sys.color.brand')])

          Column({ space: $r('sys.float.padding_level4') }) {
            Text(this.label)
              .fontSize($r('sys.float.Body_M'))
              .fontColor($r('sys.color.font_secondary'))
            if (this.valueExpanded) {
              Text(this.value.length > 0 ? this.value : ' ')
                .fontSize($r('sys.float.Body_L'))
                .fontColor($r('sys.color.font_primary'))
                .fontWeight(FontWeight.Medium)
                .wordBreak(WordBreak.BREAK_ALL)
            } else {
              Text(this.value.length > 0 ? this.value : ' ')
                .fontSize($r('sys.float.Body_L'))
                .fontColor($r('sys.color.font_primary'))
                .fontWeight(FontWeight.Medium)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .wordBreak(WordBreak.BREAK_ALL)
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          if (this.trailingBuilder !== undefined) {
            Row({ space: $r('sys.float.padding_level4') }) {
              this.trailingBuilder()
            }
            .alignSelf(ItemAlign.Center)
          }
          if (this.showTrailingButton) {
            IconToggleButton({
              symbol: this.trailingSymbol,
              accessibilityLabel: $r('app.string.notes'),
              exclusive: true,
              onToggle: () => this.onTrailingClick(),
            })
          }
        }
        .alignItems(VerticalAlign.Top)

        if (this.extraBuilder !== undefined) {
          this.extraBuilder()
        }
      }

    }
    .padding($r('sys.float.padding_level6'))
    .margin($r('sys.float.padding_level2'))
    .stateStyles({
      normal: {
        .backgroundColor(Color.Transparent)
      },
      pressed: {
        .backgroundColor(this.clickable ? $r('sys.color.interactive_pressed') : Color.Transparent)
      },
    })
    .borderRadius($r('sys.float.corner_radius_level8'))
    .onClick(() => {
      if (!this.clickable) {
        return
      }
      this.onCellClick()
    })
  }
}

@ComponentV2
export struct EntryPreviewView {
  @Param sheet: EntrySheetViewModel = entrySheetViewModel
  @Param topOffset: number = 0
  @Param bottomOffset: number = 0
  @Event onClose: () => void = () => {
  }
  @Event onEdit: () => void = () => {
  }
  @Local private session: AppSessionState = appSessionState
  // 明文可见性是敏感状态，只在预览体存活期间有效，绝不外提；受保护字段共用一套倒计时。
  @Local private revealedKeys: Set<string> = new Set<string>()
  @Local private revealSeconds: number = 0
  private revealTimer: number = -1
  private readonly viewModel: AppViewModel = appViewModel
  private readonly favoriteIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.star'))
      .fontColor([$r('sys.color.titlebar_icon_color')])
  private readonly favoritedIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.star_fill'))
      .fontColor([$r('app.color.favorite')])
  private readonly editIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.square_and_pencil'))
      .fontColor([$r('sys.color.titlebar_icon_color')])
  private readonly deleteIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.trash'))
      .fontColor([$r('sys.color.warning')])
  private readonly closeIcon: SymbolGlyphModifier =
    new SymbolGlyphModifier($r('sys.symbol.xmark'))
      .fontColor([$r('sys.color.titlebar_icon_color')])

  private needsExpansion(value: string): boolean {
    return value.includes('\n') || value.length > 48
  }

  private customFieldIcon(type: VaultFieldType): Resource {
    switch (type) {
      case VaultFieldType.Url:
        return $r('sys.symbol.link')
      case VaultFieldType.Email:
        return $r('sys.symbol.envelope')
      case VaultFieldType.Phone:
        return $r('sys.symbol.phone')
      case VaultFieldType.Address:
        return $r('sys.symbol.map')
      case VaultFieldType.Date:
        return $r('sys.symbol.calendar')
      case VaultFieldType.Password:
        return $r('sys.symbol.key')
      case VaultFieldType.Text:
        return $r('sys.symbol.textformat')
      default:
        return $r('sys.symbol.circle_grid_2x2')
    }
  }

  @Computed
  private get notes(): string {
    return this.fieldValue('Notes')
  }

  @Computed
  private get definition(): ItemTemplateDefinition {
    return definitionFor(this.sheet.template)
  }

  // 「其他」区：既不是 KDBX 保留字段，也不属于当前模板定义。
  @Computed
  private get customFields(): VaultField[] {
    return this.sheet.fields.filter((field: VaultField) =>
    !RESERVED_FIELD_NAMES.includes(field.name) && !isTemplateFieldKey(this.sheet.template, field.name))
  }

  // 附件只展示名字与体积；增删与导出在编辑页完成。
  @Computed
  private get attachments(): VaultAttachmentMeta[] {
    return this.sheet.previewEntry?.attachments ?? []
  }

  // SSH 密钥行由卡片列表渲染，不进字段行。
  @Computed
  private get previewFields(): TemplateFieldDefinition[] {
    return this.definition.fields.filter((field: TemplateFieldDefinition) =>
    !field.attachments && !field.sshKeys)
  }

  @Computed
  private get sshKeys(): SshKeyDraft[] {
    return parseSshKeys(this.fieldValue(SSH_KEYS_FIELD))
  }

  aboutToDisappear(): void {
    this.hideRevealed()
  }

  @Monitor('session.sensitiveEpoch')
  onSensitiveStateChanged(): void {
    this.hideRevealed()
  }

  private fieldValue(name: string): string {
    return this.sheet.fields.find((field: VaultField) => field.name === name)?.value ?? ''
  }

  private templateValue(definition: TemplateFieldDefinition): string {
    return this.fieldValue(definition.reservedField.length > 0 ? definition.reservedField : definition.key)
  }

  private clearRevealTimer(): void {
    if (this.revealTimer >= 0) {
      clearInterval(this.revealTimer)
      this.revealTimer = -1
    }
  }

  private hideRevealed(): void {
    this.clearRevealTimer()
    this.revealedKeys = new Set<string>()
    this.revealSeconds = 0
  }

  // Set 原地增删不触发 @Trace 通知，整体替换。
  private startRevealTimeout(key: string): void {
    this.clearRevealTimer()
    const next: Set<string> = new Set(this.revealedKeys)
    next.add(key)
    this.revealedKeys = next
    this.revealSeconds = PREVIEW_REVEAL_SECONDS
    this.revealTimer = setInterval(() => {
      this.revealSeconds--
      if (this.revealSeconds <= 0) {
        this.hideRevealed()
      }
    }, 1000)
  }

  private toggleReveal(key: string): void {
    if (this.revealedKeys.has(key)) {
      this.hideRevealed()
      return
    }
    this.startRevealTimeout(key)
  }

  private safeValue(value: string): string {
    return value.length > 0 ? PASSWORD_MASK : ''
  }

  private copy(value: string): void {
    this.viewModel.copyValue(value).then((copied: boolean) => {
      if (copied) {
        AppToast.showAboveSheets(this.getUIContext(), $r('app.string.copy_completed'))
      }
    })
  }

  // 复制受保护字段等同一次查看：显示掩码并开始倒计时。
  private copyProtected(key: string, value: string): void {
    if (value.length === 0) {
      return
    }
    this.viewModel.copyValue(value).then((copied: boolean) => {
      if (copied) {
        this.startRevealTimeout(key)
        AppToast.showAboveSheets(this.getUIContext(), $r('app.string.copy_completed'))
      }
    })
  }

  private openUrl(): void {
    this.viewModel.openFieldAction(this.fieldValue('URL'), VaultFieldType.Url)
  }

  private countdownText(): string {
    const time: string = `00:${this.revealSeconds < 10 ? '0' : ''}${this.revealSeconds}`
    return ResUtil.getStringSync($r('app.string.password_hide_countdown')).replace('%s', time)
  }

  private confirmDelete(): void {
    const options: AlertDialogParamWithButtons = {
      title: $r('app.string.delete_entry_title'),
      message: $r('app.string.delete_entry_message'),
      primaryButton: {
        value: $r('app.string.cancel'), action: () => {
        },
      },
      secondaryButton: {
        value: $r('app.string.delete_entry'),
        fontColor: $r('sys.color.warning'),
        action: () => this.viewModel.deleteEntry(this.sheet.entryUuid).then((deleted: boolean) => {
          if (deleted) {
            this.onClose()
          }
        }),
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  private menuItem(icon: SymbolGlyphModifier, label: Resource, action: () => void,
    enabled: boolean = true): HdsNavigationMenuItemOptions {
    const content: HdsNavigationIconOptions = {
      icon: icon,
      type: IconStyleMode.SMALL,
      label: label,
      isEnabled: enabled,
      action: action,
    }
    return { content: content }
  }

  private previewMenuItems(): HdsNavigationMenuItemOptions[] {
    if (this.sheet.readOnly) {
      return [this.menuItem(this.closeIcon, $r('app.string.close'), () => this.onClose())]
    }
    return [
      this.menuItem(this.sheet.favorite ? this.favoritedIcon : this.favoriteIcon,
        this.sheet.favorite ? $r('app.string.remove_favorite') : $r('app.string.add_favorite'),
        () => this.sheet.toggleFavorite(), !this.viewModel.busy),
      this.menuItem(this.editIcon, $r('app.string.edit'), () => this.onEdit(), !this.viewModel.busy),
      this.menuItem(this.deleteIcon, $r('app.string.delete_entry'), () => this.confirmDelete(),
        !this.viewModel.busy),
      this.menuItem(this.closeIcon, $r('app.string.close'), () => this.onClose()),
    ]
  }

  @LocalBuilder
  private revealTrailing(definition: TemplateFieldDefinition) {
    PasswordVisibilityToggle({
      visible: this.revealedKeys.has(definition.key),
      exclusive: true,
      onChange: () => this.toggleReveal(definition.key),
    })
  }

  @LocalBuilder
  private revealCountdown(definition: TemplateFieldDefinition) {
    if (this.revealedKeys.has(definition.key) && this.revealSeconds > 0) {
      Text(this.countdownText())
        .width('100%')
        .fontSize($r('sys.float.Caption_S'))
        .fontColor($r('sys.color.font_tertiary'))
        .padding({ left: $r('sys.float.padding_level16'), bottom: $r('sys.float.padding_level8') })
    }
  }

  @Builder
  private templateCell(definition: TemplateFieldDefinition) {
    if (definition.reservedField === 'Notes') {
      Cell({
        icon: definition.icon,
        label: definition.label,
        value: this.sheet.notesExpanded ? this.notes : this.notes.split('\n')[0],
        valueExpanded: this.sheet.notesExpanded,
        clickable: this.notes.length > 0,
        onCellClick: () => this.copy(this.notes),
        trailingBuilder: this.notesTrailing,
      })
    } else if (definition.protected) {
      Cell({
        icon: definition.icon,
        label: definition.label,
        value: this.revealedKeys.has(definition.key)
          ? this.templateValue(definition) : this.safeValue(this.templateValue(definition)),
        clickable: this.templateValue(definition).length > 0,
        onCellClick: () => this.copyProtected(definition.key, this.templateValue(definition)),
        trailingBuilder: () => {
          this.revealTrailing(definition)
        },
        extraBuilder: () => {
          this.revealCountdown(definition)
        },
      })
    } else if (definition.reservedField === 'URL') {
      Cell({
        icon: definition.icon,
        label: definition.label,
        value: this.templateValue(definition),
        clickable: this.templateValue(definition).length > 0,
        onCellClick: () => this.copy(this.templateValue(definition)),
        trailingBuilder: this.urlTrailing,
      })
    } else {
      Cell({
        icon: definition.icon,
        label: definition.label,
        value: this.sheet.expandedCustomFields.has(definition.key)
          ? this.templateValue(definition) : this.templateValue(definition).split('\n')[0],
        valueExpanded: this.sheet.expandedCustomFields.has(definition.key),
        clickable: this.templateValue(definition).length > 0,
        onCellClick: () => this.copy(this.templateValue(definition)),
        showTrailingButton: this.needsExpansion(this.templateValue(definition)),
        trailingSymbol: this.sheet.expandedCustomFields.has(definition.key)
          ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'),
        onTrailingClick: () => this.sheet.toggleCustomExpanded(definition.key),
      })
    }
  }

  @LocalBuilder
  private urlTrailing() {
    if (this.fieldValue('URL').length > 0) {
      IconToggleButton({
        symbol: $r('sys.symbol.arrow_up_right'),
        accessibilityLabel: $r('app.string.open_link'),
        exclusive: true,
        onToggle: () => this.openUrl(),
      })
    }
  }

  @LocalBuilder
  private notesTrailing() {
    if (this.needsExpansion(this.notes)) {
      IconToggleButton({
        symbol: this.sheet.notesExpanded ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'),
        accessibilityLabel: $r('app.string.notes'),
        exclusive: true,
        onToggle: () => this.sheet.toggleNotesExpanded(),
      })
    }
  }

  @Builder
  private previewMenu() {
    HdsNavigation() {
      Scroll() {
        Column({ space: $r('sys.float.padding_level16') }) {
          Row({ space: $r('sys.float.padding_level8') }) {
            EntryAvatar(
              {
                title: this.sheet.title,
                avatarData: this.sheet.avatarData,
                avatarSize: $r('app.float.entry_avatar_size'),
                initialsFontSize: $r('sys.float.Display_S'),
              })
            Column({ space: $r('sys.float.padding_level4') }) {
              Text(this.sheet.title)
                .width('100%')
                .fontSize($r('sys.float.Title_M'))
                .fontWeight(FontWeight.Bold)
                .fontColor($r('sys.color.font_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .ellipsisMode(EllipsisMode.CENTER)
              Row({ space: $r('sys.float.padding_level4') }) {
                SymbolGlyph($r('sys.symbol.folder')).fontSize($r('sys.float.Body_M'))
                  .fontColor([$r('sys.color.font_secondary')])
                Text(this.sheet.groupPath).fontSize($r('sys.float.Body_M'))
                  .fontColor($r('sys.color.font_secondary'))
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .ellipsisMode(EllipsisMode.CENTER)
                  .layoutWeight(1)
              }
              .width('100%')
            }
            .layoutWeight(1).alignItems(HorizontalAlign.Start)
          }
          .margin({ left: $r('sys.float.padding_level8') })

          Column({ space: $r('sys.float.padding_level8') }) {
            List() {
              ForEach(this.previewFields, (definition: TemplateFieldDefinition) => {
                this.templateCell(definition)
              }, (definition: TemplateFieldDefinition) => definition.key)
            }
            .backgroundColor($r('sys.color.comp_background_primary'))
            .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
            .borderRadius($r('sys.float.corner_radius_level10'))
            .divider({
              strokeWidth: 1,
              color: $r('sys.color.grid_menu_divider_color'),
              startMargin: $r('sys.float.padding_level8'),
              endMargin: $r('sys.float.padding_level8'),
            })

            if (this.sshKeys.length > 0) {
              EntrySshKeyList({
                keys: this.sshKeys,
                onActivity: () => this.viewModel.recordActivity(),
              })
            }

            if (this.attachments.length > 0) {
              List() {
                ForEach(this.attachments, (attachment: VaultAttachmentMeta) => {
                  Cell({
                    icon: $r('sys.symbol.paperclip'),
                    label: $r('app.string.attachment_file'),
                    value: `${attachment.name} · ${FileUtil.getFormatFileSize(attachment.size)}`,
                    clickable: false,
                  })
                }, (attachment: VaultAttachmentMeta) => attachment.name)
              }
              .width('100%')
              .backgroundColor($r('sys.color.comp_background_primary'))
              .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
              .borderRadius($r('sys.float.corner_radius_level10'))
              .divider({
                strokeWidth: 1,
                color: $r('sys.color.grid_menu_divider_color'),
                startMargin: $r('sys.float.padding_level8'),
                endMargin: $r('sys.float.padding_level8'),
              })
              .scrollBar(BarState.Off)
            }

            Row() {
              Row({ space: $r('sys.float.padding_level4') }) {
                SymbolGlyph($r('sys.symbol.label'))
                  .width($r('sys.float.ohos_id_min_circle_button_icon_size'))
                  .fontSize($r('sys.float.ohos_id_textfield_icon_size'))
                  .fontColor([$r('sys.color.brand')])
                Flex({
                  wrap: FlexWrap.Wrap, space: {
                    main: LengthMetrics.resource($r('sys.float.padding_level8')),
                    cross: LengthMetrics.resource($r('sys.float.padding_level8')),
                  },
                }) {
                  ForEach(this.sheet.tags, (tag: string) => {
                    ChipV2({
                      chipV2Options: new ChipV2Options({
                        label: new ChipV2Label({ text: tag }),
                        allowClose: false,
                      }),
                    })
                  }, (tag: string) => tag)
                }
                .layoutWeight(1)
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
              .padding($r('sys.float.padding_level8'))
            }
            .width('100%')
            .backgroundColor($r('sys.color.comp_background_primary'))
            .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
            .borderRadius($r('sys.float.corner_radius_level10'))

            if (this.customFields.length > 0) {
              List() {
                ForEach(this.customFields, (field: VaultField) => {
                  Cell({
                    icon: this.customFieldIcon(field.type),
                    label: field.name,
                    value: this.sheet.expandedCustomFields.has(field.name)
                      ? (field.value.length > 0 &&
                        (field.protected || field.type === VaultFieldType.Password) ? PASSWORD_MASK : field.value)
                      : (field.value.length > 0 &&
                        (field.protected || field.type === VaultFieldType.Password) ? PASSWORD_MASK :
                        field.value).split('\n')[0],
                    valueExpanded: this.sheet.expandedCustomFields.has(field.name),
                    clickable: field.value.length > 0,
                    onCellClick: () => this.copy(field.value),
                    showTrailingButton: this.needsExpansion(field.value),
                    trailingSymbol: this.sheet.expandedCustomFields.has(field.name)
                      ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'),
                    onTrailingClick: () => this.sheet.toggleCustomExpanded(field.name),
                  })
                }, (field: VaultField) => field.name)
              }
              .width('100%')
              .backgroundColor($r('sys.color.comp_background_primary'))
              .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
              .borderRadius($r('sys.float.corner_radius_level10'))
              .divider({
                strokeWidth: 1,
                color: $r('sys.color.grid_menu_divider_color'),
                startMargin: $r('sys.float.padding_level8'),
                endMargin: $r('sys.float.padding_level8'),
              })
              .scrollBar(BarState.Off)
            }
          }
          .margin({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

        }
        .justifyContent(FlexAlign.Start)
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .padding({ top: this.topOffset, bottom: this.bottomOffset })
        .onTouch(() => this.viewModel.recordActivity())
      }
      .width('100%')
      .height('100%')
      .id('entry_preview_scroll')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      style: {
        scrollEffectOpts: { enableScrollEffect: false, scrollEffectType: ScrollEffectType.GRADIENT_BLUR },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      content: { title: { mainTitle: '' }, menu: { maxCount: PREVIEW_MENU_MAX_COUNT, value: this.previewMenuItems() } },
    })
  }

  build() {
    this.previewMenu()
  }
}
