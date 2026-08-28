import { HdsNavDestination } from '@kit.UIDesignKit'
import { ROUTE_SECURITY } from '../../constants/RouteConstants'
import { appRouter } from '../../navigation/AppRouter'
import { ModulePendingContent } from './ModulePendingContent'

@ComponentV2
export struct SecurityPage {
  build() {
    HdsNavDestination() {
      ModulePendingContent({ title: $r('app.string.security_center') })
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .onBackPressed(() => {
      appRouter.handleRootBack(ROUTE_SECURITY)
      return true
    })
  }
}

@Builder
export function securityPageBuilder() {
  SecurityPage()
}
