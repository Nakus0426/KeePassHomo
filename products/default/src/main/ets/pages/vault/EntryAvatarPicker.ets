import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { FileUtil, LogUtil } from '@pura/harmony-utils'
import { DsToastHost } from '../../components/DsToast'
import { DsContextMenu } from '../../components/DsContextMenu'
import { DsMenuItem, DsMenuItemTheme } from '../../components/DsMenuItem'

// 设计稿的紧凑方形头像：48×48，与标题输入井同高。
const AVATAR_SIZE: number = 48
const AVATAR_MAX_EDGE: number = 384
const AVATAR_IMAGE_FORMAT: string = 'image/jpeg'
const AVATAR_QUALITY: number = 85
const AVATAR_BACKGROUND: number = 0xFFFFFF

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

// 选图、沙箱暂存、压缩与预览解码都封在这里，宿主只负责把结果接进编辑器。
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

  // createImageSource 只接受应用沙箱路径，传媒体库 uri 会静默返回 undefined，故先按 fd 复制到 cacheDir。
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
      FileUtil.unlinkSync(path)
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
    DsToastHost.show(this.getUIContext(), $r('app.string.avatar_failed'))
  }

  // @BuilderParam 传内容必须委托给 @Builder 方法，箭头函数里直接构造组件会报 class constructor 错误。
  @LocalBuilder
  private avatarMenuItems() {
    DsMenuItem({
      icon: $r('app.string.symbol_image'),
      label: $r('app.string.avatar_pick'),
      onAction: () => {
        this.pickAvatar()
      },
    })
    DsMenuItem({
      icon: $r('app.string.symbol_refresh'),
      label: $r('app.string.avatar_reset'),
      theme: DsMenuItemTheme.Warning,
      onAction: () => this.onReset(),
    })
  }

  @LocalBuilder
  private avatarMenu() {
    DsContextMenu({
      content: this.avatarMenuItems,
    })
  }

  build() {
    Stack() {
      if (this.avatarPixelMap !== undefined) {
        Image(this.avatarPixelMap)
          .draggable(false)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Text(this.initials)
          .fontSize($r('app.float.ds_font_title_md'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_text_primary'))
      }

      if (this.avatarBusy) {
        LoadingProgress()
          .width($r('app.float.ds_icon_md'))
          .height($r('app.float.ds_icon_md'))
          .color($r('app.color.ds_text_secondary'))
      }
    }
    .width(AVATAR_SIZE)
    .height(AVATAR_SIZE)
    .backgroundColor($r('app.color.ds_surface_high'))
    .borderRadius($r('app.float.ds_radius_none'))
    .clip(true)
    .enabled(!this.avatarBusy && !this.readOnly)
    .bindMenu(this.avatarMenu())
  }
}
