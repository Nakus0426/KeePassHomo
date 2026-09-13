import { SymbolGlyphModifier, uiMaterial } from '@kit.ArkUI'
import { hdsMaterial, HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit'
import { VaultFieldType } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { AppSessionState, appSessionState } from '../../state/AppSessionState'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { EntryEditorViewModel } from '../../viewmodel/EntryEditorViewModel'

const DATE_PATTERN: string = 'yyyy-MM-dd'

/**
 * 自定义字段预设：label 是界面文案，defaultName 是落盘的字段名（固定中文，
 * 不随界面语言变化——字段名是写进用户文件的数据）。
 */
interface FieldPreset {
  type: VaultFieldType
  label: Resource
  defaultName: string
}

const FIELD_PRESETS: FieldPreset[] = [
  { type: VaultFieldType.Text, label: $r('app.string.field_type_text'), defaultName: '文本' },
  { type: VaultFieldType.Url, label: $r('app.string.website'), defaultName: '网址' },
  { type: VaultFieldType.Email, label: $r('app.string.field_type_email'), defaultName: '邮箱' },
  { type: VaultFieldType.Phone, label: $r('app.string.field_type_phone'), defaultName: '电话' },
  { type: VaultFieldType.Address, label: $r('app.string.field_type_address'), defaultName: '地址' },
  { type: VaultFieldType.Date, label: $r('app.string.field_type_date'), defaultName: '日期' },
  { type: VaultFieldType.Password, label: $r('app.string.password'), defaultName: '密码' },
]

const CUSTOM_FIELD_PRESET: FieldPreset = {
  type: VaultFieldType.Text,
  label: $r('app.string.field_type_custom'),
  defaultName: '',
}

/**
 * 条目编辑半模态的显示状态：宿主持有实例，只负责置 visible 与 entryUuid，
 * 编辑器加载、保存与关闭流程全部由 EntryEditSheet 内部处理。
 */
@ObservedV2
export class EntryEditSheetState {
  @Trace visible: boolean = false
  @Trace entryUuid: string = ''
}

/**
 * 条目编辑半模态：新建（entryUuid 为空）与编辑共用同一入口。
 * 组件根节点自持 bindSheet，宿主渲染组件并驱动 state 即可。
 */
@ComponentV2
export struct EntryEditSheet {
  @Param state: EntryEditSheetState = new EntryEditSheetState()
  @Local private session: AppSessionState = appSessionState
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private editor: EntryEditorViewModel = new EntryEditorViewModel()
  @Local private unsavedDialogVisible: boolean = false
  private readonly viewModel: AppViewModel = appViewModel
  private readonly sheetMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
  })
  private readonly saveIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.checkmark'))
    .fontColor([$r('sys.color.confirm')])
    .fontSize($r('sys.float.titlebar_icon_width'))
  private readonly cancelIcon: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.xmark'))
    .fontSize($r('sys.float.titlebar_icon_width'))
    .fontColor([$r('sys.color.icon_primary')])

  @Monitor('state.visible')
  onVisibleChanged(): void {
    if (this.state.visible) {
      this.unsavedDialogVisible = false
      this.loadEditor()
      return
    }
    this.releaseEditor()
  }

  @Monitor('session.vaultLocked')
  onVaultLockChanged(): void {
    if (this.session.vaultLocked) {
      this.closeSheet()
    }
  }

  private loadEditor(): void {
    if (this.state.entryUuid.length > 0) {
      this.viewModel.loadEntryForEdit(this.editor, this.state.entryUuid)
      return
    }
    this.viewModel.loadNewEntry(this.editor)
  }

  private releaseEditor(): void {
    this.unsavedDialogVisible = false
    this.editor.reset()
  }

  private closeSheet(): void {
    this.state.visible = false
  }

  private requestExit(): void {
    if (this.viewModel.busy) {
      return
    }
    if (!this.editor.changed()) {
      this.closeSheet()
      return
    }
    this.unsavedDialogVisible = true
  }

  private saveEntry(): void {
    if (this.viewModel.busy) {
      return
    }
    this.viewModel.saveEntry(this.editor).then((saved: boolean) => {
      if (saved) {
        this.closeSheet()
      }
    })
  }

  private onSheetWillDismiss(action: DismissSheetAction): void {
    if (this.viewModel.busy || this.editor.changed()) {
      this.unsavedDialogVisible = true
      return
    }
    action.dismiss()
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

  @Builder
  private avatarBuilder() {
    Stack() {
      Row() {
        Text('GO')
          .fontSize($r('sys.float.Display_S'))
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width($r('app.float.entry_avatar_size'))
      .height($r('app.float.entry_avatar_size'))
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .aspectRatio(1)
      .borderRadius('50%')
      .backgroundColor($r('sys.color.background_emphasize'))
      .border({ width: $r('sys.float.border_medium'), color: $r('sys.color.comp_background_secondary') })

      Button() {
        SymbolGlyph($r('sys.symbol.pencil_line'))
          .fontColor([$r('sys.color.icon_primary')])
          .fontSize($r('sys.float.Body_L'))
      }
      .padding($r('sys.float.padding_level2'))
      .type(ButtonType.Circle)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
      .position({ right: 0, bottom: 0 })
      .shadow(ShadowStyle.OUTER_FLOATING_SM)
    }
  }

  @Builder
  private sheetContent() {
    HdsNavigation() {
      Scroll() {
        Column({ space: $r('sys.float.padding_level6') }) {
          this.avatarBuilder()
        }
        .height('100%')
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .padding({
          top: this.contentTopOffset,
          bottom: this.contentBottomOffset,
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
        })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .onTouch(() => this.viewModel.recordActivity())
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar({
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      content: {
        title: {
          mainTitle: this.state.entryUuid.length === 0
            ? $r('app.string.new_entry') : $r('app.string.edit'),
        },
        menu: {
          value: [{
            content: {
              icon: this.cancelIcon,
              label: $r('app.string.cancel'),
              action: () => this.requestExit(),
            },
          }, {
            content: {
              icon: this.saveIcon,
              label: this.viewModel.busy ? $r('app.string.saving') : $r('app.string.save'),
              action: () => this.saveEntry(),
            },
          }],
        },
      },
    })
  }

  build() {
    Stack()
      .width(0)
      .height(0)
      .bindSheet(this.state.visible, this.sheetContent(), {
        dragBar: true,
        showClose: false,
        backgroundColor: Color.Transparent,
        systemMaterial: this.sheetMaterial,
        onWillDismiss: (action: DismissSheetAction) => this.onSheetWillDismiss(action),
        onDisappear: () => {
          this.state.visible = false
        },
      })
  }
}
