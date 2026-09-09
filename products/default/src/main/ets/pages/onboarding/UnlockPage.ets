import { HdsNavDestination } from '@kit.UIDesignKit'
import { ROUTE_UNLOCK } from '../../constants/RouteConstants'
import { immersiveLayoutState, ImmersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { ColorModeState, colorModeState } from '../../state/ColorModeState'
import { appRouter } from '../../navigation/AppRouter'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { ResUtil } from '@pura/harmony-utils'

const LUNCH_ICON_SIZE = 100

@ComponentV2
export struct UnlockPage {
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private colorMode: ColorModeState = colorModeState
  private readonly viewModel: AppViewModel = appViewModel

  @Computed
  get bottomSafeAreaHeight() {
    return this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx)
  }

  @Computed
  get formPaddingToHeight() {
    const padding = ResUtil.getNumber($r('sys.float.padding_level12').id)
    return this.getUIContext().px2vp(padding + LUNCH_ICON_SIZE / 2)
  }

  build() {
    HdsNavDestination() {
      Stack() {
        Rect()
          .width('100%')
          .height('20%')
          .fill($r('sys.color.background_tertiary'))
          .position({ top: 0, left: 0 })
          .border({
            width: {
              top: 0,
              bottom: $r('sys.float.border_width'),
              left: 0,
              right: 0,
            },
            color: $r('sys.color.comp_divider'),
          })
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.launch_icon'))
            .width(LUNCH_ICON_SIZE * 256 / (256 - 30 * 2))
            .height(LUNCH_ICON_SIZE * 256 / (256 - 30 * 2))
        }
        .width(LUNCH_ICON_SIZE)
        .height(LUNCH_ICON_SIZE)
        .position({ top: '20%', left: '50%' })
        .translate({ x: "-50%", y: "-50%" })
        .zIndex(1)
        .borderRadius('50%')
        .clip(true)
        .shadow(ShadowStyle.OUTER_DEFAULT_XS)

        Rect()
          .width('100%')
          .height('80%')
          .fill(this.colorMode.isDark
            ? $r('sys.color.background_fourth') : $r('sys.color.background_secondary'))
          .position({ bottom: 0, left: 0 })

        Column() {

        }
        .width('100%')
        .height('80%')
        .position({ bottom: 0, left: 0 })
        .padding({ top: this.formPaddingToHeight, bottom: this.bottomSafeAreaHeight })
      }
      .height('100%')
      .width('100%')
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .onBackPressed(() => {
      appRouter.handleRootBack(ROUTE_UNLOCK)
      return true
    })
  }
}

@Builder
export function unlockPageBuilder() {
  UnlockPage()
}
