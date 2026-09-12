import {
  ChipGroupV2,
  ChipGroupV2ItemConfig,
  ChipGroupV2Items,
  ChipGroupV2ItemStyle,
  ChipGroupV2Padding,
  ChipGroupV2Space,
  TextModifier,
  uiMaterial,
} from '@kit.ArkUI'
import { HdsNavigationMenuItemOptions } from '@kit.UIDesignKit'
import { AnimationTokens, VaultGroup } from '@ohos/common'
import { appRouter } from '../../navigation/AppRouter'
import { appViewModel } from '../../viewmodel/AppViewModel'
import { VaultBrowseMode } from '../../model/StageOneVaultStore'
import { vaultHomeViewModel, VaultHomeViewModel } from '../../viewmodel/VaultHomeViewModel'
import { ROUTE_SEARCH } from '../../constants/RouteConstants'
import { ModuleTabChrome } from '../../components/ModuleTabChrome'

const SWITCH_BUTTON_MAX_WIDTH = '50%'
const FILTER_TYPE_MAX_WIDTH = '50%'

class GroupChipLabelModifier extends TextModifier {
  applyNormalAttribute(instance: TextAttribute): void {
    instance.maxLines(1)
    instance.textOverflow({ overflow: TextOverflow.Ellipsis })
    instance.constraintSize({ maxWidth: $r('app.float.vault_group_chip_max_width') })
  }
}

function browseModeLabel(mode: VaultBrowseMode): ResourceStr {
  if (mode === VaultBrowseMode.Favorites) {
    return $r('app.string.favorites')
  }
  if (mode === VaultBrowseMode.Archived) {
    return $r('app.string.archived')
  }
  return $r('app.string.all_entries')
}

function browseModeIndex(mode: VaultBrowseMode): number {
  if (mode === VaultBrowseMode.Favorites) {
    return 1
  }
  if (mode === VaultBrowseMode.Archived) {
    return 2
  }
  return 0
}

function browseModeAtIndex(index: number): VaultBrowseMode {
  if (index === 1) {
    return VaultBrowseMode.Favorites
  }
  if (index === 2) {
    return VaultBrowseMode.Archived
  }
  return VaultBrowseMode.All
}

@ComponentV2
struct VaultSwitchButton {
  @Local private pressed: boolean = false

  @Computed
  get contentColor(): ResourceColor {
    return this.pressed ? $r('sys.color.brand_font') : $r('sys.color.font_secondary')
  }

  build() {
    Button() {
      Row({ space: $r('sys.float.padding_level2') }) {
        Text(appViewModel.currentSource().displayName)
          .fontSize($r('sys.float.Body_M'))
          .fontColor(this.contentColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .animation({
            duration: AnimationTokens.STATE_TRANSITION_DURATION,
            curve: AnimationTokens.STATE_TRANSITION_CURVE,
          })
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize($r('sys.float.Body_M'))
          .fontColor([this.contentColor])
          .animation({
            duration: AnimationTokens.STATE_TRANSITION_DURATION,
            curve: AnimationTokens.STATE_TRANSITION_CURVE,
          })
      }
    }
    .buttonStyle(ButtonStyleMode.TEXTUAL)
    .constraintSize({ maxWidth: SWITCH_BUTTON_MAX_WIDTH })
    .stateEffect(false)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressed = true
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressed = false
      }
    })
    .onClick(() => appViewModel.chooseAnotherVault())
  }
}

@Builder
function vaultTitleRowBuilder() {
  Column({ space: $r('sys.float.padding_level2') }) {
    Text($r('app.string.vault_home'))
      .fontSize($r('sys.float.Title_M'))
      .fontWeight(FontWeight.Bold)
      .fontColor($r('sys.color.font_primary'))
      .maxLines(1)

    if (appViewModel.hasRecentVault()) {
      VaultSwitchButton()
    }
  }
  .width('100%')
  .height('100%')
  .alignItems(HorizontalAlign.Start)
  .justifyContent(FlexAlign.Center)
  .padding({ left: $r('sys.float.titlebar_backbutton_margin_left') })
}

@ComponentV2
struct VaultFilterRow {
  @Local private home: VaultHomeViewModel = vaultHomeViewModel

  @Computed
  private get modeOptions(): SelectOption[] {
    const options: SelectOption[] = [
      { value: $r('app.string.all_entries') },
      { value: $r('app.string.favorites') },
      { value: $r('app.string.archived') },
    ]
    return options
  }

  @Computed
  private get groupItems(): ChipGroupV2Items {
    const configs: ChipGroupV2ItemConfig[] = []
    for (const group of appViewModel.topLevelGroups()) {
      configs.push({
        label: { text: group.name, modifier: new GroupChipLabelModifier() },
      })
    }
    return new ChipGroupV2Items(configs)
  }

  @Computed
  private get selectedGroupIndexes(): number[] {
    const groups: VaultGroup[] = appViewModel.topLevelGroups()
    const indexes: number[] = []
    for (let index = 0; index < groups.length; index++) {
      if (this.home.selectedGroupUuids.includes(groups[index].uuid)) {
        indexes.push(index)
      }
    }
    return indexes
  }

  @Computed
  private get chipItemStyle(): ChipGroupV2ItemStyle {
    return new ChipGroupV2ItemStyle({
      backgroundSystemMaterial: new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
        interactive: true,
      }),
      selectedBackgroundSystemMaterial: new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
        materialColor: $r('sys.color.brand'),
        interactive: true,
      }),
    })
  }

  private selectGroups(indexes: number[]): void {
    const groups: VaultGroup[] = appViewModel.topLevelGroups()
    this.home.selectBrowseGroups(indexes.map((index: number): string => groups[index].uuid))
  }

  build() {
    Stack() {
      Select(this.modeOptions)
        .selected(browseModeIndex(this.home.browseMode))
        .value(browseModeLabel(this.home.browseMode))
        .font({ size: $r('sys.float.Body_M'), weight: FontWeight.Regular })
        .fontColor($r('sys.color.font_primary'))
        .constraintSize({ maxWidth: FILTER_TYPE_MAX_WIDTH })
        .systemMaterial(new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
          interactive: true,
        }))
        .position({ top: '50%', left: $r('sys.float.titlebar_backbutton_margin_left') })
        .translate({ y: '-50%' })
        .onSelect((index: number) => this.home.setBrowseMode(browseModeAtIndex(index)))

      Scroll() {
        ChipGroupV2({
          items: this.groupItems,
          itemStyle: this.chipItemStyle,
          selectedIndexes: this.selectedGroupIndexes,
          multiple: true,
          chipGroupSpace: new ChipGroupV2Space({
            itemSpace: 8,
            startSpace: $r('sys.float.padding_level4'),
            endSpace: 0,
          }),
          chipGroupPadding: new ChipGroupV2Padding({ top: 0, bottom: 0 }),
          onChange: (indexes: number[]) => this.selectGroups(indexes),
        })
          .height($r('sys.float.titlebar_icon_background_height'))
      }
      .layoutWeight(1)
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }
}

@Builder
function vaultFilterRowBuilder() {
  VaultFilterRow()
}

export const vaultTabChrome: ModuleTabChrome = {
  titleRowBuilder: wrapBuilder(vaultTitleRowBuilder),
  bottomRowBuilder: wrapBuilder(vaultFilterRowBuilder),
  menuItems: (): HdsNavigationMenuItemOptions[] => [{
    content: {
      icon: $r('sys.symbol.magnifyingglass'),
      label: $r('app.string.search'),
      action: (): void => {
        appRouter.push(ROUTE_SEARCH)
      },
    },
  }],
}
