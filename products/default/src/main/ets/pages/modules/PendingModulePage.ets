import { HdsNavDestination } from '@kit.UIDesignKit'
import { PageTopBar } from '../../components/PageChrome'

@ComponentV2
export struct PendingModulePage {
  @Param title: Resource = $r('app.string.app_title')
  @Param route: string = ''
  @Event onLock: () => void = () => {
  }
  @Event onActivity: () => void = () => {
  }
  @Event onShown: (route: string) => void = () => {
  }
  @Event onRootBack: () => void = () => {
  }

  build() {
    HdsNavDestination() {
      Column({ space: 16 }) {
        PageTopBar({
          title: this.title,
          showLock: true,
          onLock: () => this.onLock(),
        })
        Column({ space: 8 }) {
          Text($r('app.string.module_pending'))
            .fontSize($r('sys.float.Body_L'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding({
        top: $r('sys.float.padding_level12'),
        right: $r('sys.float.padding_level12'),
        bottom: $r('app.float.module_content_bottom_padding'),
        left: $r('sys.float.padding_level12'),
      })
      .onTouch(() => this.onActivity())
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .onShown(() => this.onShown(this.route))
    .onBackPressed(() => {
      this.onRootBack()
      return true
    })
  }
}
