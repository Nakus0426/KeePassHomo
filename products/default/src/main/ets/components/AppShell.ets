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
import { appViewModel } from '../viewmodel/AppViewModel'
import { SplashContent } from '../pages/onboarding/SplashContent'
import { VaultHomePage } from '../pages/vault/VaultHomePage'
import { ModulePendingContent } from '../pages/modules/ModulePendingContent'
import { GeneratorPage } from '../pages/generator/GeneratorPage'
import { GeneratorContentController } from '../pages/generator/GeneratorComponents'

/**
 * 底部页签描述：路由名与页签图标、文案的映射，顺序即 HdsTabs 页签顺序。
 */
interface ModuleTabDescriptor {
  route: string
  label: Resource
  symbol: Resource
}

const MODULES: readonly ModuleTabDescriptor[] = [
  { route: ROUTE_VAULT, label: $r('app.string.vault_home'), symbol: $r('sys.symbol.folder_fill') },
  { route: ROUTE_SECURITY, label: $r('app.string.security_center'), symbol: $r('sys.symbol.shield_checkered') },
  { route: ROUTE_GENERATOR, label: $r('app.string.password_generator'), symbol: $r('sys.symbol.wand_and_stars_fill') },
  { route: ROUTE_SETTINGS, label: $r('app.string.settings'), symbol: $r('sys.symbol.gearshape_fill') },
]

@ComponentV2
export struct AppShell {
  @Local private session: AppSessionState = appSessionState
  private readonly tabsController: HdsTabsController = new HdsTabsController()
  private readonly generatorController: GeneratorContentController = new GeneratorContentController()
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
   * 消除首页露出的系统默认横向滑入残影；其余转场返回 undefined 走系统默认。
   */
  private readonly navTransition: CustomTransitionDelegate =
    (_from: NavContentInfo, _to: NavContentInfo, _operation: NavigationOperation):
    NavigationAnimatedTransition | undefined => {
      if (appRouter.consumeHomeTransition()) {
        return {
          timeout: 0,
          transition: (proxy: NavigationTransitionProxy) => {
            proxy.finishTransition()
          },
        }
      }
      return undefined
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

  @Computed
  get titleBarOptions(): HdsNavigationTitleBarOptions {
    const menuItems: HdsNavigationMenuItemOptions[] = [{
      content: {
        icon: $r('sys.symbol.lock'),
        label: $r('app.string.lock'),
        action: () => appViewModel.lockVault(),
      },
    }]
    if (this.currentTab.route === ROUTE_GENERATOR) {
      menuItems.push({
        content: {
          icon: $r('sys.symbol.doc_text_on_doc_text'),
          label: $r('app.string.copy'),
          action: () => this.generatorController.copyPassword(),
        },
      })
    }
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
        title: {
          mainTitle: this.currentTab.label,
        },
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
            GeneratorPage({ controller: this.generatorController })
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
