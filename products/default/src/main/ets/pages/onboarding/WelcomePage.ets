import { uiMaterial } from '@kit.ArkUI'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { ROUTE_WELCOME } from '../../constants/RouteConstants'
import { StatusText } from '../../components/PageChrome'
import { VaultAppViewModel } from '../../viewmodel/VaultAppViewModel'

@ComponentV2
export struct DataSourceCard {
  @Param icon: Resource = $r('sys.symbol.folder_fill')
  @Param title: Resource = $r('app.string.open_local_vault')
  @Param description: Resource = $r('app.string.open_local_vault_description')
  @Param selectable: boolean = true
  @Event onSelect: () => void = () => {
  }

  build() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Row({ space: $r('sys.float.padding_level8') }) {
        Stack() {
          SymbolGlyph(this.icon)
            .fontSize($r('sys.float.Title_L'))
            .fontColor([$r('sys.color.brand')])
        }
        .padding($r('sys.float.padding_level4'))
        .borderRadius('50%')
        .backgroundColor($r('sys.color.comp_emphasize_secondary'))

        Column({ space: $r('sys.float.padding_level2') }) {
          Text(this.title)
            .fontSize($r('sys.float.Subtitle_L'))
            .fontColor($r('sys.color.font_primary'))
            .fontWeight(FontWeight.Medium)
          Text(this.description)
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize($r('sys.float.Title_S'))
          .fontColor([$r('sys.color.font_secondary')])
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .enabled(this.selectable)
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .borderRadius($r('sys.float.corner_radius_level10'))
    .systemMaterial(new uiMaterial.ImmersiveMaterial({
      interactive: true,
      lightEffect: { color: undefined },
      style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
    }))
    .onClick(() => this.onSelect())
  }
}


@ComponentV2
export struct WelcomePage {
  @Param viewModel: VaultAppViewModel = new VaultAppViewModel()

  build() {
    HdsNavDestination() {
      Scroll() {
        Column({ space: $r('sys.float.padding_level8') }) {
          Column({ space: $r('sys.float.padding_level2') }) {
            Image($r('app.media.launch_icon'))
              .width($r('app.float.welcome_icon_size'))
              .height($r('app.float.welcome_icon_size'))
            Text($r('app.string.app_title'))
              .fontSize($r('sys.float.Title_L'))
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
            Text($r('app.string.welcome_description'))
              .fontSize($r('sys.float.Subtitle_M'))
              .fontColor($r('sys.color.font_secondary'))
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ top: $r('sys.float.padding_level16') })

          Row({ space: $r('sys.float.padding_level8') }) {
            Stack() {
              SymbolGlyph($r('sys.symbol.shield_checkered'))
                .fontSize($r('sys.float.Title_L'))
                .fontColor([$r('sys.color.brand')])
            }
            .padding($r('sys.float.padding_level4'))
            .borderRadius('50%')
            .backgroundColor($r('sys.color.comp_emphasize_secondary'))

            Column({ space: $r('sys.float.padding_level2') }) {
              Text($r('app.string.local_storage_title'))
                .fontSize($r('sys.float.Subtitle_L'))
                .fontColor($r('sys.color.font_primary'))
                .fontWeight(FontWeight.Medium)
              Text($r('app.string.local_storage_description'))
                .fontSize($r('sys.float.Body_S'))
                .fontColor($r('sys.color.font_secondary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding($r('sys.float.padding_level8'))
          .margin({ top: $r('sys.float.padding_level8') })
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .borderRadius($r('sys.float.corner_radius_level10'))

          Text($r('app.string.choose_data_source'))
            .fontSize($r('sys.float.Subtitle_L'))
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
            .alignSelf(ItemAlign.Start)
            .padding({ left: $r('sys.float.padding_level8'), top: $r('sys.float.padding_level8') })

          Column({ space: $r('sys.float.padding_level6') }) {
            DataSourceCard({
              icon: $r('sys.symbol.plus'),
              title: $r('app.string.create_vault'),
              description: $r('app.string.create_vault_source_description'),
              onSelect: () => this.viewModel.openCreateVault(),
            })
            DataSourceCard({
              icon: $r('sys.symbol.folder_badge_plus'),
              title: $r('app.string.open_local_vault'),
              description: $r('app.string.open_local_vault_description'),
              selectable: !this.viewModel.busy,
              onSelect: () => this.viewModel.chooseLocalVault(),
            })
            DataSourceCard({
              icon: $r('sys.symbol.icloud'),
              title: $r('app.string.connect_webdav'),
              description: $r('app.string.connect_webdav_description'),
              onSelect: () => this.viewModel.showWebDavPending(),
            })
          }
          .width('100%')

          StatusText({ status: this.viewModel.status })

          Column({ space: $r('sys.float.padding_level2') }) {
            Text() {
              SymbolSpan($r('sys.symbol.lock_fill'))
              Span(' ')
              Span($r('app.string.privacy_statement'))
            }
            .fontSize($r('sys.float.Body_S'))
            .fontColor($r('sys.color.font_secondary'))

            Text($r('app.string.privacy_statement_secondary'))
              .fontSize($r('sys.float.Body_S'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Center)
        }
        .width('100%')
        .constraintSize({ maxWidth: $r('app.float.content_max_width') })
        .padding($r('sys.float.padding_level8'))
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .onShown(() => this.viewModel.showRoute(ROUTE_WELCOME))
  }
}
