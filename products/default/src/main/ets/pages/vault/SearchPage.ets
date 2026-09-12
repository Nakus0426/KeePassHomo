import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit'
import { uiMaterial } from '@kit.ArkUI'
import { ResUtil } from '@pura/harmony-utils'
import { ROUTE_SEARCH } from '../../constants/RouteConstants'
import { registerFadeDestination, unregisterFadeDestination } from '../../navigation/NavFadeTransition'

@ComponentV2
export struct SearchPage {
  @Local private pageOpacity: number = 1

  aboutToAppear(): void {
    registerFadeDestination(ROUTE_SEARCH, {
      onFadeStart: (isEnter: boolean) => {
        this.pageOpacity = isEnter ? 0 : 1
      },
      onFadeFinish: (isEnter: boolean) => {
        this.pageOpacity = isEnter ? 1 : 0
      },
    })
  }

  aboutToDisappear(): void {
    unregisterFadeDestination(ROUTE_SEARCH)
  }

  @Computed
  private get searchPaddingLeft() {
    const backButtonMarginLeftPx = ResUtil.getNumber($r('sys.float.titlebar_backbutton_margin_left').id)
    const backButtonWidthPx = ResUtil.getNumber($r('sys.float.titlebar_icon_background_width').id)
    const paddingLeftPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
    return this.getUIContext().px2vp(backButtonMarginLeftPx + backButtonWidthPx + paddingLeftPx)
  }

  @Builder
  private searchBuilder() {
    Row() {
      Search({ placeholder: $r('app.string.search_vault') })
        .height($r('sys.float.titlebar_icon_background_width'))
        .searchButton($r('app.string.search'))
        .systemMaterial(
          new uiMaterial.ImmersiveMaterial({ style: uiMaterial.ImmersiveStyle.ULTRA_THIN, interactive: true }))
    }
    .width('100%')
    .padding({
      left: this.searchPaddingLeft,
      right: $r('sys.float.padding_level8'),
    })
  }

  build() {
    HdsNavDestination() {
      Scroll() {
        Column() {
        }
        .width('100%')
        .padding({
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
          bottom: $r('sys.float.padding_level12'),
        })
      }
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring)
      .clip(false)
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
        },
      },
      content: {
        backIcon: {},
        stackBuilder: () => this.searchBuilder(),
      },
    })
    .opacity(this.pageOpacity)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}

@Builder
export function searchPageBuilder() {
  SearchPage()
}
