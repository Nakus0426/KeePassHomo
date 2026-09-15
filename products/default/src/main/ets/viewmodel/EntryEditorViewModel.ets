import { VaultFieldInput, VaultFieldType } from '@ohos/common'

let nextFieldId: number = 1

/**
 * 头像的待写入意图：Keep 不动原头像，Set 写入 avatarData，Clear 删除原头像。
 * 与 avatarData 分开，因为"当前显示的头像"和"保存时要写的动作"是两件事。
 */
export enum EntryAvatarAction {
  Keep = 'keep',
  Set = 'set',
  Clear = 'clear'
}

/**
 * 编辑器内的自定义字段：逐项 @Trace，改字段名/类型/敏感都直接驱动对应输入控件。
 * id 只用于列表渲染的稳定标识，删除中间项时不让控件身份错位。
 */
@ObservedV2
export class EntryFieldEditor {
  readonly id: number = nextFieldId++
  @Trace name: string = ''
  @Trace value: string = ''
  @Trace type: VaultFieldType = VaultFieldType.Text
  @Trace protected: boolean = false
}

/**
 * 条目编辑器 ViewModel：与 EntryEditSheet 的开合生命周期绑定，
 * 关闭即重置，编辑内容与初始值快照不残留。
 */
@ObservedV2
export class EntryEditorViewModel {
  @Trace entryUuid: string = ''
  @Trace title: string = ''
  @Trace username: string = ''
  @Trace password: string = ''
  @Trace url: string = ''
  @Trace notes: string = ''
  @Trace tags: string = ''
  @Trace groupUuid: string = ''
  @Trace fields: EntryFieldEditor[] = []
  @Trace avatarData: ArrayBuffer | undefined = undefined
  @Trace avatarAction: EntryAvatarAction = EntryAvatarAction.Keep
  @Trace initialValue: string = ''

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

  setTags(value: string): void {
    this.tags = value
  }

  setGroup(groupUuid: string): void {
    this.groupUuid = groupUuid
  }

  setAvatar(data: ArrayBuffer): void {
    this.avatarData = data
    this.avatarAction = EntryAvatarAction.Set
  }

  clearAvatar(): void {
    this.avatarData = undefined
    this.avatarAction = EntryAvatarAction.Clear
  }

  /** 保存入参的头像三态：undefined 不动、null 删除、ArrayBuffer 写入。 */
  avatarInput(): ArrayBuffer | null | undefined {
    if (this.avatarAction === EntryAvatarAction.Set) {
      return this.avatarData
    }
    if (this.avatarAction === EntryAvatarAction.Clear) {
      return null
    }
    return undefined
  }

  /** 追加自定义字段：字段名重名时自动加序号后缀，保证 KDBX 字段名唯一。 */
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

  /** 保存入参：去除字段名两端空白后交给引擎。 */
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

  /**
   * 编辑器当前内容快照，用于与 initialValue 对比判断是否有未保存修改。
   * 头像只记动作标记，不拼图片字节。
   */
  currentValue(): string {
    const fields: string = this.fields.map((field: EntryFieldEditor): string => {
      return `${field.name}\u0001${field.value}\u0001${field.type}\u0001${field.protected}`
    }).join('\u0002')
    return [this.title, this.username, this.password, this.url,
      this.notes, this.tags, this.groupUuid, fields, this.avatarAction].join('\n')
  }

  changed(): boolean {
    return this.initialValue !== this.currentValue()
  }

  /**
   * 保存成功后同步初始值快照。头像动作先归位 Keep，
   * 否则再次保存会重复写入同一张图。
   */
  markSaved(): void {
    this.avatarAction = EntryAvatarAction.Keep
    this.initialValue = this.currentValue()
  }

  reset(): void {
    this.entryUuid = ''
    this.title = ''
    this.username = ''
    this.password = ''
    this.url = ''
    this.notes = ''
    this.tags = ''
    this.groupUuid = ''
    this.fields = []
    this.avatarData = undefined
    this.avatarAction = EntryAvatarAction.Keep
    this.initialValue = ''
  }
}
