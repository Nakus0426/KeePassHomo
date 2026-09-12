import { common } from '@kit.AbilityKit'
import { SymbolGlyphModifier, UIObserver } from '@kit.ArkUI'
import {
  CustomTransitionDelegate,
  hdsMaterial,
  HdsNavigation,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { ROUTE_GENERATOR, ROUTE_SECURITY, ROUTE_SETTINGS, ROUTE_VAULT } from '../constants/RouteConstants'
import { appSessionState, AppSessionState } from '../state/AppSessionState'
import { appRouter } from '../navigation/AppRouter'
import { fadeNavTransition } from '../navigation/NavFadeTransition'
import { appViewModel } from '../viewmodel/AppViewModel'
import { SplashContent } from '../pages/onboarding/SplashContent'
import { VaultHomePage } from '../pages/vault/VaultHomePage'
import { vaultTabChrome } from '../pages/vault/VaultTabChrome'
import { ModuleTabChrome } from './ModuleTabChrome'
import { ModulePendingContent } from '../pages/modules/ModulePendingContent'
import { GeneratorPage } from '../pages/generator/GeneratorPage'
import { generatorTabChrome } from '../pages/generator/GeneratorTabChrome'

/**
 * 底部页签描述：路由名与页签图标、文案、标题栏供给的映射，顺序即 HdsTabs 页签顺序。
 */
interface ModuleTabDescriptor {
  route: string
  label: Resource
  symbol: Resource
  chrome?: ModuleTabChrome
}

const MODULES: readonly ModuleTabDescriptor[] = [
  {
    route: ROUTE_VAULT,
    label: $r('app.string.vault_home'),
    symbol: $r('sys.symbol.folder_fill'),
    chrome: vaultTabChrome,
  },
  { route: ROUTE_SECURITY, label: $r('app.string.security_center'), symbol: $r('sys.symbol.shield_checkered') },
  {
    route: ROUTE_GENERATOR,
    label: $r('app.string.password_generator'),
    symbol: $r('sys.symbol.wand_and_stars_fill'),
    chrome: generatorTabChrome,
  },
  { route: ROUTE_SETTINGS, label: $r('app.string.settings'), symbol: $r('sys.symbol.gearshape_fill') },
]

@ComponentV2
export struct AppShell {
  @Local private session: AppSessionState = appSessionState
  private readonly tabsController: HdsTabsController = new HdsTabsController()
  private uiObserver: UIObserver | undefined = undefined

  aboutToAppear(): void {
    this.uiObserver = this.getUIContext().getUIObserver()
    appRouter.attach(this.uiObserver)
    appViewModel.initialize(this.context())
  }

  aboutToDisappear(): void {
    if (this.uiObserver !== undefined) {
      appRouter.detach(this.uiObserver)
      this.uiObserver = undefined
    }
    appViewModel.dispose()
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

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  /**
   * Navigation 级转场代理：clearToHome 的清栈回首页零时长，
   * 消除首页露出的系统默认横向滑入残影；其余转场委托 fadeNavTransition
   * 解析（页面经 registerFadeDestination 注册即得淡入淡出，未注册走系统默认）。
   * 注意：本委托存在时页面级 systemTransition 不生效，须统一在此分发。
   */
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
  get currentTab(): ModuleTabDescriptor {
    return MODULES[this.moduleIndex]
  }

  private tabBar(module: ModuleTabDescriptor): BottomTabBarStyle {
    return new BottomTabBarStyle({
      normal: new SymbolGlyphModifier(module.symbol)
        .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
        .fontColor([$r('sys.color.ohos_id_color_bottom_tab_icon_off')]),
      selected: new SymbolGlyphModifier(module.symbol)
        .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
        .fontColor([$r('sys.color.ohos_id_color_activated')]),
    }, module.label)
  }

  /**
   * 模块标题行代理：在组件上下文内调用契约供给的 WrappedBuilder，
   * 使模块自绘标题行拿到正确的渲染上下文（直接传全局 @Builder 引用会丢失）。
   * 仅在模块提供了 titleRowBuilder 时才作为 stackBuilder 被调用。
   */
  @Builder
  private moduleTitleRow() {
    this.currentTab.chrome!.titleRowBuilder!.builder()
  }

  /**
   * 模块标题栏底部行代理：与 moduleTitleRow 同理，在组件上下文内调用契约供给的
   * WrappedBuilder；仅在模块提供了 bottomRowBuilder 且保险库已解锁时被调用。
   */
  @Builder
  private moduleBottomRow() {
    this.currentTab.chrome!.bottomRowBuilder!.builder()
  }

  @Computed
  get titleBarOptions(): HdsNavigationTitleBarOptions {
    const chrome: ModuleTabChrome | undefined = this.currentTab.chrome
    const menuItems: HdsNavigationMenuItemOptions[] = []
    const moduleMenuItems: HdsNavigationMenuItemOptions[] = chrome?.menuItems?.() ?? []
    for (const item of moduleMenuItems) {
      menuItems.push(item)
    }
    menuItems.push({
      content: {
        icon: $r('sys.symbol.lock'),
        label: $r('app.string.lock'),
        action: () => appViewModel.lockVault(),
      },
    })

    return {
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
        title: chrome?.titleRowBuilder !== undefined
          ? { mainTitle: '' }
          : {
            mainTitle: this.currentTab.label,
            subTitle: chrome?.subtitle?.(),
          },
        stackBuilder: chrome?.titleRowBuilder !== undefined ? (): void => this.moduleTitleRow() : undefined,
        bottomBuilder: chrome?.bottomRowBuilder !== undefined && !this.session.vaultLocked
          ? { builder: (): void => this.moduleBottomRow() }
          : undefined,
        menu: { value: menuItems },
      },
    }
  }

  build() {
    Stack() {
      HdsNavigation(appRouter.stack) {
        HdsTabs({ controller: this.tabsController, index: this.moduleIndex }) {
          TabContent() {
            VaultHomePage()
          }
          .tabBar(this.tabBar(MODULES[0]))

          TabContent() {
            ModulePendingContent()
          }
          .tabBar(this.tabBar(MODULES[1]))

          TabContent() {
            GeneratorPage()
          }
          .tabBar(this.tabBar(MODULES[2]))

          TabContent() {
            ModulePendingContent()
          }
          .tabBar(this.tabBar(MODULES[3]))
        }
        .barPosition(BarPosition.End)
        .barOverlap(true)
        .barFloatingStyle({
          barBottomMargin: 28,
          systemMaterialEffect: {
            materialType: hdsMaterial.MaterialType.IMMERSIVE,
          },
        })
        .onChange((index: number) => appViewModel.switchModule(MODULES[index].route))
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .hideBackButton(true)
      .titleBar(this.titleBarOptions)
      .titleMode(HdsNavigationTitleMode.MINI)
      .customNavContentTransition(this.navTransition)
      .mode(NavigationMode.Stack)
      .backgroundColor($r('sys.color.background_secondary'))

      if (this.session.privacyCovered) {
        SplashContent({ viewModel: appViewModel })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
