import {
  ItemTemplate,
  required,
  stringSchema,
  ValidationSchema,
  VaultAttachmentChange,
  VaultAttachmentMeta,
  VaultFieldInput,
  VaultFieldType,
  VaultGroup,
} from '@ohos/common'
import { FormItemController } from '../components/FormItem'
import { parseSshKeys, serializeSshKeys, SSH_KEYS_FIELD, SshKeyDraft } from '../model/SshKeyPayload'

let nextFieldId: number = 1
let nextAttachmentId: number = 1

export enum AttachmentEditAction {
  Keep = 'keep',
  Add = 'add',
  Remove = 'remove'
}

// 附件草稿：既有附件只带名字与体积，字节在导出时按需读取；新增附件带字节。
@ObservedV2
export class EntryAttachmentEditor {
  readonly id: number = nextAttachmentId++
  readonly name: string
  readonly data: ArrayBuffer | undefined
  @Trace size: number
  @Trace action: AttachmentEditAction

  constructor(name: string, size: number, data: ArrayBuffer | undefined, action: AttachmentEditAction) {
    this.name = name
    this.size = size
    this.data = data
    this.action = action
  }
}

export enum EntryAvatarAction {
  Keep = 'keep',
  Set = 'set',
  Clear = 'clear'
}

export enum TagAddResult {
  Added = 'added',
  Duplicate = 'duplicate',
  Separator = 'separator'
}

// 半角分号是 KDBX 的标签分隔符，半角逗号是旧版编辑器的分隔符；
// 全角逗号/分号不会被 KDBX 切分，但写入后会与其他客户端显示不一致。
const TAG_SEPARATORS: string[] = [',', ';', '，', '；']

// id 只作列表渲染的稳定标识，删除中间项时不让控件身份错位。
@ObservedV2
export class EntryFieldEditor {
  readonly id: number = nextFieldId++
  // 非空表示该行由模板定义：字段名固定，不可改名、删除或改类型。
  readonly templateKey: string
  @Trace name: string = ''
  @Trace value: string = ''
  @Trace type: VaultFieldType = VaultFieldType.Text
  @Trace protected: boolean = false

  constructor(templateKey: string = '') {
    this.templateKey = templateKey
  }
}

// 一次编辑会话一份，随半模态退出编辑态 reset，不残留内容与初始值快照。
@ObservedV2
export class EntryEditorViewModel {
  @Trace entryUuid: string = ''
  // 模板类型新建即固定，不可切换；未标记类型的既有条目按通用模板（登录信息）编辑。
  @Trace template: ItemTemplate = ItemTemplate.Login
  @Trace title: string = ''
  @Trace username: string = ''
  @Trace password: string = ''
  @Trace url: string = ''
  @Trace notes: string = ''
  @Trace tags: string[] = []
  @Trace groupUuid: string = ''
  // 名称与路径仅用于分组行展示，不参与改动判断（随 groupUuid 派生）。
  @Trace groupName: string = ''
  @Trace groupPath: string = ''
  @Trace fields: EntryFieldEditor[] = []
  @Trace attachments: EntryAttachmentEditor[] = []
  @Trace sshKeys: SshKeyDraft[] = []
  @Trace avatarData: ArrayBuffer | undefined = undefined
  @Trace avatarAction: EntryAvatarAction = EntryAvatarAction.Keep
  @Trace initialValue: string = ''
  readonly titleController: FormItemController = new FormItemController()
  readonly titleSchema: ValidationSchema = stringSchema([required($r('app.string.entry_title_required'))])

  // 返回首个未通过字段的 key（自定义字段为 EntryFieldEditor.id），全部通过返回 undefined。
  validate(): string | undefined {
    if (!this.titleController.validate(this.title)) {
      return 'title'
    }
    const invalidField: EntryFieldEditor | undefined =
      this.fields.find((field: EntryFieldEditor) => field.name.trim().length === 0)
    if (invalidField !== undefined) {
      return `${invalidField.id}`
    }
    return undefined
  }

  setTitle(value: string): void {
    this.title = value
  }

  setUsername(value: string): void {
    this.username = value
  }

  setPassword(value: string): void {
    this.password = value
  }

  setUrl(value: string): void {
    this.url = value
  }

  setNotes(value: string): void {
    this.notes = value
  }

  addTag(value: string): TagAddResult {
    if (TAG_SEPARATORS.some((separator: string) => value.includes(separator))) {
      return TagAddResult.Separator
    }
    if (this.tags.includes(value)) {
      return TagAddResult.Duplicate
    }
    this.tags.push(value)
    return TagAddResult.Added
  }

  removeTag(value: string): void {
    this.tags = this.tags.filter((tag: string) => tag !== value)
  }

  // 密钥草稿的唯一真源是 SshKeys 字段值：每次增删改后立刻回写，沿用既有的字段保存链路。
  loadSshKeys(): void {
    this.sshKeys = parseSshKeys(this.templateField(SSH_KEYS_FIELD)?.value ?? '')
  }

  addSshKey(name: string, privateKey: string, publicKey: string, algorithm: string, bits: number): SshKeyDraft {
    const draft: SshKeyDraft = new SshKeyDraft()
    draft.name = this.uniqueSshKeyName(name)
    draft.privateKey = privateKey
    draft.publicKey = publicKey
    draft.algorithm = algorithm
    draft.bits = bits
    draft.addedAt = Date.now()
    this.sshKeys.push(draft)
    this.syncSshKeyField()
    return draft
  }

  renameSshKey(draft: SshKeyDraft, name: string): void {
    draft.name = name
    this.syncSshKeyField()
  }

  removeSshKey(draft: SshKeyDraft): void {
    this.sshKeys = this.sshKeys.filter((key: SshKeyDraft) => key.id !== draft.id)
    this.syncSshKeyField()
  }

  sshKeyNameTaken(name: string, except: SshKeyDraft | undefined = undefined): boolean {
    return this.sshKeys.some((key: SshKeyDraft) => key.id !== except?.id && key.name === name)
  }

  // 条目内密钥名唯一：重名自动加序号后缀，用户不必先改名再添加。
  private uniqueSshKeyName(name: string): string {
    let candidate: string = name
    let suffix: number = 2
    while (this.sshKeyNameTaken(candidate)) {
      candidate = `${name} ${suffix}`
      suffix++
    }
    return candidate
  }

  private syncSshKeyField(): void {
    const field: EntryFieldEditor | undefined = this.templateField(SSH_KEYS_FIELD)
    if (field === undefined) {
      return
    }
    field.value = serializeSshKeys(this.sshKeys)
  }

  // uuid 驱动保存与改动判断，名称与路径仅驱动展示；禁止分散赋值。
  setGroup(group: VaultGroup): void {
    this.groupUuid = group.uuid
    this.groupName = group.name
    this.groupPath = group.path
  }

  setAvatar(data: ArrayBuffer): void {
    this.avatarData = data
    this.avatarAction = EntryAvatarAction.Set
  }

  clearAvatar(): void {
    this.avatarData = undefined
    this.avatarAction = EntryAvatarAction.Clear
  }

  // 保存入参的头像三态：undefined 不动、null 删除、ArrayBuffer 写入。
  avatarInput(): ArrayBuffer | null | undefined {
    if (this.avatarAction === EntryAvatarAction.Set) {
      return this.avatarData
    }
    if (this.avatarAction === EntryAvatarAction.Clear) {
      return null
    }
    return undefined
  }

  // 字段名重名时自动加序号后缀，保证 KDBX 字段名唯一。
  addField(type: VaultFieldType, name: string): void {
    const field: EntryFieldEditor = new EntryFieldEditor()
    field.name = this.uniqueFieldName(name)
    field.type = type
    field.protected = type === VaultFieldType.Password
    this.fields.push(field)
  }

  // 模板字段的字段名即 KDBX 字段名，不参与重名去重。
  appendTemplateField(key: string, type: VaultFieldType, protectedValue: boolean): EntryFieldEditor {
    const field: EntryFieldEditor = new EntryFieldEditor(key)
    field.name = key
    field.type = type
    field.protected = protectedValue
    this.fields.push(field)
    return field
  }

  templateField(key: string): EntryFieldEditor | undefined {
    return this.fields.find((field: EntryFieldEditor) => field.templateKey === key)
  }

  customFields(): EntryFieldEditor[] {
    return this.fields.filter((field: EntryFieldEditor) => field.templateKey.length === 0)
  }

  // 可见附件：被标记移除的草稿不再展示。
  visibleAttachments(): EntryAttachmentEditor[] {
    return this.attachments.filter((item: EntryAttachmentEditor) => item.action !== AttachmentEditAction.Remove)
  }

  addAttachment(name: string, data: ArrayBuffer): void {
    this.attachments.push(new EntryAttachmentEditor(name, data.byteLength, data, AttachmentEditAction.Add))
  }

  // 尚未保存过的附件直接丢弃，已入库的标记为移除并在保存时删除。
  removeAttachment(item: EntryAttachmentEditor): void {
    if (item.action === AttachmentEditAction.Add) {
      this.attachments = this.attachments.filter((entry: EntryAttachmentEditor) => entry.id !== item.id)
      return
    }
    item.action = AttachmentEditAction.Remove
  }

  // 保存后按落盘结果重建附件草稿：引擎可能对重名附件做过改名，字节也不再需要留在草稿里。
  syncAttachments(attachments: VaultAttachmentMeta[]): void {
    this.attachments = attachments.map((meta: VaultAttachmentMeta) =>
    new EntryAttachmentEditor(meta.name, meta.size, undefined, AttachmentEditAction.Keep))
  }

  // 保存时提交的附件变更：data 为空表示删除该附件。
  attachmentChanges(): VaultAttachmentChange[] {
    const changes: VaultAttachmentChange[] = []
    for (const item of this.attachments) {
      if (item.action === AttachmentEditAction.Add && item.data !== undefined) {
        changes.push({ name: item.name, data: item.data })
      } else if (item.action === AttachmentEditAction.Remove) {
        changes.push({ name: item.name, data: undefined })
      }
    }
    return changes
  }

  removeField(field: EntryFieldEditor): void {
    this.fields.splice(this.fields.indexOf(field), 1)
  }

  renameField(field: EntryFieldEditor, name: string): void {
    field.name = name
  }

  setFieldValue(field: EntryFieldEditor, value: string): void {
    field.value = value
  }

  setFieldType(index: number, type: VaultFieldType): void {
    this.fields[index].type = type
  }

  setFieldProtected(index: number, protectedValue: boolean): void {
    this.fields[index].protected = protectedValue
  }

  // 模板字段留空即视为不使用，不写入 KDBX，避免给条目塞空字段；清空既有值等价于删除该字段。
  fieldInputs(): VaultFieldInput[] {
    return this.fields
      .filter((field: EntryFieldEditor) => field.templateKey.length === 0 || field.value.length > 0)
      .map((field: EntryFieldEditor): VaultFieldInput => {
        return {
          name: field.name.trim(),
          value: field.value,
          type: field.type,
          protected: field.protected,
        }
      })
  }

  private uniqueFieldName(name: string): string {
    let candidate: string = name
    let suffix: number = 2
    while (this.fields.some((field: EntryFieldEditor) => field.name === candidate)) {
      candidate = `${name} ${suffix}`
      suffix++
    }
    return candidate
  }

  // 快照用于与 initialValue 比对修改；头像只记动作标记，不拼图片字节。
  currentValue(): string {
    const fields: string = this.fields.map((field: EntryFieldEditor): string => {
      return `${field.templateKey}\u0001${field.name}\u0001${field.value}\u0001${field.type}\u0001${field.protected}`
    }).join('\u0002')
    const attachments: string = this.attachments.map((item: EntryAttachmentEditor): string => {
      return `${item.name}\u0001${item.size}\u0001${item.action}`
    }).join('\u0002')
    return [this.template, this.title, this.username, this.password, this.url,
      this.notes, this.tags.join('\n'), this.groupUuid, fields, attachments, this.avatarAction].join('\n')
  }

  changed(): boolean {
    return this.initialValue !== this.currentValue()
  }

  // 头像动作先归位 Keep，否则再次保存会重复写入同一张图。
  markSaved(): void {
    this.avatarAction = EntryAvatarAction.Keep
    this.initialValue = this.currentValue()
  }

  reset(): void {
    this.entryUuid = ''
    this.template = ItemTemplate.Login
    this.title = ''
    this.titleController.reset()
    this.username = ''
    this.password = ''
    this.url = ''
    this.notes = ''
    this.tags = []
    this.groupUuid = ''
    this.groupName = ''
    this.groupPath = ''
    this.fields = []
    this.attachments = []
    this.sshKeys = []
    this.avatarData = undefined
    this.avatarAction = EntryAvatarAction.Keep
    this.initialValue = ''
  }
}
