// 独立成文件：宿主组件与编辑态内容都要读它，放在宿主组件文件里会形成组件间循环依赖。
// 三个字段各自独立：切换形态不动开合状态，切换条目不动形态。
@ObservedV2
export class EntrySheetState {
  @Trace visible: boolean = false
  @Trace mode: EntrySheetMode = EntrySheetMode.Preview
  // 目标条目 uuid；空串表示新建，没有预览态。
  @Trace entryUuid: string = ''
  // 编辑态退出后是否返回预览：左滑编辑与新建直接收起半模态。
  @Trace editFromPreview: boolean = false
}

// 半模态形态：预览态只看与取值，编辑态改草稿。
export enum EntrySheetMode {
  Preview = 'preview',
  Edit = 'edit'
}
