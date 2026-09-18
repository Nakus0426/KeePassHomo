import { BusinessError } from '@kit.BasicServicesKit'
import { image } from '@kit.ImageKit'
import { LogUtil } from '@pura/harmony-utils'

const EMPTY_TITLE_PLACEHOLDER: string = '?'

/**
 * 条目头像展示：绑定了自定义图片时显示图片，否则显示标题前两个字符。
 * 图标字节由宿主读取后传入（StageOneVaultStore.loadEntryAvatar），组件只负责展示。
 */
@ComponentV2
export struct EntryAvatar {
  @Param title: string = ''
  @Param avatarData: ArrayBuffer | undefined = undefined
  @Param avatarSize: Length = $r('app.float.entry_card_avatar_size')
  @Local private avatarPixelMap: image.PixelMap | undefined = undefined
  /** 已解码的来源字节：列表节点换条目复用时，据此判断旧图必须先清空。 */
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
    // 来源变化先把旧图解绑：复用节点上残留的上一条目头像比空头像更糟。
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
          .fontSize($r('sys.float.Body_L'))
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
