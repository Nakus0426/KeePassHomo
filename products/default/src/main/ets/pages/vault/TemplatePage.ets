import { HdsNavDestination } from '@kit.UIDesignKit'
import { VaultGroup } from '@ohos/common'
import { ROUTE_ENTRY_EDIT } from '../../constants/RouteConstants'
import { PageTopBar } from '../../components/PageChrome'
import { appRouter } from '../../navigation/AppRouter'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'

@ComponentV2
export struct TemplatePage {
  private readonly viewModel: AppViewModel = appViewModel

  @Builder
  private templateRow(title: Resource, description: Resource, enabled: boolean) {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(title)
          .width('100%')
          .fontWeight(FontWeight.Medium)
        Text(description)
          .width('100%')
          .fontSize($r('app.float.text_caption'))
          .fontColor($r('sys.color.font_secondary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button(enabled ? $r('app.string.continue_action') : $r('app.string.not_available'))
        .enabled(enabled)
        .backgroundColor(enabled ? $r('sys.color.comp_emphasize_secondary') : $r('sys.color.background_secondary'))
        .fontColor(enabled ? $r('sys.color.brand') : $r('sys.color.font_secondary'))
        .onClick(() => {
          appRouter.push(ROUTE_ENTRY_EDIT)
          this.viewModel.recordActivity()
        })
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level4'))
  }

  build() {
    HdsNavDestination() {
      Column({ space: 12 }) {
        PageTopBar({
          title: $r('app.string.choose_template'),
          showBack: true,
          onBack: () => appRouter.pop(),
        })
        this.templateRow($r('app.string.login_template'), $r('app.string.login_template_description'), true)
        this.templateRow($r('app.string.credit_card_template'), $r('app.string.not_available'), false)
        this.templateRow($r('app.string.secure_note_template'), $r('app.string.not_available'), false)
        this.templateRow($r('app.string.identity_template'), $r('app.string.not_available'), false)
        this.templateRow($r('app.string.wifi_template'), $r('app.string.not_available'), false)
        this.templateRow($r('app.string.license_template'), $r('app.string.not_available'), false)
        Blank()
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding($r('sys.float.padding_level12'))
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}

@Builder
export function templatePageBuilder() {
  TemplatePage()
}
