import { common } from '@kit.AbilityKit'
import { AppShell } from '../components/AppShell'
import { LaunchPage } from './onboarding/LaunchPage'
import { appRouter } from '../navigation/AppRouter'
import { appViewModel, AppViewModel } from '../viewmodel/AppViewModel'
import { ROUTE_HOME } from '../constants/RouteConstants'

@Entry
@ComponentV2
struct Index {
  // 首帧只构建品牌页，等初始化完成再挂 AppShell，避免整棵导航树拖慢首屏。
  @Local private viewModel: AppViewModel = appViewModel

  aboutToAppear(): void {
    this.viewModel.initialize(this.context())
  }

  aboutToDisappear(): void {
    this.viewModel.dispose()
  }

  onBackPress(): boolean {
    if (appRouter.isHomePage()) {
      appRouter.handleRootBack(ROUTE_HOME)
      return true
    }
    return false
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  build() {
    Stack() {
      if (this.viewModel.shellVisible) {
        AppShell()
      }
      if (this.viewModel.launchVisible) {
        LaunchPage()
      }
    }
    .width('100%')
    .height('100%')
  }
}
