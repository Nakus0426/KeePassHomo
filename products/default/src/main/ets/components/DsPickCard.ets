import { AnimationTokens } from '@ohos/common'

// 选择卡容器：图标 + 标题的网格卡共用悬停/按下面底，内容由调用方给。
@ComponentV2
export struct DsPickCard {
  @Event onPick: () => void = () => {
  }
  @BuilderParam contentBuilder?: () => void

  @Local private hovered: boolean = false
  @Local private pressed: boolean = false

  private cardColor(): ResourceColor {
    if (this.pressed) {
      return $r('app.color.ds_surface_highest')
    }
    return this.hovered ? $r('app.color.ds_surface_high') : $r('app.color.ds_surface_low')
  }

  build() {
    Column({ space: $r('app.float.ds_space_sm') }) {
      if (this.contentBuilder !== undefined) {
        this.contentBuilder()
      }
    }
    .width('100%')
    .padding($r('app.float.ds_space_md'))
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(this.cardColor())
    .borderRadius($r('app.float.ds_radius_none'))
    .animation(AnimationTokens.FEEDBACK_ANIMATION)
    .onHover((isHover: boolean) => {
      this.hovered = isHover
    })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressed = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false
      }
    })
    .onClick(() => this.onPick())
  }
}
