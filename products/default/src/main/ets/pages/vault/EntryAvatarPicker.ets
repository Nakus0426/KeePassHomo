import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { AppToast } from '@ohos/common'
import { FileUtil, LogUtil } from '@pura/harmony-utils'

const AVATAR_MAX_EDGE: number = 384
const AVATAR_IMAGE_FORMAT: string = 'image/jpeg'
const AVATAR_QUALITY: number = 85
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
 * 条目头像：没有自定义图片时显示标题前两个字符，右下角按钮弹出切换菜单。
 * 选图、沙箱暂存、压缩与预览解码都封在这里，宿主只负责把结果接进编辑器。
 */
@ComponentV2
export struct EntryAvatarPicker {
  @Param title: string = ''
  @Param avatarData: ArrayBuffer | undefined = undefined
  @Param readOnly: boolean = false
  @Event onPicked: (data: ArrayBuffer) => void = () => {
  }
  @Event onReset: () => void = () => {
  }
  @Local private avatarPixelMap: image.PixelMap | undefined = undefined
  @Local private avatarBusy: boolean = false

  aboutToAppear(): void {
    this.refreshPreview()
  }

  @Monitor('avatarData')
  onAvatarDataChanged(): void {
    this.refreshPreview()
  }

  /** 默认头像取标题前两个字符，空标题回退为问号。 */
  @Computed
  get initials(): string {
    const title: string = this.title.trim()
    if (title.length === 0) {
      return '?'
    }
    return title.slice(0, 2).toUpperCase()
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
      this.onPicked(await this.compressAvatar(result.photoUris[0]))
    } catch (error) {
      this.reportAvatarError(error)
    } finally {
      this.avatarBusy = false
    }
  }

  /**
   * 相册返回的是媒体库 uri，而 createImageSource 只接受应用沙箱路径，
   * 传 uri 会静默返回 undefined，所以先按 fd 复制进 cacheDir 再解码。
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

  /** 先用 desiredSize 在解码阶段缩到最长边 384，再质量压缩为 JPEG。 */
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

  private async refreshPreview(): Promise<void> {
    const data: ArrayBuffer | undefined = this.avatarData
    if (data === undefined) {
      this.avatarPixelMap = undefined
      return
    }
    try {
      const pixelMap: image.PixelMap = await image.createImageSource(data).createPixelMap()
      // 解码期间头像可能已被替换，只有来源仍是同一份字节才应用结果。
      if (this.avatarData === data) {
        this.avatarPixelMap = pixelMap
      }
    } catch (error) {
      this.reportAvatarError(error)
    }
  }

  private reportAvatarError(error: Object): void {
    const businessError: BusinessError = error as BusinessError
    LogUtil.error(`头像处理失败，错误码=${businessError.code}，错误信息=${businessError.message}`)
    AppToast.show(this.getUIContext(), $r('app.string.avatar_failed'))
  }

  @Builder
  private avatarMenu() {
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
        symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_counterclockwise'))
          .fontColor([$r('sys.color.warning')]),
      })
        .contentFontColor($r('sys.color.warning'))
        .enabled(!this.avatarBusy && this.avatarData !== undefined)
        .onClick(() => {
          this.onReset()
        })
    }
    .menuItemDivider({
      strokeWidth: LengthMetrics.resource($r('sys.float.alert_divider_width')),
      color: $r('sys.color.grid_menu_divider_color'),
      startMargin: LengthMetrics.resource($r('sys.float.menu_divider_start_margin')),
      endMargin: LengthMetrics.resource($r('sys.float.menu_divider_end_margin')),
    })
  }

  build() {
    Stack() {
      Stack() {
        if (this.avatarPixelMap !== undefined) {
          Image(this.avatarPixelMap)
            .width('100%')
            .height('100%')
            .objectFit(ImageFit.Cover)
        } else {
          Text(this.initials)
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
      .bindMenu(this.avatarMenu())
    }
    .width($r('app.float.entry_avatar_size'))
    .height($r('app.float.entry_avatar_size'))
    .aspectRatio(1)
    .borderRadius('50%')
  }
}
