import { uiMaterial } from '@kit.ArkUI'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { VaultEntry, VaultFormat, VaultGroup } from '@ohos/common'
import { ROUTE_TEMPLATE, ROUTE_VAULT } from '../../constants/RouteConstants'
import { PageTopBar, StatusText } from '../../components/PageChrome'
import { VaultBrowseMode } from '../../model/StageOneVaultStore'
import { appRouter } from '../../navigation/AppRouter'
import { VaultAppViewModel, vaultAppViewModel } from '../../viewmodel/VaultAppViewModel'

@ComponentV2
export struct VaultHomePage {
  private readonly viewModel: VaultAppViewModel = vaultAppViewModel

  @Builder
  private browseModeButton(title: Resource, mode: VaultBrowseMode) {
    Button(title)
      .layoutWeight(1)
      .backgroundColor(this.viewModel.browseMode === mode
        ? $r('sys.color.brand') : $r('sys.color.comp_background_primary'))
      .fontColor(this.viewModel.browseMode === mode
        ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
      .onClick(() => this.viewModel.setBrowseMode(mode))
  }

  build() {
    HdsNavDestination() {
      Column({ space: 12 }) {
        PageTopBar({
          title: $r('app.string.vault_home'),
          showLock: true,
          onLock: () => this.viewModel.lockVault(),
        })
        Text(this.viewModel.currentSource().displayName)
          .width('100%')
          .fontSize($r('app.float.text_caption'))
          .fontColor($r('sys.color.font_secondary'))
        if (this.viewModel.currentSource().readOnly) {
          Text($r('app.string.read_only_explanation'))
            .width('100%')
            .fontColor($r('sys.color.alert'))
          if (this.viewModel.currentFormat() === VaultFormat.Kdbx31) {
            Column({ space: 8 }) {
              Text($r('app.string.upgrade_required'))
                .width('100%')
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.font_primary'))
              Text($r('app.string.upgrade_description'))
                .width('100%')
                .fontSize($r('app.float.text_caption'))
                .fontColor($r('sys.color.font_secondary'))
              Button(this.viewModel.busy ? $r('app.string.upgrading') : $r('app.string.backup_and_upgrade'))
                .width('100%')
                .enabled(!this.viewModel.busy)
                .backgroundColor($r('sys.color.brand'))
                .onClick(() => this.viewModel.upgradeLegacyVault())
            }
            .width('100%')
            .padding($r('sys.float.padding_level8'))
            .backgroundColor($r('sys.color.comp_background_primary'))
            .borderRadius($r('sys.float.corner_radius_level4'))
          }
        }
        StatusText({ status: this.viewModel.status })
        TextInput({ placeholder: $r('app.string.search_vault'), text: this.viewModel.searchQuery })
          .width('100%')
          .height($r('app.float.control_height'))
          .backgroundColor($r('sys.color.comp_background_primary'))
          .onChange((value: string) => this.viewModel.setSearchQuery(value))
        Row({ space: 8 }) {
          this.browseModeButton($r('app.string.all_entries'), VaultBrowseMode.All)
          this.browseModeButton($r('app.string.favorites'), VaultBrowseMode.Favorites)
          this.browseModeButton($r('app.string.archived'), VaultBrowseMode.Archived)
        }
        .width('100%')

        Scroll() {
          Row({ space: 8 }) {
            Button($r('app.string.groups'))
              .backgroundColor(this.viewModel.selectedGroupUuid.length === 0
                ? $r('sys.color.brand') : $r('sys.color.comp_background_primary'))
              .fontColor(this.viewModel.selectedGroupUuid.length === 0
                ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
              .onClick(() => this.viewModel.selectBrowseGroup(''))
            ForEach(this.viewModel.groups(), (group: VaultGroup) => {
              Button(group.name)
                .backgroundColor(this.viewModel.selectedGroupUuid === group.uuid
                  ? $r('sys.color.brand') : $r('sys.color.comp_background_primary'))
                .fontColor(this.viewModel.selectedGroupUuid === group.uuid
                  ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
                .onClick(() => this.viewModel.selectBrowseGroup(group.uuid))
            }, (group: VaultGroup) => group.uuid)
          }
        }
        .width('100%')
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)

        if (this.viewModel.entries().length === 0) {
          Column({ space: 12 }) {
            Text($r('app.string.no_entries'))
              .fontSize($r('app.float.text_heading'))
              .fontWeight(FontWeight.Medium)
            Text($r('app.string.no_entries_description'))
              .fontColor($r('sys.color.font_secondary'))
              .textAlign(TextAlign.Center)
            if (!this.viewModel.currentSource().readOnly) {
              Button($r('app.string.new_entry'))
                .backgroundColor($r('sys.color.brand'))
                .onClick(() => appRouter.push(ROUTE_TEMPLATE))
            }
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.viewModel.visibleEntries().length === 0) {
          Column() {
            Text($r('app.string.no_results'))
              .fontSize($r('app.float.text_heading'))
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          List({ space: 8 }) {
            ForEach(this.viewModel.visibleEntries(), (entry: VaultEntry) => {
              ListItem() {
                Row({ space: 12 }) {
                  Text(entry.title.substring(0, 1).toUpperCase())
                    .width($r('app.float.control_height'))
                    .height($r('app.float.control_height'))
                    .textAlign(TextAlign.Center)
                    .fontColor($r('sys.color.font_on_primary'))
                    .backgroundColor($r('sys.color.brand'))
                    .borderRadius($r('sys.float.corner_radius_level4'))
                  Column({ space: 4 }) {
                    Text(entry.title)
                      .width('100%')
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('sys.color.font_primary'))
                    Text(this.viewModel.field(entry, 'UserName'))
                      .width('100%')
                      .fontSize($r('app.float.text_caption'))
                      .fontColor($r('sys.color.font_secondary'))
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  if (entry.favorite) {
                    Text($r('app.string.favorites'))
                      .fontSize($r('app.float.text_caption'))
                      .fontColor($r('sys.color.brand'))
                  }
                }
                .width('100%')
                .padding($r('sys.float.padding_level8'))
                .backgroundColor($r('sys.color.comp_background_primary'))
                .borderRadius($r('sys.float.corner_radius_level4'))
                .onClick(() => this.viewModel.openEntry(entry.uuid))
              }
            }, (entry: VaultEntry) => entry.uuid)
          }
          .width('100%')
          .layoutWeight(1)

          if (!this.viewModel.currentSource().readOnly) {
            Button($r('app.string.new_entry'))
              .width('100%')
              .height($r('app.float.control_height'))
              .backgroundColor($r('sys.color.brand'))
              .onClick(() => appRouter.push(ROUTE_TEMPLATE))
          }
        }
      }
      .width('100%')
      .height('100%')
      .constraintSize({ maxWidth: $r('app.float.content_max_width') })
      .padding({
        top: $r('sys.float.padding_level12'),
        right: $r('sys.float.padding_level12'),
        bottom: $r('app.float.module_content_bottom_padding'),
        left: $r('sys.float.padding_level12'),
      })
      .onTouch(() => this.viewModel.recordActivity())
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .onBackPressed(() => {
      appRouter.handleRootBack(ROUTE_VAULT)
      return true
    })
  }
}

@Builder
export function vaultHomePageBuilder() {
  VaultHomePage()
}
