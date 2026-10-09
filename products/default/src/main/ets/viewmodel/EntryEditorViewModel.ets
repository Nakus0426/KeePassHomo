import { required, stringSchema, ValidationSchema, VaultFieldInput, VaultFieldType, VaultGroup } from '@ohos/common'
import { FormItemController } from '../components/FormItem'

let nextFieldId: number = 1

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
  @Trace name: string = ''
  @Trace value: string = ''
  @Trace type: VaultFieldType = VaultFieldType.Text
  @Trace protected: boolean = false
}

// 一次编辑会话一份，随半模态退出编辑态 reset，不残留内容与初始值快照。
@ObservedV2
export class EntryEditorViewModel {
  @Trace entryUuid: string = ''
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

  removeField(index: number): void {
    this.fields.splice(index, 1)
  }

  renameField(index: number, name: string): void {
    this.fields[index].name = name
  }

  setFieldValue(index: number, value: string): void {
    this.fields[index].value = value
  }

  setFieldType(index: number, type: VaultFieldType): void {
    this.fields[index].type = type
  }

  setFieldProtected(index: number, protectedValue: boolean): void {
    this.fields[index].protected = protectedValue
  }

  fieldInputs(): VaultFieldInput[] {
    return this.fields.map((field: EntryFieldEditor): VaultFieldInput => {
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
      return `${field.name}\u0001${field.value}\u0001${field.type}\u0001${field.protected}`
    }).join('\u0002')
    return [this.title, this.username, this.password, this.url,
      this.notes, this.tags.join('\n'), this.groupUuid, fields, this.avatarAction].join('\n')
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
    this.avatarData = undefined
    this.avatarAction = EntryAvatarAction.Keep
    this.initialValue = ''
  }
}
