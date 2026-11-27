import { ItemTemplate, PasswordStrengthCalculator, VaultEntry, VaultField } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { definitionFor } from '../model/EntryTemplateCatalog'
import { stageOneVaultStore } from '../model/StageOneVaultStore'
import { parseSshKeys, SSH_KEYS_FIELD } from '../model/SshKeyPayload'
import {
  ENTRY_FIELD_CARD_NUMBER,
  ENTRY_FIELD_CARD_TYPE,
  ENTRY_FIELD_NOTES,
  ENTRY_FIELD_PASSWORD,
  ENTRY_FIELD_USERNAME,
  formatEntryTime,
  strengthLabel,
} from './EntryPresentation'

// 列表行展示模型：标题、副标题和收藏状态都在 ViewModel 层算好，行组件只负责画。
@ObservedV2
export class EntryRowModel {
  readonly uuid: string
  @Trace groupUuid: string = ''
  @Trace title: string = ''
  @Trace subtitle: ResourceStr = ''
  @Trace archived: boolean = false
  @Trace favorite: boolean = false
  @Trace hasAvatar: boolean = false
  @Trace avatarData: ArrayBuffer | undefined = undefined
  @Trace menuGroupName: string = ''
  // 离场收缩中：刷新前先把高度与透明度归零，避免条目瞬间消失、下方条目跳位。
  @Trace leaving: boolean = false
  // 行内容对应的数据版本：与当前版本一致即可跳过重算，筛选切换时复用整张行模型。
  revision: number = -1
  // 内容每次重写递增：行挂载后据此惰性重算副标题，未上屏的行不做密码强度与资源查表。
  @Trace contentVersion: number = 0
  private entry: VaultEntry | undefined = undefined
  private appendGroupName: boolean = false
  private matchTag: string = ''
  private subtitleDirty: boolean = false
  private fields: VaultField[] = []
  // 长按菜单才需要的字段留到展开时再算，避免逐行构造时做资源查表与日期格式化。
  private template: ItemTemplate | undefined = undefined
  private lastModifiedAt: number = 0

  constructor(entry: VaultEntry, appendGroupName: boolean = false) {
    this.uuid = entry.uuid
    this.update(entry, appendGroupName)
  }

  update(entry: VaultEntry, appendGroupName: boolean = false): void {
    this.entry = entry
    this.appendGroupName = appendGroupName
    this.fields = entry.fields
    this.groupUuid = entry.groupUuid
    this.title = entry.title
    this.subtitleDirty = true
    this.archived = entry.archived
    this.favorite = entry.favorite
    this.hasAvatar = entry.hasAvatar
    this.menuGroupName = entry.groupName
    this.template = entry.template
    this.leaving = false
    if (!entry.hasAvatar) {
      this.avatarData = undefined
    } else if (this.avatarData !== undefined && this.lastModifiedAt !== entry.lastModifiedAt) {
      this.avatarData = stageOneVaultStore.loadEntryAvatar(this.uuid)
    }
    this.lastModifiedAt = entry.lastModifiedAt
    this.contentVersion++
  }

  // 由行组件在挂载与内容变化时调用：副标题要读字段、算密码强度并查资源，只在上屏后付这个代价。
  ensureSubtitle(): void {
    if (!this.subtitleDirty || this.entry === undefined) {
      return
    }
    this.subtitleDirty = false
    this.subtitle = this.buildSubtitle(this.entry, this.appendGroupName)
  }

  setFavorite(favorite: boolean): void {
    this.favorite = favorite
  }

  // 搜索按标签命中时，副标题追加命中的标签；离开搜索态传空串复位。
  setMatchTag(tag: string): void {
    if (this.matchTag === tag) {
      return
    }
    this.matchTag = tag
    this.subtitleDirty = true
    this.contentVersion++
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
    if (!appendGroupName && this.matchTag.length === 0) {
      return subtitle
    }
    const text: string = typeof subtitle === 'string' ? subtitle : ResUtil.getStringSync(subtitle)
    const parts: string[] = []
    if (text.length > 0) {
      parts.push(text)
    }
    if (appendGroupName && entry.groupName.length > 0) {
      parts.push(entry.groupName)
    }
    if (this.matchTag.length > 0) {
      parts.push(this.format($r('app.string.entry_search_tag_match').id, this.matchTag))
    }
    return parts.join(' · ')
  }

  menuTemplateLabel(): string {
    switch (this.template) {
      case ItemTemplate.Login:
        return ResUtil.getStringSync($r('app.string.entry_menu_template_login'))
      case ItemTemplate.Password:
        return ResUtil.getStringSync($r('app.string.entry_menu_template_password'))
      case ItemTemplate.SecureNote:
        return ResUtil.getStringSync($r('app.string.entry_menu_template_secure_note'))
      case ItemTemplate.CreditCard:
        return ResUtil.getStringSync($r('app.string.entry_menu_template_credit_card'))
      case ItemTemplate.SshKey:
        return ResUtil.getStringSync($r('app.string.entry_menu_template_ssh_key'))
      case ItemTemplate.Attachment:
        return ResUtil.getStringSync($r('app.string.entry_menu_template_attachment'))
      default:
        return ResUtil.getStringSync(definitionFor(this.template).name)
    }
  }

  menuSubtitle(): string {
    const password: string = this.passwordSubtitle()
    const modified: string = this.lastModifiedAt > 0
      ? ResUtil.getStringSync($r('app.string.entry_menu_last_modified'), [formatEntryTime(this.lastModifiedAt)])
      : ''
    return [password, modified].filter((part: string) => part.length > 0).join(' · ')
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
  @Trace leaving: boolean = false

  constructor(groupUuid: string) {
    this.groupUuid = groupUuid
  }

  update(groupName: string, count: number): void {
    // 筛选切换只改 count，其余字段同值时跳过，避免每次切换都触发段头重渲染。
    if (this.groupName !== groupName) {
      this.groupName = groupName
    }
    if (this.count !== count) {
      this.count = count
    }
    if (this.leaving) {
      this.leaving = false
    }
  }
}

// 搜索分区段头：只承载分区名与条数，没有分组 uuid，也不提供「在此新建」。
@ObservedV2
export class EntrySearchSectionModel {
  readonly key: string
  @Trace name: string = ''
  @Trace count: number = 0
  @Trace leaving: boolean = false

  constructor(key: string) {
    this.key = key
  }

  update(name: string, count: number): void {
    if (this.name !== name) {
      this.name = name
    }
    if (this.count !== count) {
      this.count = count
    }
    if (this.leaving) {
      this.leaving = false
    }
  }
}

export enum EntryListItemKind {
  Header = 'header',
  Section = 'section',
  Row = 'row',
}

@ObservedV2
export class EntryListItem {
  readonly key: string
  readonly kind: EntryListItemKind
  readonly header: EntryGroupHeaderModel | undefined
  readonly section: EntrySearchSectionModel | undefined
  readonly row: EntryRowModel | undefined

  constructor(key: string, kind: EntryListItemKind, header?: EntryGroupHeaderModel, row?: EntryRowModel,
    section?: EntrySearchSectionModel) {
    this.key = key
    this.kind = kind
    this.header = header
    this.row = row
    this.section = section
  }
}
