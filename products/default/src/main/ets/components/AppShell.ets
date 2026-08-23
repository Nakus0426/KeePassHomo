import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { uiMaterial } from '@kit.ArkUI'
import { HdsNavDestination, HdsNavigation } from '@kit.UIDesignKit'
import { LogUtil, ToastUtil } from '@pura/harmony-utils'
import {
  ROUTE_CREATE_VAULT,
  ROUTE_ENTRY_DETAIL,
  ROUTE_ENTRY_EDIT,
  ROUTE_FILE_SUMMARY,
  ROUTE_GENERATOR,
  ROUTE_SECURITY,
  ROUTE_SETTINGS,
  ROUTE_TEMPLATE,
  ROUTE_UNLOCK,
  ROUTE_VAULT,
  ROUTE_WELCOME,
} from '../constants/RouteConstants'
import { GeneratorPage } from '../pages/generator/GeneratorPage'
import { SplashContent } from '../pages/onboarding/SplashContent'
import { PendingModulePage } from '../pages/modules/PendingModulePage'
import { CreateVaultPage } from '../pages/onboarding/CreateVaultPage'
import { FileSummaryPage } from '../pages/onboarding/FileSummaryPage'
import { UnlockPage } from '../pages/onboarding/UnlockPage'
import { WelcomePage } from '../pages/onboarding/WelcomePage'
import { EntryDetailPage } from '../pages/vault/EntryDetailPage'
import { EntryEditPage } from '../pages/vault/EntryEditPage'
import { TemplatePage } from '../pages/vault/TemplatePage'
import { VaultHomePage } from '../pages/vault/VaultHomePage'
import { appSessionState, AppSessionState } from '../state/AppSessionState'
import { VaultAppViewModel } from '../viewmodel/VaultAppViewModel'

@ComponentV2
struct ModuleNavigationBar {
  @Param viewModel: VaultAppViewModel = new VaultAppViewModel()
  @Param session: AppSessionState = appSessionState
  private readonly material: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.THIN,
    applyShadow: true,
  })

  @Builder
  private navigationItem(label: Resource, symbol: Resource, route: string) {
    Button({ type: ButtonType.Normal, stateEffect: false }) {
      Column({ space: 2 }) {
        SymbolGlyph(symbol)
          .fontSize(22)
          .fontColor([this.session.currentModule === route
            ? $r('sys.color.brand') : $r('sys.color.font_secondary')])
        Text(label)
          .fontSize(11)
          .fontWeight(this.session.currentModule === route ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.session.currentModule === route
            ? $r('sys.color.brand') : $r('sys.color.font_secondary'))
          .maxLines(1)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.session.currentModule === route
        ? $r('sys.color.comp_emphasize_secondary') : Color.Transparent)
      .borderRadius(28)
    }
    .layoutWeight(1)
    .height(56)
    .backgroundColor(Color.Transparent)
    .onClick(() => this.viewModel.switchModule(route))
  }

  build() {
    Row({ space: 4 }) {
      this.navigationItem($r('app.string.vault_home'), $r('sys.symbol.folder_fill'), ROUTE_VAULT)
      this.navigationItem($r('app.string.security_center'), $r('sys.symbol.shield_checkered'), ROUTE_SECURITY)
      this.navigationItem($r('app.string.password_generator'), $r('sys.symbol.wand_and_stars_fill'), ROUTE_GENERATOR)
      this.navigationItem($r('app.string.settings'), $r('sys.symbol.gearshape_fill'), ROUTE_SETTINGS)
    }
    .width('calc(100% - 32vp)')
    .height(68)
    .padding(6)
    .margin({ left: 16, right: 16, bottom: 12 })
    .borderRadius(34)
    .systemMaterial(this.material)
  }
}

@ComponentV2
export struct AppShell {
  @Local private viewModel: VaultAppViewModel = new VaultAppViewModel()
  @Local private session: AppSessionState = appSessionState
  private lastBackPressedAt: number = 0
  private lastBackRoute: string = ''

  aboutToAppear(): void {
    this.viewModel.initialize(this.context())
  }

  aboutToDisappear(): void {
    this.viewModel.dispose()
  }

  @Monitor('session.vaultLocked')
  onVaultLockChanged(_monitor: IMonitor): void {
    this.viewModel.onVaultLockChanged()
  }

  @Monitor('session.sensitiveEpoch')
  onSensitiveEpochChanged(_monitor: IMonitor): void {
    this.viewModel.onSensitiveEpochChanged()
  }

  @Monitor('session.foregroundEpoch')
  onForegroundEpochChanged(_monitor: IMonitor): void {
    this.viewModel.onForegroundEpochChanged()
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  private handleRootBack(route: string): void {
    const now: number = Date.now()
    if (route !== this.lastBackRoute || now - this.lastBackPressedAt > 2000) {
      this.lastBackPressedAt = now
      this.lastBackRoute = route
      try {
        ToastUtil.showToast($r('app.string.press_back_again_to_background'), {
          uiContext: this.getUIContext(),
          duration: 2000,
        })
      } catch (error) {
        const businessError: BusinessError = error as BusinessError
        LogUtil.error(`返回桌面提示显示失败，错误码=${businessError.code}`)
      }
      return
    }
    this.lastBackPressedAt = 0
    this.lastBackRoute = ''
    try {
      this.context().moveAbilityToBackground().catch((error: BusinessError) => {
        LogUtil.error(`返回桌面失败，错误码=${error.code}`)
      })
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      LogUtil.error(`返回桌面失败，错误码=${businessError.code}`)
    }
  }

  @Builder
  private routeDestination(name: string, param: Object) {
    if (name === ROUTE_WELCOME) {
      WelcomePage({ viewModel: this.viewModel })
    } else if (name === ROUTE_CREATE_VAULT) {
      CreateVaultPage({ viewModel: this.viewModel })
    } else if (name === ROUTE_FILE_SUMMARY) {
      FileSummaryPage({ viewModel: this.viewModel })
    } else if (name === ROUTE_UNLOCK) {
      UnlockPage({
        viewModel: this.viewModel,
        onRootBack: () => this.handleRootBack(ROUTE_UNLOCK),
      })
    } else if (name === ROUTE_VAULT) {
      VaultHomePage({
        viewModel: this.viewModel,
        onRootBack: () => this.handleRootBack(ROUTE_VAULT),
      })
    } else if (name === ROUTE_SECURITY) {
      PendingModulePage({
        title: $r('app.string.security_center'),
        route: ROUTE_SECURITY,
        onLock: () => this.viewModel.lockVault(),
        onActivity: () => this.viewModel.recordActivity(),
        onShown: (route: string) => this.viewModel.showRoute(route),
        onRootBack: () => this.handleRootBack(ROUTE_SECURITY),
      })
    } else if (name === ROUTE_GENERATOR) {
      GeneratorPage({
        viewModel: this.viewModel.generator,
        clipboardSeconds: this.viewModel.clipboardSeconds,
        onLock: () => this.viewModel.lockVault(),
        onCopy: (value: string) => this.viewModel.copyValue(value),
        onActivity: () => this.viewModel.recordActivity(),
        onShown: () => this.viewModel.showRoute(ROUTE_GENERATOR),
        onRootBack: () => this.handleRootBack(ROUTE_GENERATOR),
      })
    } else if (name === ROUTE_SETTINGS) {
      PendingModulePage({
        title: $r('app.string.settings'),
        route: ROUTE_SETTINGS,
        onLock: () => this.viewModel.lockVault(),
        onActivity: () => this.viewModel.recordActivity(),
        onShown: (route: string) => this.viewModel.showRoute(route),
        onRootBack: () => this.handleRootBack(ROUTE_SETTINGS),
      })
    } else if (name === ROUTE_TEMPLATE) {
      TemplatePage({ viewModel: this.viewModel })
    } else if (name === ROUTE_ENTRY_EDIT) {
      EntryEditPage({ viewModel: this.viewModel })
    } else if (name === ROUTE_ENTRY_DETAIL) {
      EntryDetailPage({ viewModel: this.viewModel })
    } else {
      HdsNavDestination() {
        Text($r('app.string.route_not_found'))
          .fontColor($r('sys.color.warning'))
      }
      .hideTitleBar(true)
      .backgroundColor($r('sys.color.background_secondary'))
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      HdsNavigation(this.viewModel.navPathStack) {
        SplashContent({ viewModel: this.viewModel })
      }
      .width('100%')
      .height('100%')
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .navDestination(this.routeDestination)
      .backgroundColor($r('sys.color.background_secondary'))
      .zIndex(0)

      if (this.viewModel.isModuleRoute()) {
        ModuleNavigationBar({ viewModel: this.viewModel, session: this.session })
          .zIndex(1)
      }
      if (this.session.privacyCovered) {
        SplashContent({ viewModel: this.viewModel })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .zIndex(2)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
