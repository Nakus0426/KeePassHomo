import { LengthMetrics } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { fileIo } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { FileUtil, LogUtil } from '@pura/harmony-utils'
import { AnimationTokens, DelayedVisibility } from '@ohos/common'
import { DsToastHost } from '../../components/DsToast'
import { DsContextMenu } from '../../components/DsContextMenu'
import { EntryAvatar } from '../../components/EntryAvatar'
import { DsLoadingIndicator, DsLoadingIndicatorSize, DsLoadingIndicatorTone } from '../../components/DsLoadingIndicator'
import { DsMenuGroup } from '../../components/DsMenuGroup'
import { DsMenuItem, DsMenuItemTheme } from '../../components/DsMenuItem'

// 设计稿的紧凑方形头像：48×48，与标题输入井同高。
const AVATAR_SIZE: number = 48
const AVATAR_MAX_EDGE: number = 384
const AVATAR_IMAGE_FORMAT: string = 'image/jpeg'
const AVATAR_QUALITY: number = 85
const AVATAR_BACKGROUND: number = 0xFFFFFF
// 菜单与头像的间距，设计稿里的 8。
const MENU_TARGET_SPACE: number = 8

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

// 选图、沙箱暂存与压缩封在这里；头像面的解码与占位复用 EntryAvatar。
@ComponentV2
export struct EntryAvatarPicker {
  @Param title: string = ''
  @Param avatarData: ArrayBuffer | undefined = undefined
  @Param readOnly: boolean = false
  @Event onPicked: (data: ArrayBuffer) => void = () => {
  }
  @Event onReset: () => void = () => {
  }
  @Local private avatarBusy: boolean = false
  @Local private hovered: boolean = false
  @Local private pressed: boolean = false
  @Local private loadingGate: DelayedVisibility = new DelayedVisibility()

  aboutToDisappear(): void {
    this.loadingGate.dispose()
  }

  @Monitor('avatarBusy')
  onAvatarBusyChanged(): void {
    this.loadingGate.setActive(this.avatarBusy)
  }

  private async pickAvatar(): Promise<void> {
    try {
      const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = 1
      const result: photoAccessHelper.PhotoSelectResult =
        await new photoAccessHelper.PhotoViewPicker().select(options)
      if (result.photoUris.length === 0) {
        return
      }
      // 加载态只覆盖压图与编码，不覆盖用户在系统相册里的选择过程。
      this.avatarBusy = true
      try {
        this.onPicked(await this.compressAvatar(result.photoUris[0]))
      } finally {
        this.avatarBusy = false
      }
    } catch (error) {
      this.reportAvatarError(error)
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

  private reportAvatarError(error: Object): void {
    const businessError: BusinessError = error as BusinessError
    LogUtil.error(`头像处理失败，错误码=${businessError.code}，错误信息=${businessError.message}`)
    DsToastHost.show(this.getUIContext(), $r('app.string.avatar_failed'))
  }

  @LocalBuilder
  private avatarMenuHeader() {
    Column({ space: $r('app.float.ds_space_6') }) {
      Text($r('app.string.avatar_menu_title'))
        .fontSize($r('app.float.ds_font_body'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_primary'))
      Text($r('app.string.avatar_menu_note'))
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontColor($r('app.color.ds_text_secondary'))
    }
    .width('100%')
    .padding({
      top: $r('app.float.ds_space_md'),
      bottom: $r('app.float.ds_space_md'),
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
    })
    .backgroundColor($r('app.color.ds_surface_low'))
    .alignItems(HorizontalAlign.Start)
  }

  // @BuilderParam 传内容必须委托给 @Builder 方法，箭头函数里直接构造组件会报 class constructor 错误。
  @LocalBuilder
  private avatarPickItem() {
    DsMenuItem({
      icon: $r('app.string.symbol_image'),
      label: $r('app.string.avatar_pick'),
      onAction: () => this.pickAvatar(),
    })
  }

  @LocalBuilder
  private avatarResetItem() {
    DsMenuItem({
      icon: $r('app.string.symbol_refresh'),
      label: $r('app.string.avatar_reset'),
      theme: DsMenuItemTheme.Warning,
      onAction: () => this.onReset(),
    })
  }

  @LocalBuilder
  private avatarMenuItems() {
    DsMenuGroup({
      content: this.avatarPickItem,
    })
    // 没有自定义头像时重置没有意义，菜单只保留选择。
    if (this.avatarData !== undefined) {
      DsMenuGroup({
        dividerTop: true,
        content: this.avatarResetItem,
      })
    }
  }

  @LocalBuilder
  private avatarMenu() {
    DsContextMenu({
      header: this.avatarMenuHeader,
      content: this.avatarMenuItems,
    })
  }

  build() {
    Stack() {
      EntryAvatar({
        title: this.title,
        avatarData: this.avatarData,
        avatarSize: AVATAR_SIZE,
        square: true,
        initialsFontSize: $r('app.float.ds_font_avatar_initials'),
        initialsFontWeight: 600,
        onDecodeError: () => DsToastHost.show(this.getUIContext(), $r('app.string.avatar_failed')),
      })

      // 状态层盖在图片之上：hover / press 只叠色，不换底、不位移。
      if (!this.readOnly && !this.avatarBusy) {
        Row()
          .width('100%')
          .height('100%')
          .backgroundColor(this.pressed
            ? $r('app.color.ds_overlay_muted')
            : (this.hovered ? $r('app.color.ds_overlay_subtle') : Color.Transparent))
          .animation(AnimationTokens.FEEDBACK_ANIMATION)
          .hitTestBehavior(HitTestMode.None)
      }

      if (this.loadingGate.visible) {
        Column() {
          DsLoadingIndicator({
            indicatorSize: DsLoadingIndicatorSize.Small,
            tone: DsLoadingIndicatorTone.Scrim,
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.ds_scrim_strong'))
      }
    }
    .width(AVATAR_SIZE)
    .height(AVATAR_SIZE)
    .backgroundColor($r('app.color.ds_surface_high'))
    .borderRadius($r('app.float.ds_radius_none'))
    .clip(true)
    .enabled(!this.avatarBusy && !this.loadingGate.visible && !this.readOnly)
    .accessibilityText($r('app.string.avatar_menu_title'))
    .onHover((isHover: boolean) => {
      this.hovered = isHover
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressed = true
        return
      }
      if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false
      }
    })
    // 系统菜单负责弹出/收起动画与遮罩，内容仍由 DsContextMenu 自绘。
    .bindMenu(this.readOnly ? undefined : this.avatarMenu, {
      placement: Placement.BottomLeft,
      targetSpace: LengthMetrics.vp(MENU_TARGET_SPACE),
      borderRadius: $r('app.float.ds_radius_none'),
      backgroundColor: $r('app.color.ds_surface_lowest'),
      backgroundBlurStyle: BlurStyle.NONE,
      mask: {
        color: $r('app.color.ds_scrim'),
        backgroundBlurStyle: BlurStyle.NONE,
      },
    })
  }
}
