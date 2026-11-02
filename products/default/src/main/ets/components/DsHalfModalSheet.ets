import {
  hdsMaterial,
  HdsNavigation,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { DsPageHeader, DsPageHeaderAction, DsPageHeaderSize } from './DsPageHeader'

// 半模态内容壳：只负责悬浮标题栏与滚动穿透；sheet 容器参数与高度仍由宿主 bindSheet 控制。
const SHEET_TITLE_BAR_MASK_EXTRA_HEIGHT_VP: number = 8

@ComponentV2
export struct DsHalfModalSheet {
  @Param title: ResourceStr = ''
  @Param showBack: boolean = false
  @Param actions: DsPageHeaderAction[] = []
  // 内容是否绘制到标题栏下方（沉浸式预览，如密码生成器预览底色上探）。默认内容避让标题栏。
  @Param contentBehindTitleBar: boolean = false
  @Event onBack: () => void = () => {
  }

  // 传 titleBarBuilder 时整条标题栏自定义（如分组选择带搜索栏），忽略 title/showBack/actions。
  @BuilderParam titleBarBuilder?: () => void
  // 内容区由父组件提供，自带 Scroll.clip(false) 以实现滚动穿透。
  @BuilderParam bodyBuilder: () => void = this.emptyBody
  @BuilderParam bottomBarBuilder?: () => void

  @Builder
  private emptyBody() {
  }

  @Builder
  private titleBarContent() {
    if (this.titleBarBuilder !== undefined) {
      this.titleBarBuilder()
    } else {
      DsPageHeader({
        title: this.title,
        headerSize: DsPageHeaderSize.Small,
        showBack: this.showBack,
        actions: this.actions,
        onBack: () => this.onBack(),
      })
    }
  }

  @Computed
  get titleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      enableComponentSafeArea: !this.contentBehindTitleBar,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: false,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
        },
        originalStyle: {
          backgroundStyle: {
            maskExtraHeight: SHEET_TITLE_BAR_MASK_EXTRA_HEIGHT_VP,
          },
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE,
        },
      },
      content: {
        title: { mainTitle: '' },
        stackBuilder: (): void => {
          this.titleBarContent()
        },
      },
    }
  }

  build() {
    HdsNavigation() {
      Stack({ alignContent: Alignment.Bottom }) {
        this.bodyBuilder()
        if (this.bottomBarBuilder !== undefined) {
          this.bottomBarBuilder()
        }
      }
      .width('100%')
      .height('100%')
    }
    .titleMode(HdsNavigationTitleMode.MODAL)
    .titleBar(this.titleBarOptions)
  }
}
