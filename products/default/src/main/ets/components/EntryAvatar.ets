import { BusinessError } from '@kit.BasicServicesKit'
import { image } from '@kit.ImageKit'
import { LogUtil } from '@pura/harmony-utils'

const EMPTY_TITLE_PLACEHOLDER: string = '?'

// 图标字节由宿主读取后传入（StageOneVaultStore.loadEntryAvatar）
@ComponentV2
export struct EntryAvatar {
  @Param title: string = ''
  @Param avatarData: ArrayBuffer | undefined = undefined
  @Param avatarSize: Length = $r('app.float.entry_card_avatar_size')
  @Param initialsFontSize: Length = $r('sys.float.Body_L')
  @Local private avatarPixelMap: image.PixelMap | undefined = undefined
  // 已解码的来源字节：列表节点换条目复用时据此判断旧图需先清空
  private decodedSource: ArrayBuffer | undefined = undefined

  aboutToAppear(): void {
    this.refreshPreview()
  }

  @Monitor('avatarData')
  onAvatarDataChanged(): void {
    this.refreshPreview()
  }

  @Computed
  private get initials(): string {
    const title: string = this.title.trim()
    return title.length === 0 ? EMPTY_TITLE_PLACEHOLDER : title.slice(0, 2).toUpperCase()
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
    }
  }

  build() {
    Stack() {
      if (this.avatarPixelMap !== undefined) {
        Image(this.avatarPixelMap)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Text(this.initials)
          .fontSize(this.initialsFontSize)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
    .aspectRatio(1)
    .borderRadius('50%')
    .backgroundColor($r('sys.color.background_emphasize'))
    .border({ width: $r('sys.float.border_medium'), color: $r('sys.color.comp_background_secondary') })
    .clip(true)
  }
}
