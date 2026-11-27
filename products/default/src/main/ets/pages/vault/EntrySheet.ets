import { LengthMetrics, promptAction } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { AnimationTokens, measureVp } from '@ohos/common'
import { LogUtil } from '@pura/harmony-utils'
import { AppSessionState, appSessionState } from '../../state/AppSessionState'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { EntrySheetViewModel, entrySheetViewModel } from '../../viewmodel/EntrySheetViewModel'
import { DeferredAction } from '../../components/DeferredAction'
import { DsBottomActionBar } from '../../components/DsBottomActionBar'
import { DsButton, DsButtonVariant } from '../../components/DsButton'
import { DsContextMenu } from '../../components/DsContextMenu'
import { dsDialogOptions } from '../../components/DsDialog'
import { DsHalfModalSheet } from '../../components/DsHalfModalSheet'
import { DsMenuGroup } from '../../components/DsMenuGroup'
import { DsMenuItem, DsMenuItemTheme } from '../../components/DsMenuItem'
import { DsPageHeader, DsPageHeaderAction, DsPageHeaderSize } from '../../components/DsPageHeader'
import { DsToastHost } from '../../components/DsToast'
import { FavoriteToggle } from '../../components/FavoriteToggle'
import { dsSheetOptions } from '../../components/DsSheetOptions'
import { EntryDeleteDialog } from './EntryDeleteDialog'
import { EntryEditorActions, EntryEditorView } from './EntryEditorView'
import { EntryPreviewView } from './EntryPreviewView'

@ObservedV2
class EntrySheetChromeState {
  @Trace editor: EntryEditorActions | undefined = undefined
  @Trace switching: boolean = false
}

// HDS 标题栏的 builder 链只构建一次，插槽内容不会随页面状态重建：
// 收藏按钮放进独立组件自读模型，收藏值与可用态才能跟着变。
@ComponentV2
struct EntrySheetFavoriteAction {
  @Require @Param sheet: EntrySheetViewModel
  @Require @Param chrome: EntrySheetChromeState
  @Event onToggle: () => void = () => {}
  private readonly app: AppViewModel = appViewModel

  build() {
    FavoriteToggle({
      visible: this.sheet.editing || !this.sheet.readOnly,
      favorite: this.sheet.editing ? this.sheet.draft.favorite : this.sheet.favorite,
      clickable: !this.app.busy && !this.chrome.switching,
      iconSizeOverride: $r('app.float.ds_icon_md'),
      onToggle: () => this.onToggle(),
    })
  }
}

// HDS 标题栏只构建一次，由此组件直接订阅视图状态。
@ComponentV2
struct EntrySheetHeader {
  @Require @Param sheet: EntrySheetViewModel
  @Require @Param chrome: EntrySheetChromeState
  @Event onClose: () => void = () => {}
  @Event onToggleFavorite: () => void = () => {}
  private readonly app: AppViewModel = appViewModel

  @Computed
  private get editing(): boolean {
    return this.sheet.editing
  }

  @Computed
  private get title(): ResourceStr {
    if (!this.editing) {
      return this.sheet.title
    }
    return this.sheet.isNewEntry ? $r('app.string.new_entry') : $r('app.string.edit_entry')
  }

  @Computed
  private get headerActions(): DsPageHeaderAction[] {
    if (this.sheet.isNewEntry || (!this.editing && this.sheet.readOnly)) {
      return []
    }
    return [{
      icon: $r('app.string.symbol_more'),
      label: $r('app.string.more'),
      enabled: !this.app.busy && !this.chrome.switching,
      onTap: () => {},
    }]
  }

  @LocalBuilder
  private favoriteAction() {
    EntrySheetFavoriteAction({
      sheet: this.sheet,
      chrome: this.chrome,
      onToggle: () => this.onToggleFavorite(),
    })
  }

  build() {
    DsPageHeader({
      title: this.title,
      titleTransitionKey: this.sheet.mode,
      scrollOverflowingTitle: !this.editing,
      headerSize: DsPageHeaderSize.Small,
      showBack: false,
      showClose: true,
      closeEnabled: !this.app.busy && !this.chrome.switching,
      actions: this.headerActions,
      actionsBuilder: this.favoriteAction,
      onClose: () => this.onClose(),
    })
  }
}

@ComponentV2
export struct EntrySheet {
  @Param sheet: EntrySheetViewModel = entrySheetViewModel
  @Local private session: AppSessionState = appSessionState
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private chrome: EntrySheetChromeState = new EntrySheetChromeState()
  // 系统回传的面板高度（vp），避免嵌套滚动容器按整窗高度布局。
  @Local private panelHeightVp: number = 0
  @Local private bottomBarHeight: number = 0
  @Local private previewScrollOffset: number = 0
  @Local private matchPreviewAvatar: boolean = true
  @Local private matchEditorAvatar: boolean = true
  @Local private opening: boolean = true
  private previewAvatarVisible: boolean = false
  private editorAvatarVisible: boolean = false
  private restorePreviewAvatar: boolean = false
  private transitionVersion: number = 0
  private readonly viewModel: AppViewModel = appViewModel
  private readonly previewScroller: Scroller = new Scroller()
  private readonly editorScroller: Scroller = new Scroller()
  private readonly overflowDeferred: DeferredAction = new DeferredAction()
  private readonly deleteDialogController: promptAction.DialogController = new promptAction.DialogController()

  @Monitor('session.vaultLocked')
  onVaultLockChanged(): void {
    if (this.session.vaultLocked) {
      this.sheet.close()
    }
  }

  @Monitor('sheet.entryUuid', 'sheet.visible')
  onTargetChanged(): void {
    this.sheet.load()
  }

  @Computed
  private get editing(): boolean {
    return this.sheet.editing
  }

  @Computed
  private get avatarEntranceScale(): number {
    if (!this.opening || this.sheet.isNewEntry) {
      return 1
    }
    const context: UIContext = this.getUIContext()
    return measureVp(context, $r('app.float.ds_entry_avatar_size')) /
      measureVp(context, $r('app.float.ds_entry_preview_avatar_size'))
  }

  @Computed
  private get panelContentHeight(): Length {
    return this.panelHeightVp > 0 ? this.panelHeightVp : '100%'
  }

  @Computed
  private get contentBottomOffset(): number {
    if (this.bottomBarHeight > 0 && !this.sheet.readOnly) {
      return this.bottomBarHeight
    }
    const context: UIContext = this.getUIContext()
    return context.px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx) +
      measureVp(context, $r('app.float.ds_space_sm'))
  }

  @Computed
  private get avatarTransitionKey(): string {
    return this.sheet.isNewEntry ? '' : 'entry-sheet-avatar-' + this.sheet.entryUuid
  }

  @Computed
  private get overflowButtonMargin(): Margin {
    const context: UIContext = this.getUIContext()
    const handle: number = measureVp(context, $r('app.float.ds_space_16'))
    const header: number = measureVp(context, $r('app.float.ds_page_header_height_sm'))
    const button: number = measureVp(context, $r('app.float.ds_button_height'))
    return {
      top: handle + (header - button) / 2,
      right: button + measureVp(context, $r('app.float.ds_space_sm')),
    }
  }

  private switchMode(change: () => void): void {
    this.opening = false
    const version: number = ++this.transitionVersion
    this.chrome.switching = true
    // 动画被后续动画打断时 onFinish 不再回调，定时器保证交互一定恢复。
    setTimeout(() => this.finishSwitch(version), AnimationTokens.STATE_TRANSITION_DURATION + 16)
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
      onFinish: () => this.finishSwitch(version),
    }, change)
  }

  private finishSwitch(version: number): void {
    if (this.transitionVersion !== version) {
      return
    }
    this.matchPreviewAvatar = true
    this.matchEditorAvatar = true
    this.chrome.switching = false
  }

  private beginEdit(): void {
    this.previewScrollOffset = Math.max(0, this.previewScroller.currentOffset().yOffset)
    this.restorePreviewAvatar = this.previewAvatarVisible &&
      this.previewScrollOffset <= measureVp(this.getUIContext(), $r('app.float.ds_space_sm'))
    this.editorAvatarVisible = false
    this.switchMode(() => {
      this.matchEditorAvatar = this.restorePreviewAvatar
      this.sheet.beginEdit()
    })
  }

  private exitEditor(): void {
    this.chrome.editor = undefined
    if (!this.sheet.editFromPreview) {
      this.sheet.exitEditor()
      return
    }
    this.previewAvatarVisible = false
    this.switchMode(() => {
      this.matchPreviewAvatar = this.restorePreviewAvatar && this.editorAvatarVisible
      this.sheet.exitEditor()
    })
  }

  private async toggleFavorite(): Promise<void> {
    const uuid: string = this.sheet.entryUuid
    if (this.editing) {
      await this.chrome.editor?.toggleFavorite()
    } else {
      await this.sheet.toggleFavorite()
    }
    if (uuid.length > 0 && this.sheet.visible && this.sheet.entryUuid === uuid) {
      this.sheet.load()
    }
  }

  private onDismissed(): void {
    this.opening = true
    this.transitionVersion++
    this.chrome.switching = false
    this.chrome.editor = undefined
    this.previewScrollOffset = 0
    this.previewAvatarVisible = false
    this.editorAvatarVisible = false
    this.restorePreviewAvatar = false
    this.matchPreviewAvatar = true
    this.matchEditorAvatar = true
    this.sheet.onDismissed()
  }

  private onSheetWillDismiss(action: DismissSheetAction): void {
    if (this.chrome.switching || this.viewModel.busy) {
      return
    }
    if (this.editing && this.chrome.editor !== undefined) {
      this.chrome.editor.requestExit()
      return
    }
    action.dismiss()
  }

  private async duplicateEntry(): Promise<void> {
    const uuid: string = await this.viewModel.duplicateEntry(this.sheet.entryUuid)
    if (uuid.length > 0) {
      this.sheet.markHomeDirty()
    }
    DsToastHost.show(this.getUIContext(), uuid.length > 0 ? $r('app.string.entry_copied') : this.viewModel.status)
  }

  private async toggleArchived(): Promise<void> {
    const archived: boolean = this.sheet.previewEntry?.archived === true
    if (await this.viewModel.toggleArchived(this.sheet.entryUuid)) {
      DsToastHost.show(this.getUIContext(), archived ? $r('app.string.entry_restored') : $r('app.string.entry_archived'))
      this.sheet.close()
      return
    }
    DsToastHost.show(this.getUIContext(), this.viewModel.status)
  }

  private openDeleteDialog(): void {
    this.getUIContext().getPromptAction()
      .presentCustomDialog(() => this.deleteDialog(), this.deleteDialogController, dsDialogOptions())
      .catch((error: BusinessError) => {
        LogUtil.error(`打开删除条目弹窗失败，错误码=${error.code}，错误信息=${error.message}`)
      })
  }

  private deleteEntry(): void {
    // 落盘是异步写文件，等回调再关弹窗不会被关掉，必须先关再删。
    this.deleteDialogController.close()
    this.viewModel.deleteEntry(this.sheet.entryUuid).then((deleted: boolean) => {
      if (deleted) {
        this.sheet.markHomeDirty()
        DsToastHost.show(this.getUIContext(), $r('app.string.entry_moved_to_recycle_bin'))
        this.sheet.close()
        return
      }
      DsToastHost.show(this.getUIContext(), this.viewModel.status)
    })
  }

  @Builder
  private deleteDialog() {
    EntryDeleteDialog({
      onCancel: () => this.deleteDialogController.close(),
      onConfirm: () => this.deleteEntry(),
    })
  }

  @LocalBuilder
  private overflowMenuHeader() {
    Text($r('app.string.more_actions'))
      .width('100%')
      .fontSize($r('app.float.ds_font_body'))
      .fontWeight(600)
      .fontColor($r('app.color.ds_text_primary'))
      .padding({
        top: $r('app.float.ds_space_md'), bottom: $r('app.float.ds_space_md'),
        left: $r('app.float.ds_gutter'), right: $r('app.float.ds_gutter'),
      })
      .backgroundColor($r('app.color.ds_surface_low'))
  }

  @LocalBuilder
  private deleteMenuItem() {
    DsMenuItem({
      icon: $r('app.string.symbol_delete'),
      label: $r('app.string.delete_entry'),
      theme: DsMenuItemTheme.Error,
      onAction: () => this.overflowDeferred.defer(() => this.openDeleteDialog()),
    })
  }

  @LocalBuilder
  private overflowMainActions() {
    DsMenuItem({
      icon: $r('app.string.symbol_copy'),
      label: $r('app.string.entry_menu_duplicate'),
      onAction: () => this.duplicateEntry(),
    })
    if (!this.editing) {
      DsMenuItem({
        icon: this.sheet.previewEntry?.archived ? $r('app.string.symbol_unarchive') : $r('app.string.symbol_archive'),
        label: this.sheet.previewEntry?.archived ? $r('app.string.entry_menu_restore') : $r('app.string.entry_menu_archive'),
        onAction: () => this.overflowDeferred.defer(() => this.toggleArchived()),
      })
    }
  }

  @LocalBuilder
  private overflowMenuItems() {
    DsMenuGroup({ content: this.overflowMainActions })
    if (!this.sheet.readOnly) {
      DsMenuGroup({ dividerTop: !this.editing, content: this.deleteMenuItem })
    }
  }

  @LocalBuilder
  private overflowMenu() {
    DsContextMenu({ header: this.overflowMenuHeader, content: this.overflowMenuItems })
  }

  @LocalBuilder
  private overflowButton() {
    // 在内容层同位置承接页头「更多」的菜单交互。
    Row() {
      DsButton({
        variant: DsButtonVariant.Text,
        iconOnly: true,
        disabled: this.viewModel.busy || this.chrome.switching,
        accessibilityLabelResource: $r('app.string.more'),
        menuBuilder: this.overflowMenu,
        menuOptions: {
          placement: Placement.BottomRight,
          targetSpace: LengthMetrics.resource(this.editing ? $r('app.float.ds_space_sm') : $r('app.float.ds_space_xs')),
          borderRadius: $r('app.float.ds_radius_none'),
          backgroundColor: $r('app.color.ds_surface_lowest'),
          backgroundBlurStyle: BlurStyle.NONE,
          mask: { color: $r('app.color.ds_scrim'), backgroundBlurStyle: BlurStyle.NONE },
          onDisappear: () => this.overflowDeferred.run(),
        },
      })
      .margin(this.overflowButtonMargin)
    }
    .width('100%')
    .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    .padding({ left: $r('app.float.ds_gutter'), right: $r('app.float.ds_gutter') })
    .justifyContent(FlexAlign.End)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @LocalBuilder
  private sheetHeader() {
    EntrySheetHeader({
      sheet: this.sheet,
      chrome: this.chrome,
      onToggleFavorite: () => this.toggleFavorite(),
      onClose: () => {
        if (this.editing) {
          this.chrome.editor?.requestExit()
        } else {
          this.sheet.close()
        }
      },
    })
  }

  @LocalBuilder
  private primaryAction() {
    DsButton({
      label: this.editing ? $r('app.string.save') : $r('app.string.edit'),
      fullWidth: true,
      loading: this.editing && this.chrome.editor?.saveGate.visible === true,
      disabled: this.chrome.switching || (this.editing ? this.chrome.editor === undefined : this.viewModel.busy),
      onTap: () => {
        if (this.editing) {
          this.chrome.editor?.save()
        } else {
          this.beginEdit()
        }
      },
    })
  }

  @LocalBuilder
  private bottomBar() {
    if (!this.sheet.readOnly) {
      DsBottomActionBar({
        onHeightChange: (height: number) => this.bottomBarHeight = height,
        contentBuilder: this.primaryAction,
      })
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
    }
  }

  @LocalBuilder
  private sheetBody() {
    Stack({ alignContent: Alignment.Top }) {
      if (this.editing) {
        EntryEditorView({
          sheet: this.sheet,
          draft: this.sheet.draft,
          scroller: this.editorScroller,
          bottomOffset: this.contentBottomOffset,
          avatarTransitionKey: this.matchEditorAvatar ? this.avatarTransitionKey : '',
          avatarEntranceScale: this.avatarEntranceScale,
          onAvatarVisibilityChange: (visible: boolean) => this.editorAvatarVisible = visible,
          onReady: (actions: EntryEditorActions) => this.chrome.editor = actions,
          onCancel: () => this.exitEditor(),
          onSaved: () => {
            this.sheet.markHomeDirty()
            if (this.sheet.editFromPreview) {
              this.sheet.load()
            }
            this.exitEditor()
          },
        })
          .transition(TransitionEffect.OPACITY)
      } else {
        EntryPreviewView({
          sheet: this.sheet,
          scroller: this.previewScroller,
          bottomOffset: this.contentBottomOffset,
          initialScrollOffset: this.previewScrollOffset,
          avatarTransitionKey: this.matchPreviewAvatar ? this.avatarTransitionKey : '',
          avatarEntranceScale: this.avatarEntranceScale,
          onAvatarVisibilityChange: (visible: boolean) => this.previewAvatarVisible = visible,
        })
          .transition(TransitionEffect.OPACITY)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private sheetContent() {
    Stack({ alignContent: Alignment.Top }) {
      DsHalfModalSheet({
        titleBarBuilder: this.sheetHeader,
        scrollableScroller: this.editing ? this.editorScroller : this.previewScroller,
        bodyBuilder: this.sheetBody,
        bottomBarBuilder: this.bottomBar,
      })
      if (!this.sheet.isNewEntry && (this.editing || !this.sheet.readOnly)) {
        this.overflowButton()
      }
    }
    .width('100%')
    .height(this.panelContentHeight)
  }

  build() {
    Stack()
      .width(0)
      .height(0)
      .bindSheet(this.sheet.visible, this.sheetContent(), dsSheetOptions({
        keyboardAvoidMode: SheetKeyboardAvoidMode.NONE,
        onHeightDidChange: (heightPx: number) => {
          this.panelHeightVp = this.getUIContext().px2vp(heightPx)
        },
        onWillDismiss: (action: DismissSheetAction) => this.onSheetWillDismiss(action),
        onAppear: () => this.opening = false,
        onDisappear: () => this.onDismissed(),
      }))
  }
}
