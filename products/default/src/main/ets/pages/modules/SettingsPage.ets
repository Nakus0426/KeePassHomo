import { HdsNavDestination } from '@kit.UIDesignKit'
import { ROUTE_SETTINGS } from '../../constants/RouteConstants'
import { appRouter } from '../../navigation/AppRouter'
import { ModulePendingContent } from './ModulePendingContent'

@ComponentV2
export struct SettingsPage {
  build() {
    HdsNavDestination() {
      ModulePendingContent({ title: $r('app.string.settings') })
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .onBackPressed(() => {
      appRouter.handleRootBack(ROUTE_SETTINGS)
      return true
    })
  }
}

@Builder
export function settingsPageBuilder() {
  SettingsPage()
}
