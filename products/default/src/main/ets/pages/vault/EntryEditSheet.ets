import { LengthMetrics, SymbolGlyphModifier, uiMaterial } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { hdsMaterial, HdsNavigation, HdsNavigationTitleMode, ScrollEffectType } from '@kit.UIDesignKit'
import { VaultFieldType } from '@ohos/common'
import { FileUtil, LogUtil, ResUtil } from '@pura/harmony-utils'
import { AppSessionState, appSessionState } from '../../state/AppSessionState'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { EntryEditorViewModel } from '../../viewmodel/EntryEditorViewModel'

const DATE_PATTERN: string = 'yyyy-MM-dd'
/** 头像最长边（px）。100vp 显示尺寸在 3.33x 屏约 333px，384 留出余量。 */
const AVATAR_MAX_EDGE: number = 384
const AVATAR_IMAGE_FORMAT: string = 'image/jpeg'
const AVATAR_QUALITY: number = 85
/** JPEG 没有透明通道，透明区域编码时填充为该颜色（0xRRGGBB）。 */
const AVATAR_BACKGROUND: number = 0xFFFFFF

/** 按最长边等比算出解码尺寸；原图不超过上限时不放大，结果保证为正整数。 */
function avatarDecodeSize(size: image.Size): image.Size {
  const longest: number = Math.max(size.width, size.height)
  if (longest <= AVATAR_MAX_EDGE) {
    return { width: size.width, height: size.height }
  }
  const ratio: number = AVATAR_MAX_EDGE / longest
  return {
    width: Math.max(1, Math.round(size.width * ratio)),
    height: Math.max(1, Math.round(size.height * ratio)),
  }
}

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
  @Local private avatarPixelMap: image.PixelMap | undefined = undefined
  @Local private avatarBusy: boolean = false
  private readonly viewModel: AppViewModel = appViewModel
  private readonly sheetMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
  })
  private readonly toastMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
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
    } else {
      this.viewModel.loadNewEntry(this.editor)
    }
    this.refreshAvatarPreview()
  }

  private releaseEditor(): void {
    this.unsavedDialogVisible = false
    this.avatarBusy = false
    this.avatarPixelMap = undefined
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

  /** 默认头像取标题前两个字符，空标题回退为问号。 */
  @Computed
  get avatarInitials(): string {
    const title: string = this.editor.title.trim()
    if (title.length === 0) {
      return '?'
    }
    return title.slice(0, 2).toUpperCase()
  }

  @Computed
  get hasAvatar(): boolean {
    return this.editor.avatarData !== undefined
  }

  private get readOnly(): boolean {
    return this.viewModel.currentSource().readOnly
  }

  private async pickAvatar(): Promise<void> {
    this.avatarBusy = true
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = 1
      const result: photoAccessHelper.PhotoSelectResult =
        await new photoAccessHelper.PhotoViewPicker().select(options)
      if (result.photoUris.length === 0) {
        return
      }
      const data: ArrayBuffer = await this.compressAvatar(result.photoUris[0])
      if (!this.state.visible) {
        return
      }
      this.editor.setAvatar(data)
      await this.refreshAvatarPreview()
    } catch (error) {
      this.reportAvatarError(error)
    } finally {
      this.avatarBusy = false
    }
  }

  /**
   * 相册返回的是媒体库 uri，而 createImageSource 只接受应用沙箱路径
   */
  private copyImageToSandbox(uri: string): string {
    const context: common.UIAbilityContext =
      this.getUIContext().getHostContext() as common.UIAbilityContext
    const name: string = FileUtil.getFileName(uri)
    const dot: number = name.lastIndexOf('.')
    const suffix: string = dot >= 0 ? name.slice(dot) : ''
    const path: string = `${context.cacheDir}/avatar_${Date.now()}${suffix}`
    const file: fileIo.File = FileUtil.openSync(uri, fileIo.OpenMode.READ_ONLY)
    try {
      FileUtil.copyFileSync(file.fd, path)
    } finally {
      FileUtil.closeSync(file)
    }
    return path
  }

  /**
   * 先用 desiredSize 在解码阶段缩到最长边 384，再质量压缩为 JPEG。
   */
  private async compressAvatar(uri: string): Promise<ArrayBuffer> {
    const path: string = this.copyImageToSandbox(uri)
    try {
      const source: image.ImageSource = image.createImageSource(path)
      const info: image.ImageInfo = await source.getImageInfo()
      const pixelMap: image.PixelMap = await source.createPixelMap({
        desiredSize: avatarDecodeSize(info.size),
      })
      return image.createImagePacker().packToData(pixelMap, {
        format: AVATAR_IMAGE_FORMAT,
        quality: AVATAR_QUALITY,
        backgroundColor: AVATAR_BACKGROUND,
      })
    } finally {
      await FileUtil.unlink(path)
    }
  }

  private resetAvatar(): void {
    this.editor.clearAvatar()
    this.refreshAvatarPreview()
  }

  private async refreshAvatarPreview(): Promise<void> {
    const data: ArrayBuffer | undefined = this.editor.avatarData
    if (data === undefined) {
      this.avatarPixelMap = undefined
      return
    }
    try {
      const pixelMap: image.PixelMap = await image.createImageSource(data).createPixelMap()
      // 解码期间头像可能已被替换，只有来源仍是同一份字节才应用结果。
      if (this.editor.avatarData === data) {
        this.avatarPixelMap = pixelMap
      }
    } catch (error) {
      this.reportAvatarError(error)
    }
  }

  private reportAvatarError(error: Object): void {
    const businessError: BusinessError = error as BusinessError
    LogUtil.error(`头像处理失败，错误码=${businessError.code}，错误信息=${businessError.message}`)
    this.showToast($r('app.string.avatar_failed'))
  }

  private showToast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message,
        systemMaterial: this.toastMaterial,
      })
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      LogUtil.error(`显示头像提示失败，错误码=${businessError.code}，错误信息=${businessError.message}`)
    }
  }

  @Builder
  private avatarMenuBuilder() {
    Menu() {
      MenuItem({
        content: $r('app.string.avatar_pick'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.picture')),
      })
        .enabled(!this.avatarBusy)
        .onClick(() => {
          this.pickAvatar()
        })
      MenuItem({
        content: $r('app.string.avatar_reset'),
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_clockwise'))
          .fontColor([$r('sys.color.warning')]),
      })
        .contentFontColor($r('sys.color.warning'))
        .enabled(!this.avatarBusy && this.hasAvatar)
        .onClick(() => {
          this.resetAvatar()
        })
    }
    .menuItemDivider({
      strokeWidth: LengthMetrics.resource($r('sys.float.alert_divider_width')),
      color: $r('sys.color.grid_menu_divider_color'),
      startMargin: LengthMetrics.resource($r('sys.float.menu_divider_start_margin')),
      endMargin: LengthMetrics.resource($r('sys.float.menu_divider_end_margin')),
    })
  }

  @Builder
  private avatarBuilder() {
    Stack() {
      Stack() {
        if (this.avatarPixelMap !== undefined) {
          Image(this.avatarPixelMap)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
        } else {
          Text(this.avatarInitials)
            .fontSize($r('sys.float.Display_S'))
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
      }
      .width('100%')
      .height('100%')
      .borderRadius('50%')
      .backgroundColor($r('sys.color.background_emphasize'))
      .border({ width: $r('sys.float.border_medium'), color: $r('sys.color.comp_background_secondary') })
      .clip(true)

      Button() {
        if (this.avatarBusy) {
          LoadingProgress()
            .width($r('sys.float.Body_L'))
            .height($r('sys.float.Body_L'))
            .color($r('sys.color.icon_primary'))
        } else {
          SymbolGlyph($r('sys.symbol.square_and_pencil'))
            .fontColor([$r('sys.color.icon_primary')])
            .fontSize($r('sys.float.Body_L'))
        }
      }
      .padding($r('sys.float.padding_level2'))
      .type(ButtonType.Circle)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: $r('sys.float.border_width'), color: $r('sys.color.comp_background_secondary') })
      .position({ right: 0, bottom: 0 })
      .shadow(ShadowStyle.OUTER_FLOATING_SM)
      .enabled(!this.avatarBusy && !this.readOnly)
      .zIndex(1)
      .bindMenu(this.avatarMenuBuilder())
    }
    .width($r('app.float.entry_avatar_size'))
    .height($r('app.float.entry_avatar_size'))
    .aspectRatio(1)
    .borderRadius('50%')
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
