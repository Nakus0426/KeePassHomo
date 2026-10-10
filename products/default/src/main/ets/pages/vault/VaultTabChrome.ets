import { SymbolGlyphModifier, uiMaterial } from '@kit.ArkUI'
import { HdsNavigationMenuItemOptions, IconStyleMode } from '@kit.UIDesignKit'
import { AnimationTokens, VaultGroup } from '@ohos/common'
import { appRouter } from '../../navigation/AppRouter'
import { AppViewModel, appViewModel } from '../../viewmodel/AppViewModel'
import { appSessionState, AppSessionState } from '../../state/AppSessionState'
import { ImmersiveLayoutState, immersiveLayoutState } from '../../state/ImmersiveLayoutState'
import { VaultBrowseMode } from '../../model/StageOneVaultStore'
import { vaultHomeViewModel, VaultHomeViewModel } from '../../viewmodel/VaultHomeViewModel'
import { ROUTE_SEARCH } from '../../constants/RouteConstants'
import { ModuleTabChrome } from '../../components/ModuleTabChrome'
import { ResUtil } from '@pura/harmony-utils'
import { EntryGroupPicker } from './EntryGroupPicker'

const SWITCH_BUTTON_MAX_WIDTH = '50%'

// 组名上限 64 字，行内筛选器只保留固定字符宽度的文本，超出省略。
const GROUP_LABEL_MAX_CHARS: number = 10

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
  @Local private immersiveLayout: ImmersiveLayoutState = immersiveLayoutState
  @Local private groupPickerVisible: boolean = false
  // 分组筛选器外观是 Select，实测尺寸用于让覆盖层与药丸严丝合缝（Select 只作外观，不参与交互）。
  @Local private groupFilterPillWidth: number = 0
  @Local private groupFilterPillHeight: number = 0
  // 返回 true 表示本次返回已被消费，半模态不收起。
  private groupPickerBackHandler: (() => boolean) | undefined = undefined
  private readonly viewModel: AppViewModel = appViewModel
  private readonly sheetMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
  })

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

  // 锁定时不读分组树（store 在锁定态会抛错）；根分组即「全部分组」，其子树覆盖全库。
  @Computed
  private get groupFilterLabel(): string {
    if (this.session.vaultLocked) {
      return ResUtil.getStringSync($r('app.string.all_groups'))
    }
    const group: VaultGroup = this.viewModel.requireGroup(this.home.selectedGroupUuids[0])
    return group.uuid === this.viewModel.rootGroup().uuid
      ? ResUtil.getStringSync($r('app.string.all_groups'))
      : group.name
  }

  @Computed
  private get groupLabelMaxWidth(): string {
    const fontSizeVp: number = this.getUIContext().px2vp(ResUtil.getNumber($r('sys.float.Body_M').id))
    return `${fontSizeVp * GROUP_LABEL_MAX_CHARS}fp`
  }

  @Computed
  private get groupPickerBottomOffset(): number {
    return this.getUIContext().px2vp(this.immersiveLayout.bottomAvoidAreaHeightPx)
  }

  // 确认选中即筛选条件；选外层容器组与根分组同义，都由 groupFilterLabel 显示为「全部分组」。
  private pickGroup(groupUuid: string): void {
    this.home.selectBrowseGroups([groupUuid])
    this.groupPickerVisible = false
  }

  // 返回键、边缘返回手势、导航栏返回都归入 PRESS_BACK，先交给选择器消费；其余原因按默认关闭。
  private onGroupPickerWillDismiss(action: DismissSheetAction): void {
    const backHandler: (() => boolean) | undefined = this.groupPickerBackHandler
    if (action.reason === DismissReason.PRESS_BACK && backHandler !== undefined && backHandler()) {
      return
    }
    action.dismiss()
  }

  @Computed
  private get groupFilterOptions(): SelectOption[] {
    return [{ value: this.groupFilterLabel }]
  }

  // 与类型筛选器同款外观只能由 Select 自身给出：内置下三角箭头、按钮文本度量与左右内边距都在组件内部。
  // Select 在自量容器里量不出宽度，故外层用 layoutWeight 给出确定宽度；点击由等尺寸覆盖层消费（Block 挡住下层 Select）。
  @Builder
  private groupFilterButton() {
    Stack({ alignContent: Alignment.End }) {
      Select(this.groupFilterOptions)
        .selected(0)
        .value(this.groupFilterLabel)
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
        .constraintSize({ maxWidth: this.groupLabelMaxWidth })
        .focusable(false)
        .accessibilityLevel('no')
        .onSizeChange((_oldSize: SizeOptions, newSize: SizeOptions) => {
          this.groupFilterPillWidth = newSize.width as number
          this.groupFilterPillHeight = newSize.height as number
        })

      Button()
        .width(this.groupFilterPillWidth)
        .height(this.groupFilterPillHeight)
        .type(ButtonType.Normal)
        .backgroundColor(Color.Transparent)
        .stateEffect(false)
        .hitTestBehavior(HitTestMode.Block)
        .accessibilityText(this.groupFilterLabel)
        .onClick(() => this.groupPickerVisible = true)
    }
    .layoutWeight(1)
  }

  @Builder
  private browseModeSelect() {
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

  // 选择器自带标题栏与菜单，半模态壳只配容器参数；与编辑半模态同高，故不设挡位。
  @Builder
  private groupPickerSheet() {
    EntryGroupPicker({
      initialGroupUuid: this.home.selectedGroupUuids[0],
      bottomOffset: this.groupPickerBottomOffset,
      onPicked: (groupUuid: string) => this.pickGroup(groupUuid),
      onClose: () => this.groupPickerVisible = false,
      onActivity: () => this.viewModel.recordActivity(),
      onBackHandler: (handler: () => boolean) => this.groupPickerBackHandler = handler,
    })
  }

  build() {
    Row({ space: $r('sys.float.padding_level4') }) {
      this.groupFilterButton()
      this.browseModeSelect()
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
    .alignItems(VerticalAlign.Center)
    .padding({
      left: $r('sys.float.titlebar_backbutton_margin_left'),
      right: $r('sys.float.titlebar_backbutton_margin_left'),
    })
    .bindSheet($$this.groupPickerVisible, this.groupPickerSheet(), {
      dragBar: true,
      backgroundColor: Color.Transparent,
      systemMaterial: this.sheetMaterial,
      showClose: false,
      onWillDismiss: (action: DismissSheetAction) => this.onGroupPickerWillDismiss(action),
      onDisappear: () => {
        this.groupPickerVisible = false
        this.groupPickerBackHandler = undefined
      },
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
      type: IconStyleMode.SMALL,
      label: $r('app.string.search'),
      action: (): void => {
        appRouter.push(ROUTE_SEARCH)
      },
    },
  }],
}
