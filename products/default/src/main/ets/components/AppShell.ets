import { common } from '@kit.AbilityKit'
import { UIObserver, uiMaterial } from '@kit.ArkUI'
import { HdsNavigation } from '@kit.UIDesignKit'
import {
  ROUTE_GENERATOR,
  ROUTE_SECURITY,
  ROUTE_SETTINGS,
  ROUTE_VAULT,
} from '../constants/RouteConstants'
import { appSessionState, AppSessionState } from '../state/AppSessionState'
import { appRouter } from '../navigation/AppRouter'
import { appViewModel, AppViewModel } from '../viewmodel/AppViewModel'
import { SplashContent } from '../pages/onboarding/SplashContent'

@ComponentV2
struct ModuleNavigationBar {
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
    .onClick(() => appViewModel.switchModule(route))
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
  @Local private viewModel: AppViewModel = appViewModel
  @Local private session: AppSessionState = appSessionState
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

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      HdsNavigation(appRouter.stack) {
        SplashContent({ viewModel: appViewModel })
      }
      .width('100%')
      .height('100%')
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .backgroundColor($r('sys.color.background_secondary'))
      .zIndex(0)

      if (appRouter.isModuleRoute()) {
        ModuleNavigationBar()
          .zIndex(1)
      }
      if (this.session.privacyCovered) {
        SplashContent({ viewModel: appViewModel })
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
