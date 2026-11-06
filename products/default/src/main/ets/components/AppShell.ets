import { UIObserver } from '@kit.ArkUI'
import { AnimationTokens } from '@ohos/common'
import {
  CustomTransitionDelegate,
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
} from '@kit.UIDesignKit'
import { ROUTE_GENERATOR, ROUTE_SECURITY, ROUTE_SETTINGS, ROUTE_VAULT } from '../constants/RouteConstants'
import { TAB_BAR_GRADIENT_HEIGHT_VP } from '../constants/TabBarMetrics'
import { appSessionState, AppSessionState } from '../state/AppSessionState'
import { appRouter } from '../navigation/AppRouter'
import { fadeNavTransition } from '../navigation/NavFadeTransition'
import { appViewModel } from '../viewmodel/AppViewModel'
import { VaultHomePage } from '../pages/vault/VaultHomePage'
import { DsPageHeader, DsPageHeaderAction } from './DsPageHeader'
import { dsPageTitleBarOptions } from './DsPageTitleBar'
import { DsBottomTabBar, DsBottomTabBarItem } from './DsBottomTabBar'
import { ModulePendingContent } from '../pages/modules/ModulePendingContent'
import { GeneratorPage } from '../pages/generator/GeneratorPage'
import { VaultHomeViewModel, vaultHomeViewModel } from '../viewmodel/VaultHomeViewModel'

// 数组顺序即页签顺序。选中态由 HdsTabs 的自定义页签 Builder 给出。
interface ModuleTabDescriptor {
  route: string
  label: Resource
  icon: Resource
}

const MODULES: ModuleTabDescriptor[] = [
  {
    route: ROUTE_VAULT,
    label: $r('app.string.vault_home'),
    icon: $r('app.string.symbol_key'),
  },
  {
    route: ROUTE_SECURITY,
    label: $r('app.string.security_center'),
    icon: $r('app.string.symbol_verified_user'),
  },
  {
    route: ROUTE_GENERATOR,
    label: $r('app.string.password_generator'),
    icon: $r('app.string.symbol_bolt'),
  },
  {
    route: ROUTE_SETTINGS,
    label: $r('app.string.settings'),
    icon: $r('app.string.symbol_settings'),
  },
]

@ComponentV2
export struct AppShell {
  @Local private session: AppSessionState = appSessionState
  @Local private home: VaultHomeViewModel = vaultHomeViewModel
  private readonly tabsController: HdsTabsController = new HdsTabsController()
  private uiObserver: UIObserver | undefined = undefined

  aboutToAppear(): void {
    this.uiObserver = this.getUIContext().getUIObserver()
    appRouter.attach(this.uiObserver)
  }

  aboutToDisappear(): void {
    if (this.uiObserver !== undefined) {
      appRouter.detach(this.uiObserver)
      this.uiObserver = undefined
    }
  }

  @Monitor('session.vaultLocked')
  onVaultLockChanged(_monitor: IMonitor): void {
    appViewModel.onVaultLockChanged()
  }

  @Monitor('session.sensitiveEpoch')
  onSensitiveEpochChanged(_monitor: IMonitor): void {
    appViewModel.onSensitiveEpochChanged()
  }

  @Monitor('session.foregroundEpoch')
  onForegroundEpochChanged(_monitor: IMonitor): void {
    appViewModel.onForegroundEpochChanged()
  }

  // AppViewModel 在创建/解锁时会直接改 currentModule，HdsTabs 没有 index 属性，必须显式同步。
  @Monitor('session.currentModule')
  onCurrentModuleChanged(): void {
    this.tabsController.changeIndex(this.moduleIndex)
  }

  // clearToHome 回首页用零时长转场；其余委托 fadeNavTransition 解析。
  // 平台限制：本委托存在时页面级 systemTransition 不生效，须统一在此分发。
  private readonly navTransition: CustomTransitionDelegate =
    (from: NavContentInfo, to: NavContentInfo, _operation: NavigationOperation):
    NavigationAnimatedTransition | undefined => {
      if (appRouter.consumeHomeTransition()) {
        return {
          timeout: 0,
          transition: (proxy: NavigationTransitionProxy) => {
            proxy.finishTransition()
          },
        }
      }
      return fadeNavTransition(this.getUIContext(), from, to)
    }

  @Computed
  get moduleIndex(): number {
    const index: number = MODULES.findIndex((module: ModuleTabDescriptor) =>
    module.route === this.session.currentModule)
    return index < 0 ? 0 : index
  }

  @Computed
  get pageHeaderActions(): DsPageHeaderAction[] {
    return [this.buildLockAction()]
  }

  @Computed
  get bottomTabItems(): DsBottomTabBarItem[] {
    return MODULES.map((module: ModuleTabDescriptor): DsBottomTabBarItem => {
      return { label: module.label, icon: module.icon }
    })
  }

  private buildLockAction(): DsPageHeaderAction {
    return {
      icon: $r('app.string.symbol_lock'),
      label: $r('app.string.lock'),
      onTap: (): void => {
        appViewModel.lockVault()
      },
    }
  }

  @Builder
  private moduleHeader(module: ModuleTabDescriptor) {
    DsPageHeader({
      title: module.label,
      showBack: false,
      actions: this.pageHeaderActions,
    })
  }

  // 页签根页各自持有 HdsNavigation，列表与标题栏才能继续走 dynamicHideTitleBar。
  @Builder
  private modulePage(module: ModuleTabDescriptor) {
    HdsNavigation() {
      if (module.route === ROUTE_GENERATOR) {
        GeneratorPage()
      } else {
        ModulePendingContent()
      }
    }
    .width('100%')
    .height('100%')
    .hideBackButton(true)
    .titleBar(dsPageTitleBarOptions((): void => this.moduleHeader(module)))
    .titleMode(HdsNavigationTitleMode.MINI)
    .mode(NavigationMode.Stack)
    .backgroundColor($r('app.color.ds_surface_canvas'))
  }

  // 纯色渐变遮罩：沿用 DsBottomActionBar 的透明到画布色处理，不叠模糊层。
  @Builder
  private bottomTabBar() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height(TAB_BAR_GRADIENT_HEIGHT_VP)
        .linearGradient({
          angle: 180,
          colors: [
            [$r('app.color.ds_surface_canvas_transparent'), 0],
            [$r('app.color.ds_surface_canvas'), 1],
          ],
        })
        .hitTestBehavior(HitTestMode.None)

      DsBottomTabBar({
        items: this.bottomTabItems,
        selectedIndex: this.moduleIndex,
        onSelect: (index: number) => this.tabsController.changeIndex(index),
      })
    }
    .width('100%')
    .height(TAB_BAR_GRADIENT_HEIGHT_VP)
    .hitTestBehavior(HitTestMode.Transparent)
  }

  // 前后台切换时的隐私遮罩：只露品牌标识，不展示启动页的版本号与加载节拍。
  @Builder
  private privacyCover() {
    Column() {
      Image($r('app.media.launch_icon'))
        .draggable(false)
        .width($r('app.float.ds_logo_size'))
        .height($r('app.float.ds_logo_size'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.ds_surface_canvas'))
  }

  build() {
    Stack() {
      HdsNavigation(appRouter.stack) {
        Stack({ alignContent: Alignment.Bottom }) {
          HdsTabs({ controller: this.tabsController }) {
            TabContent() {
              VaultHomePage()
            }

            TabContent() {
              this.modulePage(MODULES[1])
            }

            TabContent() {
              this.modulePage(MODULES[2])
            }

            TabContent() {
              this.modulePage(MODULES[3])
            }
          }
          .width('100%')
          .height('100%')
          .vertical(false)
          .barPosition(BarPosition.End)
          .barHeight(0)
          .scrollable(false)
          .animationDuration(AnimationTokens.DURATION_FEEDBACK)
          .onChange((index: number) => appViewModel.switchModule(MODULES[index].route))

          if (!this.home.batchMode) {
            this.bottomTabBar()
          }
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .hideBackButton(true)
      .hideTitleBar(true)
      .customNavContentTransition(this.navTransition)
      .mode(NavigationMode.Stack)
      .backgroundColor($r('app.color.ds_surface_canvas'))

      if (this.session.privacyCovered) {
        this.privacyCover()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ds_surface_canvas'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    // 壳层真正上屏后才让品牌页退场，交接期间不出现空白帧。
    .onAppear(() => appViewModel.markShellReady())
  }
}
