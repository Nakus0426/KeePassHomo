/**
 * 条目编辑器页面域 ViewModel：随 EntryEditPage 入栈创建、出栈销毁，
 * 编辑内容与初始值快照不跨导航残留。
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

  /**
   * 编辑器当前内容快照，用于与 initialValue 对比判断是否有未保存修改。
   */
  currentValue(): string {
    return [this.title, this.username, this.password, this.url,
      this.notes, this.tags, this.groupUuid].join('\n')
  }

  changed(): boolean {
    return this.initialValue !== this.currentValue()
  }

  /**
   * 保存成功后同步初始值快照。
   */
  markSaved(): void {
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
    this.initialValue = ''
  }
}
