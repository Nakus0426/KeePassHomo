import { UIObserver } from '@kit.ArkUI'
import {
  CustomTransitionDelegate,
  hdsMaterial,
  HdsNavigation,
  HdsNavigationMenuItemOptions,
  HdsNavigationTitleBarOptions,
  HdsNavigationTitleMode,
  IconStyleMode,
  ScrollEffectType,
} from '@kit.UIDesignKit'
import { ROUTE_GENERATOR, ROUTE_SECURITY, ROUTE_SETTINGS, ROUTE_VAULT } from '../constants/RouteConstants'
import {
  TAB_BAR_FLOAT_BOTTOM_MARGIN_VP,
  TAB_BAR_FLOAT_HEIGHT_VP,
  TAB_ICON_LABEL_GAP_VP,
  TAB_ICON_SIZE_VP,
  TAB_LABEL_FONT_SIZE_FP,
} from '../constants/TabBarMetrics'
import { appSessionState, AppSessionState } from '../state/AppSessionState'
import { appRouter } from '../navigation/AppRouter'
import { fadeNavTransition } from '../navigation/NavFadeTransition'
import { appViewModel } from '../viewmodel/AppViewModel'
import { VaultHomePage } from '../pages/vault/VaultHomePage'
import { vaultTabChrome } from '../pages/vault/VaultTabChrome'
import { DsPageHeader, DsPageHeaderAction } from './DsPageHeader'
import { dsPageTitleBarOptions } from './DsPageTitleBar'
import { ModuleTabChrome } from './ModuleTabChrome'
import { ModulePendingContent } from '../pages/modules/ModulePendingContent'
import { GeneratorPage } from '../pages/generator/GeneratorPage'
import { generatorTabChrome } from '../pages/generator/GeneratorTabChrome'

// 数组顺序即页签顺序。选中态用两套位图表达，矩形选中底由自绘页签给出。
interface ModuleTabDescriptor {
  route: string
  label: Resource
  icon: Resource
  selectedIcon: Resource
  chrome?: ModuleTabChrome
}

const MODULES: ModuleTabDescriptor[] = [
  {
    route: ROUTE_VAULT,
    label: $r('app.string.vault_home'),
    icon: $r('app.media.nav_vault_normal'),
    selectedIcon: $r('app.media.nav_vault_selected'),
    chrome: vaultTabChrome,
  },
  {
    route: ROUTE_SECURITY,
    label: $r('app.string.security_center'),
    icon: $r('app.media.nav_security_normal'),
    selectedIcon: $r('app.media.nav_security_selected'),
  },
  {
    route: ROUTE_GENERATOR,
    label: $r('app.string.password_generator'),
    icon: $r('app.media.nav_generator_normal'),
    selectedIcon: $r('app.media.nav_generator_selected'),
    chrome: generatorTabChrome,
  },
  {
    route: ROUTE_SETTINGS,
    label: $r('app.string.settings'),
    icon: $r('app.media.nav_settings_normal'),
    selectedIcon: $r('app.media.nav_settings_selected'),
  },
]

@ComponentV2
export struct AppShell {
  @Local private session: AppSessionState = appSessionState
  private readonly tabsController: TabsController = new TabsController()
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
  get currentTab(): ModuleTabDescriptor {
    return MODULES[this.moduleIndex]
  }

  @Computed
  get isVaultModule(): boolean {
    return this.currentTab.route === ROUTE_VAULT
  }

  @Computed
  get pageHeaderActions(): DsPageHeaderAction[] {
    const actions: DsPageHeaderAction[] = []
    const moduleActions: DsPageHeaderAction[] = this.currentTab.chrome?.headerActions?.() ?? []
    for (const action of moduleActions) {
      actions.push(action)
    }
    actions.push(this.buildLockAction())
    return actions
  }

  // 页头动作与标题栏菜单共用同一个锁定项，避免两处重复构造。
  private buildLockAction(): DsPageHeaderAction {
    return {
      icon: $r('app.string.symbol_lock'),
      label: $r('app.string.lock'),
      onTap: (): void => {
        appViewModel.lockVault()
      },
    }
  }

  // 内容须铺满页签，否则点击热区只覆盖墨迹；选中态在 Builder 内读状态，切换时才会刷新。
  @Builder
  private tabItem(module: ModuleTabDescriptor, index: number) {
    Column({ space: TAB_ICON_LABEL_GAP_VP }) {
      Image(this.moduleIndex === index ? module.selectedIcon : module.icon)
        .width(TAB_ICON_SIZE_VP)
        .height(TAB_ICON_SIZE_VP)
        .interpolation(ImageInterpolation.High)
      Text(module.label)
        .fontSize(TAB_LABEL_FONT_SIZE_FP)
        .fontColor(this.moduleIndex === index ? $r('app.color.ds_text_primary') : $r('app.color.ds_text_secondary'))
        .maxLines(1)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.moduleIndex === index ? $r('app.color.ds_surface_high') : Color.Transparent)
    .onClick(() => {
      this.tabsController.changeIndex(index)
      appViewModel.switchModule(module.route)
    })
  }

  @Builder
  private floatingTabBar() {
    Column() {
      Row() {
        ForEach(MODULES, (module: ModuleTabDescriptor, index: number) => {
          this.tabItem(module, index)
        }, (module: ModuleTabDescriptor) => module.route)
      }
      .width('100%')
      .height(TAB_BAR_FLOAT_HEIGHT_VP)
      .backgroundColor($r('app.color.ds_surface_low'))
    }
    .width('100%')
    .padding({ left: $r('app.float.ds_space_sm'), right: $r('app.float.ds_space_sm') })
    .margin({ bottom: TAB_BAR_FLOAT_BOTTOM_MARGIN_VP })
  }

  // 须在组件上下文内调用契约供给的 WrappedBuilder：直接传全局 @Builder 引用会丢失渲染上下文。
  @Builder
  private moduleTitleRow() {
    this.currentTab.chrome!.titleRowBuilder!.builder()
  }

  @Builder
  private moduleBottomRow() {
    this.currentTab.chrome!.bottomRowBuilder!.builder()
  }

  @Computed
  get vaultTitleBarOptions(): HdsNavigationTitleBarOptions {
    const chrome: ModuleTabChrome | undefined = this.currentTab.chrome
    const menuItems: HdsNavigationMenuItemOptions[] = []
    const moduleMenuItems: HdsNavigationMenuItemOptions[] = chrome?.menuItems?.() ?? []
    for (const item of moduleMenuItems) {
      menuItems.push(item)
    }
    const lockAction: DsPageHeaderAction = this.buildLockAction()
    menuItems.push({
      content: {
        icon: lockAction.icon,
        type: IconStyleMode.SMALL,
        label: lockAction.label,
        action: lockAction.onTap,
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
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
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

  @Builder
  private pageHeaderBuilder() {
    DsPageHeader({
      title: this.currentTab.label,
      showBack: false,
      actions: this.pageHeaderActions,
    })
  }

  @Computed
  get titleBarOptions(): HdsNavigationTitleBarOptions {
    return this.isVaultModule
      ? this.vaultTitleBarOptions
      : dsPageTitleBarOptions((): void => this.pageHeaderBuilder())
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
          Tabs({ controller: this.tabsController, index: this.moduleIndex }) {
            TabContent() {
              VaultHomePage()
            }

            TabContent() {
              ModulePendingContent()
            }

            TabContent() {
              GeneratorPage()
            }

            TabContent() {
              ModulePendingContent()
            }
          }
          .barHeight(0)
          .barBackgroundColor(Color.Transparent)
          .scrollable(false)
          .onChange((index: number) => appViewModel.switchModule(MODULES[index].route))
          .width('100%')
          .height('100%')

          this.floatingTabBar()
        }
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
