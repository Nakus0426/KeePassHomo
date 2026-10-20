import { bundleManager } from '@kit.AbilityKit'
import { ROUTE_WELCOME } from '../../constants/RouteConstants'
import { appRouter } from '../../navigation/AppRouter'
import { WelcomeParam } from '../../navigation/RouteParams'
import { appViewModel, AppViewModel } from '../../viewmodel/AppViewModel'

@ComponentV2
export struct WelcomePage {
  private readonly viewModel: AppViewModel = appViewModel
  @Local private showBack: boolean = false
  @Local private version: string = ''

  aboutToAppear(): void {
    const param: WelcomeParam | undefined = appRouter.topParam() as WelcomeParam | undefined
    this.showBack = param?.showBack ?? false
    const info: bundleManager.BundleInfo =
      bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
    this.version = `v${info.versionName}`
  }

  @Builder
  private actionCard(title: ResourceStr, description: ResourceStr, footer: ResourceStr, icon: Resource,
    filled: boolean, action: () => void) {
    Column() {
      Row({ space: $r('app.float.ds_space_sm') }) {
        SymbolGlyph(icon)
          .fontSize($r('app.float.ds_icon_md'))
          .fontColor([filled ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_primary')])
        Column({ space: $r('app.float.ds_space_sm') }) {
          Text(title)
            .fontSize($r('app.float.ds_font_title'))
            .fontWeight(600)
            .fontColor(filled ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_primary'))
          Text(description)
            .fontSize($r('app.float.ds_font_body_sm'))
            .fontColor(filled ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_secondary'))
            .opacity(filled ? 0.78 : 1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: $r('app.float.ds_space_xs') }) {
        Text(footer)
          .fontSize($r('app.float.ds_font_body_sm'))
          .fontWeight(600)
          .fontColor(filled ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_primary'))
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize($r('app.float.ds_icon_tiny'))
          .fontColor([filled ? $r('app.color.ds_on_primary') : $r('app.color.ds_text_primary')])
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height(110)
    .padding($r('app.float.ds_gutter'))
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor(filled ? $r('app.color.ds_primary') : $r('app.color.ds_surface_low'))
    .onClick(action)
  }

  build() {
    NavDestination() {
      Column() {
        Column() {
          Column({ space: $r('app.float.ds_space_lg') }) {
            Row().width('100%').height($r('app.float.ds_space_xl'))
            if (this.showBack) {
              Row() {
                SymbolGlyph($r('sys.symbol.arrow_left'))
                  .fontSize($r('app.float.ds_icon_md'))
                  .fontColor([$r('app.color.ds_text_primary')])
              }
              .width($r('app.float.ds_button_height'))
              .height($r('app.float.ds_button_height'))
              .justifyContent(FlexAlign.Center)
              .onClick(() => appRouter.pop())
            }

            Stack() {
              SymbolGlyph($r('sys.symbol.lock'))
                .fontSize($r('app.float.ds_space_xl'))
                .fontColor([$r('app.color.ds_on_primary')])
            }
            .width($r('app.float.ds_logo_size'))
            .height($r('app.float.ds_logo_size'))
            .backgroundColor($r('app.color.ds_primary'))

            Column({ space: $r('app.float.ds_space_sm') }) {
              Text($r('app.string.app_brand_name'))
                .fontSize($r('app.float.ds_font_display'))
                .fontWeight(600)
                .fontColor($r('app.color.ds_text_primary'))
              Text($r('app.string.welcome_tagline'))
                .fontSize($r('app.float.ds_font_body'))
                .fontColor($r('app.color.ds_text_secondary'))
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({
            bottom: 32,
            left: $r('app.float.ds_space_lg'),
            right: $r('app.float.ds_space_lg'),
          })
          .backgroundColor($r('app.color.ds_surface_low'))
          .alignItems(HorizontalAlign.Start)

          Column({ space: $r('app.float.ds_space_md') }) {
            this.actionCard(
              $r('app.string.create_vault'),
              $r('app.string.action_create_vault_desc'),
              $r('app.string.action_create_vault_footer'),
              $r('sys.symbol.plus'),
              true,
              () => this.viewModel.openCreateVault(),
            )
            this.actionCard(
              $r('app.string.action_open_local_title'),
              $r('app.string.action_open_local_desc'),
              $r('app.string.action_open_local_footer'),
              $r('sys.symbol.folder'),
              false,
              () => this.viewModel.chooseLocalVault(),
            )
            this.actionCard(
              $r('app.string.action_webdav_title'),
              $r('app.string.action_webdav_desc'),
              $r('app.string.action_webdav_footer'),
              $r('sys.symbol.icloud'),
              false,
              () => this.viewModel.openWebDav(),
            )

            Text(this.version)
              .fontSize($r('app.float.ds_font_body_sm'))
              .fontColor($r('app.color.ds_text_disabled'))
              .alignSelf(ItemAlign.Start)
              .margin({ top: $r('app.float.ds_space_lg') })
          }
          .width('100%')
          .padding({
            top: $r('app.float.ds_space_lg'),
            bottom: $r('app.float.ds_space_lg'),
            left: $r('app.float.ds_space_lg'),
            right: $r('app.float.ds_space_lg'),
          })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.ds_surface_canvas'))
    .onBackPressed(() => {
      if (this.showBack) {
        appRouter.pop()
        return true
      }
      appRouter.handleRootBack(ROUTE_WELCOME)
      return true
    })
  }
}

@Builder
export function welcomePageBuilder() {
  WelcomePage()
}
