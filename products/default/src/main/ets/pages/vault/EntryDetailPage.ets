import { HdsNavDestination } from '@kit.UIDesignKit'
import { ROUTE_ENTRY_DETAIL } from '../../constants/RouteConstants'
import { PageTopBar } from '../../components/PageChrome'
import { appRouter } from '../../navigation/AppRouter'
import { VaultAppViewModel, vaultAppViewModel } from '../../viewmodel/VaultAppViewModel'

@ComponentV2
export struct EntryDetailPage {
  private readonly viewModel: VaultAppViewModel = vaultAppViewModel

  @Builder
  private detailField(label: Resource, value: string) {
    Column({ space: 8 }) {
      Text(label)
        .width('100%')
        .fontSize($r('app.float.text_caption'))
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: 8 }) {
        Text(value)
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
        if (value.length > 0) {
          Button($r('app.string.copy'))
            .backgroundColor(Color.Transparent)
            .fontColor($r('sys.color.brand'))
            .onClick(() => this.viewModel.copyValue(value))
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level4'))
  }

  @Builder
  private passwordField(value: string) {
    Column({ space: 8 }) {
      Text($r('app.string.password'))
        .width('100%')
        .fontSize($r('app.float.text_caption'))
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: 8 }) {
        Text(this.viewModel.showEntryPassword ? value : $r('app.string.password_hidden'))
          .layoutWeight(1)
          .fontSize($r('sys.float.Body_L'))
          .fontColor($r('sys.color.font_primary'))
        Button(this.viewModel.showEntryPassword ? $r('app.string.hide') : $r('app.string.show'))
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.brand'))
          .onClick(() => this.viewModel.showEntryPassword
            ? this.viewModel.hidePasswords() : this.viewModel.revealPassword(ROUTE_ENTRY_DETAIL))
        Button($r('app.string.copy'))
          .backgroundColor(Color.Transparent)
          .fontColor($r('sys.color.brand'))
          .onClick(() => this.viewModel.copyValue(value))
      }
      .width('100%')
    }
    .width('100%')
    .padding($r('sys.float.padding_level8'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('sys.float.corner_radius_level4'))
  }

  build() {
    HdsNavDestination() {
      Column({ space: 16 }) {
        PageTopBar({
          title: $r('app.string.login_template'),
          showBack: true,
          onBack: () => appRouter.pop(),
        })
        Text(this.viewModel.entry(this.viewModel.selectedEntryUuid).title)
          .width('100%')
          .fontSize($r('sys.float.Title_L'))
          .fontWeight(FontWeight.Bold)
        Text(this.viewModel.entry(this.viewModel.selectedEntryUuid).groupPath)
          .width('100%')
          .fontColor($r('sys.color.font_secondary'))
        Row({ space: 8 }) {
          Button(this.viewModel.entry(this.viewModel.selectedEntryUuid).favorite
            ? $r('app.string.remove_favorite') : $r('app.string.add_favorite'))
            .enabled(!this.viewModel.busy && !this.viewModel.currentSource().readOnly)
            .backgroundColor($r('sys.color.comp_emphasize_secondary'))
            .fontColor($r('sys.color.brand'))
            .onClick(() => this.viewModel.toggleFavorite())
          Button(this.viewModel.entry(this.viewModel.selectedEntryUuid).archived
            ? $r('app.string.restore_entry') : $r('app.string.archive_entry'))
            .enabled(!this.viewModel.busy && !this.viewModel.currentSource().readOnly)
            .backgroundColor($r('sys.color.comp_background_primary'))
            .fontColor($r('sys.color.font_primary'))
            .onClick(() => this.viewModel.toggleArchived())
        }
        .width('100%')

        this.detailField($r('app.string.username'),
          this.viewModel.field(this.viewModel.entry(this.viewModel.selectedEntryUuid), 'UserName'))
        this.passwordField(
          this.viewModel.field(this.viewModel.entry(this.viewModel.selectedEntryUuid), 'Password'))
        this.detailField($r('app.string.website'),
          this.viewModel.field(this.viewModel.entry(this.viewModel.selectedEntryUuid), 'URL'))
        this.detailField($r('app.string.notes'),
          this.viewModel.field(this.viewModel.entry(this.viewModel.selectedEntryUuid), 'Notes'))
        if (this.viewModel.entry(this.viewModel.selectedEntryUuid).tags.length > 0) {
          this.detailField($r('app.string.tags'),
            this.viewModel.entry(this.viewModel.selectedEntryUuid).tags.join(', '))
        }
        if (this.viewModel.clipboardSeconds > 0) {
          Text($r('app.string.copied_countdown', this.viewModel.clipboardSeconds))
            .width('100%')
            .fontColor($r('sys.color.confirm'))
            .textAlign(TextAlign.Center)
        }
        Blank()
        if (!this.viewModel.currentSource().readOnly) {
          Button($r('app.string.edit'))
            .width('100%')
            .height($r('app.float.control_height'))
            .backgroundColor($r('sys.color.brand'))
            .onClick(() => this.viewModel.startEditEntry())
        }
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding($r('sys.float.padding_level12'))
      .onTouch(() => this.viewModel.recordActivity())
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}

@Builder
export function entryDetailPageBuilder() {
  EntryDetailPage()
}
