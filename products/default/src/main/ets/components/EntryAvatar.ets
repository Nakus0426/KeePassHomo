import { BusinessError } from '@kit.BasicServicesKit'
import { image } from '@kit.ImageKit'
import { AnimationTokens } from '@ohos/common'
import { LogUtil } from '@pura/harmony-utils'

const EMPTY_TITLE_PLACEHOLDER: string = '?'

// 图标字节由宿主读取后传入（StageOneVaultStore.loadEntryAvatar）
@ComponentV2
export struct EntryAvatar {
  @Param title: string = ''
  @Param avatarData: ArrayBuffer | undefined = undefined
  @Param avatarSize: Length = $r('app.float.entry_card_avatar_size')
  @Param initialsFontSize: Length = $r('sys.float.Body_L')
  @Param initialsFontWeight: FontWeight | number = FontWeight.Bold
  @Param entranceScale: number = 1
  // 方形瓦片供密集列表使用，圆角为 0。
  @Param square: boolean = false
  // 列表里静默退回首字；编辑态需要额外提示时由宿主接。
  @Event onDecodeError: () => void = () => {
  }
  @Local private avatarPixelMap: image.PixelMap | undefined = undefined
  @Local private avatarScale: number = 1
  // 已解码的来源字节：列表节点换条目复用时据此判断旧图需先清空
  private decodedSource: ArrayBuffer | undefined = undefined

  aboutToAppear(): void {
    this.avatarScale = this.entranceScale
    this.refreshPreview()
  }

  @Monitor('avatarData')
  onAvatarDataChanged(): void {
    this.refreshPreview()
  }

  @Computed
  private get initials(): string {
    const title: string = this.title.trim()
    if (title.length === 0) {
      return EMPTY_TITLE_PLACEHOLDER
    }
    const wordBoundary: RegExpMatchArray | null = title.match(/^[A-Z][a-z]+([A-Z])/)
    return wordBoundary === null ? Array.from(title).slice(0, 2).join('').toUpperCase() : title[0] + wordBoundary[1]
  }

  private async refreshPreview(): Promise<void> {
    const data: ArrayBuffer | undefined = this.avatarData
    if (data === this.decodedSource) {
      return
    }
    // 来源变化先解绑旧图，避免复用节点残留上一条目头像
    this.decodedSource = data
    this.avatarPixelMap = undefined
    if (data === undefined) {
      return
    }
    try {
      const pixelMap: image.PixelMap = await image.createImageSource(data).createPixelMap()
      // 解码期间头像可能已被替换，只有来源仍是同一份字节才应用结果。
      if (this.avatarData === data) {
        this.avatarPixelMap = pixelMap
      }
    } catch (error) {
      // 条目卡片成列出现，逐行弹提示会盖住内容；解码失败退回头像字母态并记录上下文。
      const businessError: BusinessError = error as BusinessError
      LogUtil.error(`头像解码失败，错误码=${businessError.code}，错误信息=${businessError.message}`)
      this.onDecodeError()
    }
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
          .fontSize(this.initialsFontSize)
          .fontWeight(this.initialsFontWeight)
          .fontColor(this.square ? $r('app.color.ds_text_secondary') : Color.White)
      }
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
    .aspectRatio(1)
    .borderRadius(this.square ? $r('app.float.ds_radius_none') : '50%')
    .backgroundColor(this.square ? $r('app.color.ds_surface_high') : $r('sys.color.background_emphasize'))
    .clip(true)
    .scale({ x: this.avatarScale, y: this.avatarScale })
    .onAppear(() => {
      if (this.avatarScale < 1) {
        this.getUIContext().animateTo(AnimationTokens.FEEDBACK_ANIMATION, () => this.avatarScale = 1)
      }
    })
  }
}
