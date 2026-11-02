import { bundleManager } from '@kit.AbilityKit'
import { AnimationTokens } from '@ohos/common'
import {
  DsLoadingIndicator,
  DsLoadingIndicatorSize,
  DsLoadingIndicatorTone,
} from '../../components/DsLoadingIndicator'
import { PASSWORD_FONT_FAMILY } from '../../constants/FontConstants'
import {
  LAUNCH_FOOTER_BOTTOM_VP,
  LAUNCH_FOOTER_GAP_VP,
  LAUNCH_VERSION_LETTER_SPACING,
} from '../../constants/LaunchPageMetrics'
import { appViewModel } from '../../viewmodel/AppViewModel'

@ComponentV2
export struct LaunchPage {
  @Local private versionName: string = ''
  @Local private footerOpacity: number = 0

  aboutToAppear(): void {
    appViewModel.startLaunchDwell()
    this.versionName = bundleManager.getBundleInfoForSelfSync(
      bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT).versionName
    // 系统启动页只有静态锁版，底栏在应用首帧淡入，避免换场时元素硬弹出。
    this.getUIContext().animateTo({
      duration: AnimationTokens.DURATION_LOADING_FADE,
      curve: AnimationTokens.EASE_ENTER,
    }, () => {
      this.footerOpacity = 1
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 与系统启动页共用同一张整屏图与 Cover 规则，两侧锁版逐像素对齐。
      Image($r('app.media.launch_background'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .syncLoad(true)
        .draggable(false)

      Column({ space: LAUNCH_FOOTER_GAP_VP }) {
        DsLoadingIndicator({
          indicatorSize: DsLoadingIndicatorSize.Medium,
          tone: DsLoadingIndicatorTone.Surface,
        })
        Text($r('app.string.launch_version', this.versionName))
          .fontSize($r('app.float.ds_font_micro'))
          .fontFamily(PASSWORD_FONT_FAMILY)
          .letterSpacing(LAUNCH_VERSION_LETTER_SPACING)
          .fontColor($r('app.color.ds_text_tertiary'))
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ bottom: LAUNCH_FOOTER_BOTTOM_VP })
      .opacity(this.footerOpacity)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ds_surface_canvas'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
