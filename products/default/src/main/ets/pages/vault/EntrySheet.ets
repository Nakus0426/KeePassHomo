import { uiMaterial } from '@kit.ArkUI'
import { AnimationTokens, VaultEntry } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { AppSessionState, appSessionState } from '../../state/AppSessionState'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { EntrySheetMode, EntrySheetState } from '../../viewmodel/EntrySheetState'
import { EntryEditorContent } from './EntryEditorContent'
import { EntryPreviewContent } from './EntryPreviewContent'

/**
 * 条目半模态宿主：三种入口共用一套开合逻辑。
 * 列表点条目进预览态，首页「新建条目」与预览态的「编辑」进编辑态。
 * 只负责半模态容器、标题栏与形态切换；预览体与编辑体各自管理自身状态。
 */
@ComponentV2
export struct EntrySheet {
  @Param state: EntrySheetState = new EntrySheetState()
  @Local private session: AppSessionState = appSessionState
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  /** 预览条目的当前数据：随 revision 与 uuid 变化重取，不在 build 里反复查表。 */
  @Local private entry: VaultEntry | undefined = undefined
  @Local private avatarData: ArrayBuffer | undefined = undefined
  /**
   * 编辑体的退出拦截钩子：草稿归编辑体所有，宿主只能在收起前问它一句。
   * 编辑体在 aboutToAppear 注册，形态或条目变化时由宿主重置，避免回调残留。
   */
  private childHandler: (() => void) | undefined = undefined
  private readonly viewModel: AppViewModel = appViewModel
  /** 预览与编辑共用半模态容器，只对内容做轻微缩放交叉淡化，避免窗口整体跳动。 */
  private readonly contentTransition: TransitionEffect = TransitionEffect.asymmetric(
    TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: 0.96, y: 0.96 }))
      .animation({
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
      }),
    TransitionEffect.OPACITY
      .combine(TransitionEffect.scale({ x: 1.02, y: 1.02 }))
      .animation({
        duration: AnimationTokens.STATE_TRANSITION_DURATION,
        curve: AnimationTokens.STATE_TRANSITION_CURVE,
      }),
  )

  @Monitor('session.vaultLocked')
  onVaultLockChanged(): void {
    if (this.session.vaultLocked) {
      this.state.visible = false
    }
  }

  /**
   * 预览数据跟随三种变化重取：换条目、重新打开、保险库内容变更（revision）。
   * 收藏与归档都会推进 revision，标题栏文案与图标据此跟着变。
   */
  @Monitor('state.entryUuid', 'state.visible', 'viewModel.revision')
  onTargetChanged(): void {
    this.childHandler = undefined
    this.loadEntry()
  }

  /** 编辑体进入与离开都据此重置拦截钩子，避免残留指向已销毁实例的回调。 */
  @Monitor('state.mode')
  onModeChanged(): void {
    this.childHandler = undefined
  }

  private loadEntry(): void {
    this.entry = this.state.visible && this.state.entryUuid.length > 0
      ? this.viewModel.entry(this.state.entryUuid) : undefined
    this.avatarData = this.entry === undefined
      ? undefined : this.viewModel.loadEntryAvatar(this.entry.uuid)
  }

  private get readOnly(): boolean {
    return this.viewModel.currentSource().readOnly
  }

  /** 新建没有可回退的条目，取消直接收起半模态。 */
  private get isNewEntry(): boolean {
    return this.state.entryUuid.length === 0
  }

  private get entryTitle(): string {
    return this.entry?.title ?? ''
  }

  private get entryGroupPath(): string {
    return this.entry?.groupPath ?? ''
  }

  private get entryFavorite(): boolean {
    return this.entry?.favorite ?? false
  }

  @Computed
  get contentTopOffset(): number {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const gapPx = ResUtil.getNumber($r('sys.float.padding_level16').id)
    return this.getUIContext().px2vp(titlebarHeightPx + gapPx)
  }

  @Computed
  get contentBottomOffset(): number {
    return this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx)
  }

  @Computed
  get sheetTopAvoidAreaHeight(): number {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const paddingHeightPx = ResUtil.getNumber($r('sys.float.padding_level12').id)
    return this.getUIContext().px2vp(titlebarHeightPx + paddingHeightPx)
  }

  private closeSheet(): void {
    this.state.visible = false
  }

  private openEditor(): void {
    this.state.editFromPreview = true
    this.state.mode = EntrySheetMode.Edit
  }

  private returnToPreview(): void {
    this.state.mode = EntrySheetMode.Preview
  }

  /**
   * 编辑态统一出口：直接编辑或新建收起半模态，预览页进入编辑后退回预览态。
   * 草稿的丢弃由编辑体自行复位，宿主只管形态。
   */
  private exitEditor(): void {
    if (this.isNewEntry || !this.state.editFromPreview) {
      this.state.visible = false
      return
    }
    this.returnToPreview()
  }

  private toggleFavorite(): void {
    this.viewModel.toggleFavorite(this.state.entryUuid)
  }

  /**
   * 归档与还原都让条目落到列表当前浏览条件之外，收起半模态并回首页。
   * 快照必须重建：归档后卡片要退出列表，还原后要回到列表。
   */
  private confirmDiscard(onDiscard: () => void): void {
    const options: AlertDialogParamWithButtons = {
      title: $r('app.string.unsaved_title'),
      message: $r('app.string.unsaved_message'),
      primaryButton: {
        value: $r('app.string.continue_editing'),
        action: () => {
        },
      },
      secondaryButton: {
        value: $r('app.string.discard'),
        fontColor: $r('sys.color.warning'),
        action: () => onDiscard(),
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  /**
   * 拖拽收起前的拦截：只有编辑态的草稿需要拦。
   * 预览态是只读的，收起不丢数据。
   */
  private onSheetWillDismiss(action: DismissSheetAction): void {
    if (this.childHandler === undefined) {
      action.dismiss()
      return
    }
    this.confirmDiscard(() => this.closeSheet())
  }

  @Builder
  private sheetContent() {
    if (this.state.mode === EntrySheetMode.Preview) {
      EntryPreviewContent({
        title: this.entryTitle,
        groupPath: this.entryGroupPath,
        fields: this.entry?.fields ?? [],
        tags: this.entry?.tags ?? [],
        entryUuid: this.state.entryUuid,
        favorite: this.entryFavorite,
        readOnly: this.readOnly,
        avatarData: this.avatarData,
        topOffset: this.contentTopOffset,
        bottomOffset: this.contentBottomOffset,
        onClose: () => this.closeSheet(),
        onEdit: () => this.openEditor(),
      }).transition(this.contentTransition)
    } else {
      EntryEditorContent({
        state: this.state,
        topOffset: this.sheetTopAvoidAreaHeight,
        bottomOffset: this.contentBottomOffset,
        onWillDismissCheck: (handler: () => void) => this.childHandler = handler,
        onCancel: () => this.exitEditor(),
        onSaved: () => this.exitEditor(),
      }).transition(this.contentTransition)
    }
  }

  build() {
    Stack()
      .width(0)
      .height(0)
      .bindSheet(this.state.visible, this.sheetContent(), {
        dragBar: true,
        showClose: false,
        backgroundColor: Color.Transparent,
        systemMaterial: new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
        }),
        onWillDismiss: (action: DismissSheetAction) => this.onSheetWillDismiss(action),
        onDisappear: () => {
          this.state.visible = false
          this.state.mode = EntrySheetMode.Preview
          this.state.editFromPreview = false
          this.viewModel.refreshHomeSnapshot()
        },
      })
  }
}
