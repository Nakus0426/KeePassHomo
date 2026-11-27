import {
  BottomBuilderParams,
  hdsMaterial,
  HdsNavigation,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { DsPageHeader, DsPageHeaderAction, DsPageHeaderSize } from './DsPageHeader'

// 半模态内容壳：只负责拖拽条、悬浮标题栏与滚动穿透；sheet 容器参数与高度仍由宿主 bindSheet 控制。
const SHEET_TITLE_BAR_MASK_EXTRA_HEIGHT_VP: number = 8
// 拖拽条几何取自 pen 的 Handle Row：36×2，位于 16 高行内。
const HANDLE_WIDTH_VP: number = 36
const HANDLE_HEIGHT_VP: number = 2

@ComponentV2
export struct DsHalfModalSheet {
  @Param title: ResourceStr = ''
  @Param showBack: boolean = false
  // 关闭按钮由壳统一绘制在动作区最右；提交中置 false 锁住退出。
  @Param showClose: boolean = true
  @Param closeEnabled: boolean = true
  // 高度固定、不可拖拽的面板不画拖拽条，避免暗示可以调整高度。
  @Param showHandle: boolean = true
  @Param actions: DsPageHeaderAction[] = []
  // 内容是否绘制到标题栏下方（沉浸式预览，如密码生成器预览底色上探）。默认内容避让标题栏。
  @Param contentBehindTitleBar: boolean = false
  @Event onBack: () => void = () => {
  }
  @Event onClose: () => void = () => {
  }

  // 传 titleBarBuilder 时整条标题栏自定义（如分组选择带搜索栏），忽略 title/showBack/actions。
  @BuilderParam titleBarBuilder?: () => void
  // 标题栏底部扩展区（标题栏之下、随材质一起悬浮），由 HDS 计入标题栏高度。
  @BuilderParam titleBarBottomBuilder?: () => void
  @Param titleBarBottomHeight: Length | undefined = undefined
  // 绑定内容滚动容器后标题栏启用渐变模糊，内容可从其下方穿过。
  @Param scrollableScroller: Scroller | undefined = undefined
  // 内容区由父组件提供，自带 Scroll.clip(false) 以实现滚动穿透。
  @BuilderParam bodyBuilder: () => void = this.emptyBody
  @BuilderParam bottomBarBuilder?: () => void

  @Builder
  private emptyBody() {
  }

  @Builder
  private titleBarContent() {
    Column() {
      // 拖拽条放在标题栏内部，与标题栏共用同一层渐变模糊材质；沉浸式预览不带拖拽条。
      if (this.showHandle && !this.contentBehindTitleBar) {
        this.dragHandle()
      }

      if (this.titleBarBuilder !== undefined) {
        this.titleBarBuilder()
      } else {
        DsPageHeader({
          title: this.title,
          headerSize: DsPageHeaderSize.Small,
          showBack: this.showBack,
          showClose: this.showClose,
          closeEnabled: this.closeEnabled,
          actions: this.actions,
          onBack: () => this.onBack(),
          onClose: () => this.onClose(),
        })
      }
    }
    .width('100%')
  }

  @Builder
  private dragHandle() {
    Row() {
      Row()
        .width(HANDLE_WIDTH_VP)
        .height(HANDLE_HEIGHT_VP)
        .backgroundColor($r('app.color.ds_outline_variant'))
    }
    .width('100%')
    .height($r('app.float.ds_space_16'))
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }

  @Computed
  get titleBarBottom(): BottomBuilderParams | undefined {
    if (this.titleBarBottomBuilder === undefined) {
      return undefined
    }
    return {
      builder: (): void => {
        this.titleBarBottomBuilder!()
      },
      height: this.titleBarBottomHeight,
    }
  }

  @Computed
  get titleBarOptions(): HdsNavigationTitleBarOptions {
    return {
      enableComponentSafeArea: !this.contentBehindTitleBar,
      style: {
        scrollEffectOpts: {
          // false 会让 GRADIENT_BLUR 直接静态生效；保持开启后，未绑定滚动容器的面板停在 originalStyle，没有模糊带。
          enableScrollEffect: true,
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
        bottomBuilder: this.titleBarBottom,
      },
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 底栏挂在导航内容区之外：HdsNavigation 会自行避让键盘并上移内容区，挂在里面会被带着浮到面板中间。
      HdsNavigation() {
        this.bodyBuilder()
      }
      .width('100%')
      .height('100%')
      .titleMode(HdsNavigationTitleMode.MODAL)
      .titleBar(this.titleBarOptions)
      .bindToScrollable(this.scrollableScroller === undefined ? [] : [this.scrollableScroller])

      if (this.bottomBarBuilder !== undefined) {
        this.bottomBarBuilder()
      }
    }
    .width('100%')
    .height('100%')
  }
}
