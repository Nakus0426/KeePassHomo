import { ItemTemplate, RESERVED_FIELD_NAMES, VaultAttachmentMeta, VaultEntry, VaultField, VaultFieldType } from '@ohos/common'
import { DateUtil } from '@pura/harmony-utils'
import { definitionFor, ItemTemplateDefinition, TemplateFieldDefinition, TemplateFieldOption } from '../model/EntryTemplateCatalog'
import { fieldTypeDefinition } from '../model/FieldTypeCatalog'
import { parseSshKeys, SSH_KEYS_FIELD, SshKeyDraft } from '../model/SshKeyPayload'
import { stageOneVaultStore } from '../model/StageOneVaultStore'
import { AppViewModel, appViewModel } from './AppViewModel'
import { ENTRY_FIELD_CARD_NUMBER, ENTRY_FIELD_CARD_TYPE } from './EntryPresentation'

const CARD_ISSUER_KEY: string = 'Issuer'
const CARD_HOLDER_KEY: string = 'CardHolderName'
const CARD_EXPIRY_KEY: string = 'Expiry'
const CARD_DIGIT_GROUP: number = 4

export interface EntryPreviewField {
  key: string
  label: ResourceStr
  value: string
  type: VaultFieldType
  protectedValue: boolean
  icon?: Resource
  iconImage?: Resource
}

// 半模态形态：预览态只看与取值，编辑态改草稿。
export enum EntrySheetMode {
  Preview = 'preview',
  Edit = 'edit'
}

// 半模态的唯一状态源：列表只发动作，预览体与编辑体只做展示与交互。
// 三个字段各自独立：切换形态不动开合状态，切换条目不动形态。
@ObservedV2
export class EntrySheetViewModel {
  @Trace visible: boolean = false
  @Trace mode: EntrySheetMode = EntrySheetMode.Preview
  // 目标条目 uuid；空串表示新建，没有预览态。
  @Trace entryUuid: string = ''
  // 新建时选定的模板类型：编辑会话内固定，不随条目内容变化。
  @Trace newEntryTemplate: ItemTemplate = ItemTemplate.Login
  // 新建时预置的分组；空串表示默认分组。
  @Trace newEntryGroupUuid: string = ''
  // 编辑态退出后是否返回预览：左滑编辑与新建直接收起半模态。
  @Trace editFromPreview: boolean = false
  // 在同一次面板会话内从编辑返回预览时，恢复已展开的字段。
  @Trace expandedFields: Set<string> = new Set<string>()
  @Trace previewEntry: VaultEntry | undefined = undefined
  @Trace avatarData: ArrayBuffer | undefined = undefined
  private readonly app: AppViewModel = appViewModel

  @Computed
  get isNewEntry(): boolean {
    return this.entryUuid.length === 0
  }

  @Computed
  get title(): string {
    return this.previewEntry?.title ?? ''
  }

  @Computed
  get groupPath(): string {
    return this.previewEntry?.groupPath ?? ''
  }

  @Computed
  private get fieldsByName(): Map<string, VaultField> {
    const byName: Map<string, VaultField> = new Map<string, VaultField>()
    for (const field of this.previewEntry?.fields ?? []) {
      if (!byName.has(field.name)) {
        byName.set(field.name, field)
      }
    }
    return byName
  }

  // 预览按条目类型渲染；未标记类型按通用模板。
  @Computed
  private get templateDefinition(): ItemTemplateDefinition {
    return definitionFor(this.previewEntry?.template)
  }

  @Computed
  get templateLabel(): Resource {
    return this.templateDefinition.template === ItemTemplate.Login
      ? $r('app.string.entry_menu_template_login') : this.templateDefinition.name
  }

  @Computed
  get showBankCard(): boolean {
    return this.templateDefinition.template === ItemTemplate.CreditCard
  }

  @Computed
  get previewFields(): EntryPreviewField[] {
    const fields: EntryPreviewField[] = []
    const templateKeys: Set<string> = new Set<string>()
    for (const definition of this.templateDefinition.fields) {
      const key: string = definition.key
      if (definition.reservedField.length === 0) {
        templateKeys.add(key)
      }
      if (definition.attachments || definition.sshKeys ||
        (this.showBankCard && (key === CARD_ISSUER_KEY || key === CARD_HOLDER_KEY || key === CARD_EXPIRY_KEY))) {
        continue
      }
      const stored: VaultField | undefined = this.fieldsByName.get(key)
      const issuer: VaultField | undefined = key === ENTRY_FIELD_CARD_TYPE
        ? this.fieldsByName.get(CARD_ISSUER_KEY) : undefined
      const value: string = stored?.value ?? ''
      const issuerValue: string = issuer?.value ?? ''
      fields.push({
        key,
        type: key === 'URL' ? VaultFieldType.Url : definition.type,
        value: value.length > 0 && issuerValue.length > 0 ? value + ' · ' + issuerValue : value || issuerValue,
        protectedValue: definition.protected || stored?.protected === true || issuer?.protected === true,
        label: definition.label,
        icon: definition.icon,
      })
    }
    for (const field of this.previewEntry?.fields ?? []) {
      if (RESERVED_FIELD_NAMES.includes(field.name) || templateKeys.has(field.name)) {
        continue
      }
      fields.push({
        key: field.name,
        label: field.name,
        value: field.value,
        type: field.type,
        protectedValue: field.protected || field.type === VaultFieldType.Password,
        iconImage: fieldTypeDefinition(field.type).icon,
      })
    }
    return fields
  }

  @Computed
  get attachments(): VaultAttachmentMeta[] {
    return this.previewEntry?.attachments ?? []
  }

  @Computed
  get sshKeys(): SshKeyDraft[] {
    return parseSshKeys(this.fieldsByName.get(SSH_KEYS_FIELD)?.value ?? '')
  }

  @Computed
  get lastModified(): string {
    const time: number = this.previewEntry?.lastModifiedAt ?? 0
    return time > 0 ? DateUtil.getFormatDateStr(time, 'yyyy-MM-dd HH:mm') : ''
  }

  @Computed
  private get cardNumber(): string {
    return (this.fieldsByName.get(ENTRY_FIELD_CARD_NUMBER)?.value ?? '').replace(/\s+/g, '')
  }

  @Computed
  get cardNumberDigits(): string {
    const groups: string[] = []
    for (let index: number = 0; index < this.cardNumber.length; index += CARD_DIGIT_GROUP) {
      groups.push(this.cardNumber.substring(index, index + CARD_DIGIT_GROUP))
    }
    return groups.join(' ')
  }

  @Computed
  get cardNumberMask(): string {
    return /^[0-9]{5,}$/.test(this.cardNumber) ? '**** **** **** ' + this.cardNumber.slice(-4) : '**** **** **** ****'
  }

  @Computed
  get cardLogo(): Resource | undefined {
    const cardType: string = this.fieldsByName.get(ENTRY_FIELD_CARD_TYPE)?.value ?? ''
    if (cardType.length === 0) {
      return undefined
    }
    // 卡面固定浅色，使用彩色词标。自定义类型没有词标。
    const field: TemplateFieldDefinition | undefined = this.templateDefinition.fields.find(
      (definition: TemplateFieldDefinition): boolean => definition.key === ENTRY_FIELD_CARD_TYPE)
    return field?.options.find((option: TemplateFieldOption): boolean => option.value === cardType)?.cardIcon
  }

  @Computed
  get cardHolder(): VaultField | undefined {
    return this.fieldsByName.get(CARD_HOLDER_KEY)
  }

  @Computed
  get cardExpiry(): VaultField | undefined {
    return this.fieldsByName.get(CARD_EXPIRY_KEY)
  }

  @Computed
  get tags(): string[] {
    return this.previewEntry?.tags ?? []
  }

  @Computed
  get favorite(): boolean {
    return this.previewEntry?.favorite ?? false
  }

  // 只读能力属于 AppViewModel，缓存进来会读到旧值。
  get readOnly(): boolean {
    return this.app.currentSource().readOnly
  }

  openNew(template: ItemTemplate, groupUuid: string = ''): void {
    this.entryUuid = ''
    this.newEntryTemplate = template
    this.newEntryGroupUuid = groupUuid
    this.editFromPreview = false
    this.mode = EntrySheetMode.Edit
    this.visible = true
  }

  openPreview(entryUuid: string): void {
    this.entryUuid = entryUuid
    this.editFromPreview = false
    this.mode = EntrySheetMode.Preview
    this.visible = true
    stageOneVaultStore.touch()
  }

  openEdit(entryUuid: string): void {
    this.entryUuid = entryUuid
    this.editFromPreview = false
    this.mode = EntrySheetMode.Edit
    this.visible = true
    stageOneVaultStore.touch()
  }

  // 预览态进入编辑：退出后回预览，而不是收起半模态。
  beginEdit(): void {
    this.editFromPreview = true
    this.mode = EntrySheetMode.Edit
  }

  close(): void {
    this.visible = false
  }

  exitEditor(): void {
    if (this.isNewEntry || !this.editFromPreview) {
      this.visible = false
      return
    }
    this.mode = EntrySheetMode.Preview
  }

  // 收起后复位形态并重建首页快照：列表变更要放在动画上下文里才可见。
  onDismissed(): void {
    this.visible = false
    this.mode = EntrySheetMode.Preview
    this.editFromPreview = false
    this.expandedFields = new Set<string>()
    this.app.refreshHomeSnapshot()
  }

  // 唯一装载入口：不可见或新建时清空，避免残留上一条的内容。
  load(): void {
    if (!this.visible || this.entryUuid.length === 0) {
      this.previewEntry = undefined
      this.avatarData = undefined
      return
    }
    this.previewEntry = this.app.entry(this.entryUuid)
    this.avatarData = this.app.loadEntryAvatar(this.entryUuid)
  }

  // 整体替换：Set 原地增删不会触发 @Trace 的赋值通知。
  toggleFieldExpanded(name: string): void {
    const next: Set<string> = new Set<string>(this.expandedFields)
    if (next.has(name)) {
      next.delete(name)
    } else {
      next.add(name)
    }
    this.expandedFields = next
  }

  toggleFavorite(): Promise<void> {
    return this.app.toggleFavorite(this.entryUuid)
  }
}

export const entrySheetViewModel: EntrySheetViewModel = new EntrySheetViewModel()
