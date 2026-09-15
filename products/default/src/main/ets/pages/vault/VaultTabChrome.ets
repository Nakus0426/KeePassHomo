import {
  ChipGroupV2,
  ChipGroupV2ItemConfig,
  ChipGroupV2Items,
  ChipGroupV2ItemStyle,
  ChipGroupV2Padding,
  ChipGroupV2Space,
  SymbolGlyphModifier,
  TextModifier,
  uiMaterial,
} from '@kit.ArkUI'
import { HdsNavigationMenuItemOptions } from '@kit.UIDesignKit'
import { AnimationTokens, VaultGroup } from '@ohos/common'
import { appRouter } from '../../navigation/AppRouter'
import { appViewModel } from '../../viewmodel/AppViewModel'
import { appSessionState, AppSessionState } from '../../state/AppSessionState'
import { VaultBrowseMode } from '../../model/StageOneVaultStore'
import { vaultHomeViewModel, VaultHomeViewModel } from '../../viewmodel/VaultHomeViewModel'
import { ROUTE_SEARCH } from '../../constants/RouteConstants'
import { ModuleTabChrome } from '../../components/ModuleTabChrome'
import { ResUtil } from '@pura/harmony-utils'

const SWITCH_BUTTON_MAX_WIDTH = '50%'
const CHIP_LABEL_MAX_CHARS: number = 10

class GroupChipLabelModifier extends TextModifier {
  private maxWidth: string

  constructor(maxWidth: string) {
    super()
    this.maxWidth = maxWidth
  }

  applyNormalAttribute(instance: TextAttribute): void {
    instance.maxLines(1)
    instance.textOverflow({ overflow: TextOverflow.Ellipsis })
    instance.constraintSize({ maxWidth: this.maxWidth })
  }
}

function browseModeLabel(mode: VaultBrowseMode): ResourceStr {
  if (mode === VaultBrowseMode.Favorites) {
    return $r('app.string.favorited')
  }
  if (mode === VaultBrowseMode.Archived) {
    return $r('app.string.archived')
  }
  return $r('app.string.all_entry')
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
struct VaultFilter {
  @Local private home: VaultHomeViewModel = vaultHomeViewModel
  @Local private session: AppSessionState = appSessionState

  private generateModeOptionIcon(mode: VaultBrowseMode, activated: boolean): SymbolGlyphModifier {
    const modeIconMap = new Map([
      [VaultBrowseMode.All, $r('sys.symbol.square_grid_2x2')],
      [VaultBrowseMode.Favorites, $r('sys.symbol.star')],
      [VaultBrowseMode.Archived, $r('sys.symbol.archivebox')],
    ])
    const modeIconActivedMap = new Map([
      [VaultBrowseMode.All, $r('sys.symbol.square_fill_grid_2x2')],
      [VaultBrowseMode.Favorites, $r('sys.symbol.star_fill')],
      [VaultBrowseMode.Archived, $r('sys.symbol.archivebox_fill')],
    ])
    const icon = activated ? modeIconActivedMap.get(mode) : modeIconMap.get(mode)

    return new SymbolGlyphModifier(icon)
      .fontSize($r('sys.float.Subtitle_L'))
      .fontColor([activated
        ? $r('sys.color.ohos_id_color_text_primary_activated')
        : $r('sys.color.ohos_id_color_text_primary')])
  }

  @Computed
  private get modeOptions(): SelectOption[] {
    const mode: VaultBrowseMode = this.home.browseMode
    const options: SelectOption[] = [
      {
        value: $r('app.string.all_entry'),
        symbolIcon: this.generateModeOptionIcon(VaultBrowseMode.All, mode === VaultBrowseMode.All),
      },
      {
        value: $r('app.string.favorited'),
        symbolIcon: this.generateModeOptionIcon(VaultBrowseMode.Favorites, mode === VaultBrowseMode.Favorites),
      },
      {
        value: $r('app.string.archived'),
        symbolIcon: this.generateModeOptionIcon(VaultBrowseMode.Archived, mode === VaultBrowseMode.Archived),
      },
    ]
    return options
  }

  @Computed
  private get chipLabelMaxWidth(): string {
    const fontSizeVp = this.getUIContext().px2vp(ResUtil.getNumber($r('sys.float.chip_normal_font_size').id))
    return `${fontSizeVp * CHIP_LABEL_MAX_CHARS}fp`
  }

  @Computed
  private get topLevelGroups(): VaultGroup[] {
    if (this.session.vaultLocked) {
      return []
    }
    return appViewModel.topLevelGroups()
  }

  @Computed
  private get groupItems(): ChipGroupV2Items {
    const labelModifier = new GroupChipLabelModifier(this.chipLabelMaxWidth)
    const configs: ChipGroupV2ItemConfig[] = []
    for (const group of this.topLevelGroups) {
      configs.push({ label: { text: group.name, modifier: labelModifier } })
    }
    return new ChipGroupV2Items(configs)
  }

  @Computed
  private get selectedGroupIndexes(): number[] {
    const groups: VaultGroup[] = this.topLevelGroups
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
        materialColor: Color.White,
        applyShadow: false,
      }),
      selectedBackgroundSystemMaterial: new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
        materialColor: $r('sys.color.brand'),
        interactive: true,
        applyShadow: false,
      }),
    })
  }

  private selectGroups(indexes: number[]): void {
    const groups: VaultGroup[] = this.topLevelGroups
    this.home.selectBrowseGroups(indexes.map((index: number): string => groups[index].uuid))
  }

  @Builder
  selectSuffix(): void {
    Select(this.modeOptions)
      .selected(browseModeIndex(this.home.browseMode))
      .value(browseModeLabel(this.home.browseMode))
      .font({ size: $r('sys.float.Body_M'), weight: FontWeight.Regular })
      .optionFont({ size: $r('sys.float.Body_M') })
      .fontColor($r('sys.color.font_primary'))
      .controlSize(ControlSize.SMALL)
      .systemMaterial(new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
        interactive: true,
        applyShadow: false,
      }))
      .menuSystemMaterial(new uiMaterial.ImmersiveMaterial({ style: uiMaterial.ImmersiveStyle.THICK }))
      .onSelect((index: number) => this.home.setBrowseMode(browseModeAtIndex(index)))
  }

  build() {
    ChipGroupV2({
      items: this.groupItems,
      itemStyle: this.chipItemStyle,
      selectedIndexes: this.selectedGroupIndexes,
      multiple: true,
      chipGroupSpace: new ChipGroupV2Space({
        itemSpace: 8,
        startSpace: $r('sys.float.titlebar_backbutton_margin_left'),
        endSpace: $r('sys.float.titlebar_backbutton_margin_left'),
      }),
      chipGroupPadding: new ChipGroupV2Padding({ top: 0, bottom: 0 }),
      onChange: (indexes: number[]) => this.selectGroups(indexes),
      suffix: () => this.selectSuffix(),
    })
  }
}

@Builder
function vaultFilterRowBuilder() {
  VaultFilter()
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
