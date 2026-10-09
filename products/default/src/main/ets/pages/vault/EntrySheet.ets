import { uiMaterial } from '@kit.ArkUI'
import { AnimationTokens } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { AppSessionState, appSessionState } from '../../state/AppSessionState'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { EntrySheetMode, EntrySheetViewModel, entrySheetViewModel } from '../../viewmodel/EntrySheetViewModel'
import { EntryEditorView } from './EntryEditorView'
import { EntryPreviewView } from './EntryPreviewView'

// 三种入口共用一套开合逻辑：只负责半模态容器、形态转场与收起拦截，内容体各自管理自己的状态。
@ComponentV2
export struct EntrySheet {
  @Param sheet: EntrySheetViewModel = entrySheetViewModel
  @Local private session: AppSessionState = appSessionState
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  // 草稿归编辑体所有，宿主只能在收起前问它；形态或条目变化时必须重置以免回调残留。
  private childHandler: (() => void) | undefined = undefined
  private readonly viewModel: AppViewModel = appViewModel
  // 预览与编辑共用半模态容器，只对内容做轻微缩放交叉淡化，避免窗口整体跳动。
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
      this.sheet.visible = false
    }
  }

  // 换条目、重新打开、revision 变化时重取；收藏与归档都会推进 revision。
  @Monitor('sheet.entryUuid', 'sheet.visible', 'viewModel.revision')
  onTargetChanged(): void {
    this.childHandler = undefined
    this.sheet.load()
  }

  // 形态变化时重置拦截钩子，避免残留指向已销毁实例的回调。
  @Monitor('sheet.mode')
  onModeChanged(): void {
    this.childHandler = undefined
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

  private confirmDiscard(): void {
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
        action: () => this.sheet.close(),
      },
    }
    this.getUIContext().showAlertDialog(options)
  }

  // 只有编辑态的草稿需要拦截；预览态是只读的，收起不丢数据。
  private onSheetWillDismiss(action: DismissSheetAction): void {
    if (this.childHandler === undefined) {
      action.dismiss()
      return
    }
    this.confirmDiscard()
  }

  @Builder
  private sheetContent() {
    if (this.sheet.mode === EntrySheetMode.Preview) {
      EntryPreviewView({
        sheet: this.sheet,
        topOffset: this.contentTopOffset,
        bottomOffset: this.contentBottomOffset,
        onClose: () => this.sheet.close(),
        onEdit: () => this.sheet.beginEdit(),
      }).transition(this.contentTransition)
    } else {
      EntryEditorView({
        sheet: this.sheet,
        topOffset: this.sheetTopAvoidAreaHeight,
        bottomOffset: this.contentBottomOffset,
        onWillDismissCheck: (handler: () => void) => this.childHandler = handler,
        onCancel: () => this.sheet.exitEditor(),
        onSaved: () => this.sheet.exitEditor(),
      }).transition(this.contentTransition)
    }
  }

  build() {
    Stack()
      .width(0)
      .height(0)
      .bindSheet(this.sheet.visible, this.sheetContent(), {
        dragBar: true,
        showClose: false,
        backgroundColor: Color.Transparent,
        systemMaterial: new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
        }),
        onWillDismiss: (action: DismissSheetAction) => this.onSheetWillDismiss(action),
        onDisappear: () => this.sheet.onDismissed(),
      })
  }
}
