import { ItemTemplate, PasswordStrengthCalculator, VaultEntry, VaultField } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { stageOneVaultStore } from '../model/StageOneVaultStore'
import { parseSshKeys, SSH_KEYS_FIELD } from '../model/SshKeyPayload'
import {
  ENTRY_FIELD_CARD_NUMBER,
  ENTRY_FIELD_CARD_TYPE,
  ENTRY_FIELD_NOTES,
  ENTRY_FIELD_PASSWORD,
  ENTRY_FIELD_USERNAME,
  strengthLabel,
} from './EntryPresentation'

// 列表行展示模型：标题、副标题、图标和收藏状态都在 ViewModel 层算好，行组件只负责画。
@ObservedV2
export class EntryRowModel {
  readonly uuid: string
  @Trace groupUuid: string = ''
  @Trace title: string = ''
  @Trace subtitle: ResourceStr = ''
  @Trace templateIcon: Resource = $r('app.string.symbol_person')
  @Trace archived: boolean = false
  @Trace favorite: boolean = false
  @Trace hasAvatar: boolean = false
  @Trace avatarData: ArrayBuffer | undefined = undefined
  private fields: VaultField[] = []

  constructor(entry: VaultEntry, appendGroupName: boolean = false) {
    this.uuid = entry.uuid
    this.update(entry, appendGroupName)
  }

  update(entry: VaultEntry, appendGroupName: boolean = false): void {
    this.fields = entry.fields
    this.groupUuid = entry.groupUuid
    this.title = entry.title
    this.subtitle = this.buildSubtitle(entry, appendGroupName)
    this.templateIcon = this.buildTemplateIcon(entry.template)
    this.archived = entry.archived
    this.favorite = entry.favorite
    this.hasAvatar = entry.hasAvatar
    if (!entry.hasAvatar) {
      this.avatarData = undefined
    }
  }

  setFavorite(favorite: boolean): void {
    this.favorite = favorite
  }

  fieldValue(name: string): string {
    return this.fields.find((field: VaultField) => field.name === name)?.value ?? ''
  }

  // 头像字节按行可见时再读，避免长列表一次解全部图片。
  ensureAvatar(): void {
    if (!this.hasAvatar || this.avatarData !== undefined || stageOneVaultStore.locked) {
      return
    }
    this.avatarData = stageOneVaultStore.loadEntryAvatar(this.uuid)
  }

  private buildSubtitle(entry: VaultEntry, appendGroupName: boolean): ResourceStr {
    let subtitle: ResourceStr = ''
    switch (entry.template) {
      case ItemTemplate.SecureNote:
        subtitle = this.fieldValue(ENTRY_FIELD_NOTES)
        break
      case ItemTemplate.CreditCard:
        subtitle = this.cardSubtitle()
        break
      case ItemTemplate.SshKey: {
        const count: number = parseSshKeys(this.fieldValue(SSH_KEYS_FIELD)).length
        subtitle = count === 0 ? '' : this.format($r('app.string.entry_card_ssh_key_count').id, String(count))
        break
      }
      case ItemTemplate.Attachment: {
        const count: number = entry.attachments.length
        subtitle = count === 0 ? '' : this.format($r('app.string.entry_card_attachment_count').id, String(count))
        break
      }
      case ItemTemplate.Password:
        subtitle = this.passwordSubtitle()
        break
      default:
        subtitle = this.fieldValue(ENTRY_FIELD_USERNAME)
    }
    if (!appendGroupName || entry.groupName.length === 0) {
      return subtitle
    }
    const text: string = typeof subtitle === 'string' ? subtitle : ResUtil.getStringSync(subtitle)
    return text.length === 0 ? entry.groupName : `${text} · ${entry.groupName}`
  }

  private buildTemplateIcon(template: ItemTemplate | undefined): Resource {
    switch (template) {
      case ItemTemplate.SecureNote:
        return $r('app.string.symbol_notes')
      case ItemTemplate.CreditCard:
        return $r('app.string.symbol_credit_card')
      case ItemTemplate.SshKey:
        return $r('app.string.symbol_key')
      case ItemTemplate.Attachment:
        return $r('app.string.symbol_attach_file')
      case ItemTemplate.Password:
        return $r('app.string.symbol_key')
      default:
        return $r('app.string.symbol_person')
    }
  }

  private passwordSubtitle(): string {
    const password: string = this.fieldValue(ENTRY_FIELD_PASSWORD)
    if (password.length === 0) {
      return ''
    }
    const label: ResourceStr = strengthLabel(PasswordStrengthCalculator.calculate(password))
    const strength: string = typeof label === 'string' ? label : ResUtil.getStringSync(label)
    return `${strength} ${this.format($r('app.string.entry_card_password_length').id, String(password.length))}`
  }

  private cardSubtitle(): ResourceStr {
    const cardType: string = this.fieldValue(ENTRY_FIELD_CARD_TYPE)
    if (cardType.length > 0) {
      return cardType
    }
    const digits: string = this.fieldValue(ENTRY_FIELD_CARD_NUMBER).replace(/\s+/g, '')
    return digits.length === 0 ? '' : this.format($r('app.string.entry_card_card_last_four').id, digits.slice(-4))
  }

  private format(resId: number, value: string): string {
    return ResUtil.getStringSync(resId, [value])
  }
}

@ObservedV2
export class EntryGroupHeaderModel {
  readonly groupUuid: string
  @Trace groupName: string = ''
  @Trace count: number = 0

  constructor(groupUuid: string) {
    this.groupUuid = groupUuid
  }

  update(groupName: string, count: number): void {
    this.groupName = groupName
    this.count = count
  }
}

export enum EntryListItemKind {
  Header = 'header',
  Row = 'row',
}

@ObservedV2
export class EntryListItem {
  readonly key: string
  readonly kind: EntryListItemKind
  readonly header: EntryGroupHeaderModel | undefined
  readonly row: EntryRowModel | undefined

  constructor(key: string, kind: EntryListItemKind, header?: EntryGroupHeaderModel, row?: EntryRowModel) {
    this.key = key
    this.kind = kind
    this.header = header
    this.row = row
  }
}
