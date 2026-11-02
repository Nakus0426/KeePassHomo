import { hdsMaterial, HdsNavigationTitleBarOptions, ScrollEffectType } from '@kit.UIDesignKit'

const DS_PAGE_CONTENT_TOP_GAP_VP: number = 20
// mask 额外高度与首屏内容间距一致，避免材质盖住首屏内容。
const DS_PAGE_TITLE_BAR_MASK_EXTRA_HEIGHT_VP: number = DS_PAGE_CONTENT_TOP_GAP_VP

function pageTitleBarOptions(stackBuilder: CustomBuilder | undefined,
  bottomBuilder: CustomBuilder | undefined, componentSafeArea: boolean): HdsNavigationTitleBarOptions {
  return {
    avoidLayoutSafeArea: true,
    enableComponentSafeArea: componentSafeArea,
    style: {
      scrollEffectOpts: {
        enableScrollEffect: true,
        scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
      },
      originalStyle: {
        backgroundStyle: {
          maskExtraHeight: DS_PAGE_TITLE_BAR_MASK_EXTRA_HEIGHT_VP,
        },
      },
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
      },
    },
    content: {
      title: {
        mainTitle: '',
      },
      stackBuilder: stackBuilder,
      bottomBuilder: bottomBuilder === undefined ? undefined : { builder: bottomBuilder },
    },
  }
}

export function dsPageTitleBarOptions(stackBuilder?: CustomBuilder): HdsNavigationTitleBarOptions {
  return pageTitleBarOptions(stackBuilder, undefined, false)
}

// HdsNavDestination 子页：标题栏作为组件级安全区，内容区自动避让；滚动容器配 clip(false) 可继续穿入标题栏。
// bottomBuilder 由 HDS 计入标题栏高度并覆盖材质，适合放步骤条一类的底部行。
export function dsNavPageTitleBarOptions(stackBuilder?: CustomBuilder,
  bottomBuilder?: CustomBuilder): HdsNavigationTitleBarOptions {
  return pageTitleBarOptions(stackBuilder, bottomBuilder, true)
}
