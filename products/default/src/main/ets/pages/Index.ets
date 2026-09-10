import { AppShell } from '../components/AppShell'
import { appRouter } from '../navigation/AppRouter'
import { ROUTE_HOME } from '../constants/RouteConstants'

@Entry
@ComponentV2
struct Index {
  onBackPress(): boolean {
    if (appRouter.isHomePage()) {
      appRouter.handleRootBack(ROUTE_HOME)
      return true
    }
    return false
  }

  build() {
    Stack() {
      AppShell()
    }
    .width('100%')
    .height('100%')
  }
}
