import { UIUtils } from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import {
  AnimationTokens,
  AppToast,
  MemorableCase,
  PasswordStrengthCalculator,
  StrengthLevel,
} from '@ohos/common'
import { LogUtil } from '@pura/harmony-utils'
import { DsButton, DsButtonSize, DsButtonTone } from '../../components/DsButton'
import { DsSegmentedSwitch, DsSegmentedSwitchItem } from '../../components/DsSegmentedSwitch'
import { DsStrengthMeter } from '../../components/DsStrengthMeter'
import { DsTabs, DsTabsItem, DsTabsSize } from '../../components/DsTabs'
import { strengthLabel } from '../../components/PasswordStrengthIndicator'
import { GeneratorMode, GeneratorViewModel } from '../../viewmodel/GeneratorViewModel'
import { appViewModel } from '../../viewmodel/AppViewModel'
import { PASSWORD_FONT_FAMILY } from '../../constants/FontConstants'

// 起始帧必须独立渲染一帧才能成为动画起点：与 animateTo 写在同一帧时起点会被同步刷新吃掉；这是时序常量非视觉 token。
const TAB_TRANSITION_START_FRAME_DELAY: number = 16
// Stepper / Switch 公共组件尚未落地，先用现有控件按其设计位置占位。
const SETTING_CONTROL_WIDTH_VP: number = 100
const SETTING_SWITCH_WIDTH_VP: number = 36
const SETTING_SWITCH_HEIGHT_VP: number = 20
const SETTING_LABEL_LETTER_SPACING: number = 0.2

// 设置行左侧「标签 + 可选描述」列，GeneratorSliderRow / GeneratorToggleRow 复用，避免结构重复。
@Builder
function generatorSettingLabel(label: ResourceStr, description: ResourceStr | undefined) {
  Column({ space: $r('app.float.ds_space_2') }) {
    Text(label)
      .fontSize($r('app.float.ds_font_label_md'))
      .fontWeight(600)
      .fontColor($r('app.color.ds_text_primary'))
      .letterSpacing(SETTING_LABEL_LETTER_SPACING)
    if (description !== undefined) {
      Text(description)
        .fontSize($r('app.float.ds_font_micro'))
        .fontColor($r('app.color.ds_text_tertiary'))
        .fontFamily(PASSWORD_FONT_FAMILY)
    }
  }
  .layoutWeight(1)
  .alignItems(HorizontalAlign.Start)
}

@ComponentV2
struct GeneratorSliderRow {
  @Param label: ResourceStr = ''
  @Param description: ResourceStr | undefined = undefined
  @Param value: number = 0
  @Param min: number = 0
  @Param max: number = 100
  @Param step: number = 1
  @Event onChange: (value: number) => void = () => {
  }

  build() {
    Row({ space: $r('app.float.ds_space_md') }) {
      generatorSettingLabel(this.label, this.description)

      Slider({
        value: this.value,
        min: this.min,
        max: this.max,
        step: this.step,
        style: SliderStyle.InSet,
      })
        .width(SETTING_CONTROL_WIDTH_VP)
        .height($r('app.float.ds_seg_height'))
        .showTips(true, this.value.toString())
        .showSteps(true)
        .onChange((value: number) => this.onChange(value))
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

@ComponentV2
struct GeneratorToggleRow {
  @Param label: ResourceStr = ''
  @Param description: ResourceStr | undefined = undefined
  @Param value: boolean = false
  @Event onChange: (value: boolean) => void = () => {
  }

  build() {
    Row({ space: $r('app.float.ds_space_md') }) {
      generatorSettingLabel(this.label, this.description)

      Toggle({ type: ToggleType.Switch, isOn: this.value })
        .width(SETTING_SWITCH_WIDTH_VP)
        .height(SETTING_SWITCH_HEIGHT_VP)
        .selectedColor($r('app.color.ds_primary'))
        .switchPointColor($r('app.color.ds_on_primary'))
        .onChange((value: boolean) => this.onChange(value))
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

@ComponentV2
struct GeneratorSegmentRow {
  @Param label: ResourceStr = ''
  @Param items: DsSegmentedSwitchItem[] = []
  @Param selectedIndex: number = 0
  @Event onSelect: (index: number) => void = () => {
  }

  build() {
    Column({ space: $r('app.float.ds_space_6') }) {
      Text(this.label)
        .fontSize($r('app.float.ds_font_label_sm'))
        .fontWeight(600)
        .fontColor($r('app.color.ds_text_tertiary'))
        .letterSpacing(SETTING_LABEL_LETTER_SPACING)

      DsSegmentedSwitch({
        items: this.items,
        selectedIndex: this.selectedIndex,
        onSelect: (index: number) => this.onSelect(index),
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

interface GeneratorContentOperations {
  copyPassword(): void

  getCurrentPassword(): string
}

export class GeneratorContentController {
  private component: GeneratorContentOperations | undefined = undefined

  bind(component: GeneratorContentOperations): void {
    this.component = component
  }

  unbind(): void {
    this.component = undefined
  }

  copyPassword(): void {
    this.component!.copyPassword()
  }

  getCurrentPassword(): string {
    return this.component!.getCurrentPassword()
  }
}

// GeneratorPage 与标题栏复制菜单共享同一实例
export const generatorContentController: GeneratorContentController = new GeneratorContentController()

@ComponentV2
export struct GeneratorContent {
  @Param viewModel: GeneratorViewModel = new GeneratorViewModel()
  @Param controller: GeneratorContentController = new GeneratorContentController()
  @Param topOffset: number = 0
  @Param bottomOffset: number = 0
  @Param onSheet: boolean = false
  // 宿主可传入 Scroller 控制参数区滚动；未传入时用默认实例。
  @Param scroller: Scroller = new Scroller()
  @Event onActivity: () => void = () => {
  }
  @Local private currentTabIndex: number = GeneratorMode.Random
  @Local private tabsWidth: number = 0
  @Local private tabOpacity: number[] = [1, 0, 0]
  @Local private tabOffsetX: number[] = [0, 0, 0]
  @Local private tabZIndex: number[] = [1, 0, 0]
  private static readonly TAB_MODES: GeneratorMode[] =
    [GeneratorMode.Random, GeneratorMode.Memorable, GeneratorMode.Pin]
  private static readonly TAB_TRANSITION_OFFSET_RATIO: number = 0.2
  private static readonly CASE_MODES: MemorableCase[] =
    [MemorableCase.Upper, MemorableCase.Lower, MemorableCase.Capitalized]
  private static readonly SEPARATORS: string[] = ['-', '_', '.', '']
  private readonly tabItems: DsTabsItem[] = [
    { label: $r('app.string.random_password') },
    { label: $r('app.string.memorable_password') },
    { label: $r('app.string.pin_code') },
  ]
  private readonly separatorItems: DsSegmentedSwitchItem[] = [
    { label: '-', enabled: true },
    { label: '_', enabled: true },
    { label: '.', enabled: true },
    { label: $r('app.string.no_separator'), enabled: true },
  ]
  private readonly caseItems: DsSegmentedSwitchItem[] = [
    { label: $r('app.string.uppercase'), enabled: true },
    { label: $r('app.string.lowercase'), enabled: true },
    { label: $r('app.string.capitalize'), enabled: true },
  ]
  private readonly tabsController: TabsController = new TabsController()
  // 起始帧定时器，卸载时需要清理。
  private startFrameTimer: number = -1

  aboutToAppear(): void {
    this.controller.bind(this)
    if (this.viewModel.mode !== GeneratorMode.Random) {
      this.viewModel.setMode(GeneratorMode.Random)
    }
  }

  aboutToDisappear(): void {
    clearTimeout(this.startFrameTimer)
    this.controller.unbind()
  }

  @Monitor('viewModel.status')
  onStatusChanged(): void {
    if (this.viewModel.status.length > 0) {
      // 生成器内容在生成器半模态内，默认模式提示会被半模态压住。
      AppToast.showAboveSheets(this.getUIContext(), this.viewModel.status)
    }
  }

  @Computed
  get hasValue(): boolean {
    return this.viewModel.value.length > 0
  }

  @Computed
  get strengthLevel(): StrengthLevel {
    return PasswordStrengthCalculator.calculate(this.viewModel.value)
  }

  @Computed
  get strengthText(): ResourceStr {
    return strengthLabel(this.strengthLevel)
  }

  @Computed
  get strengthColor(): ResourceColor {
    if (this.strengthLevel <= StrengthLevel.Weak) {
      return $r('app.color.ds_error')
    }
    return this.strengthLevel === StrengthLevel.Medium
      ? $r('app.color.ds_warning') : $r('app.color.ds_success')
  }

  copyPassword(): void {
    if (this.viewModel.value.length === 0) {
      return
    }
    appViewModel.copyValue(this.viewModel.value)
    AppToast.showAboveSheets(this.getUIContext(), $r('app.string.copy_success'))
  }

  getCurrentPassword(): string {
    return this.viewModel.value
  }

  @Computed
  get separatorIndex(): number {
    return GeneratorContent.SEPARATORS.indexOf(this.viewModel.memorableSeparator)
  }

  @Computed
  get caseIndex(): number {
    return GeneratorContent.CASE_MODES.indexOf(this.viewModel.memorableCase)
  }

  private get tabTransitionOffset(): number {
    return this.tabsWidth * GeneratorContent.TAB_TRANSITION_OFFSET_RATIO
  }

  // 只写模式：页签切换统一由 changeIndex 发起，Tabs 不绑定 index，避免重渲染打断转场。
  private selectMode(index: number): void {
    this.viewModel.setMode(GeneratorContent.TAB_MODES[index])
    this.tabsController.changeIndex(index)
  }

  private tabContentTransition(from: number, to: number): TabContentAnimatedTransition {
    if (from === to) {
      return {
        timeout: 0,
        transition: (proxy: TabContentTransitionProxy) => proxy.finishTransition(),
      }
    }

    const direction: number = to > from ? 1 : -1
    const offset: number = this.tabTransitionOffset

    return {
      // 超时必须覆盖「起始帧延迟 + 动画时长」，否则 Tabs 会在动画播完前强制结束本次转场。
      timeout: TAB_TRANSITION_START_FRAME_DELAY + AnimationTokens.STATE_TRANSITION_DURATION + 100,
      transition: (proxy: TabContentTransitionProxy) => {
        UIUtils.applySync(() => {
          this.tabOpacity[from] = 1
          this.tabOffsetX[from] = 0
          this.tabOpacity[to] = 0
          this.tabOffsetX[to] = direction * offset
          this.tabZIndex[from] = 0
          this.tabZIndex[to] = 1
        })

        // 起始帧先落地成真实渲染结果，下一帧再改终态，起点才成立。
        this.startFrameTimer = setTimeout(() => {
          this.getUIContext().animateTo({
            duration: AnimationTokens.STATE_TRANSITION_DURATION,
            curve: AnimationTokens.STATE_TRANSITION_CURVE,
            onFinish: () => proxy.finishTransition(),
          }, () => {
            this.tabOpacity[from] = 0
            this.tabOffsetX[from] = -direction * offset
            this.tabOpacity[to] = 1
            this.tabOffsetX[to] = 0
          })
        }, TAB_TRANSITION_START_FRAME_DELAY)
      },
    }
  }

  @Builder
  private dividerBuilder() {
    Divider()
      .color($r('app.color.ds_outline_variant'))
  }

  @Builder
  private randomOptions() {
    Column({ space: $r('app.float.ds_space_md') }) {
      GeneratorSliderRow({
        label: $r('app.string.password_length_value'),
        description: $r('app.string.password_length_range'),
        value: this.viewModel.randomLength,
        min: 8,
        max: 20,
        step: 1,
        onChange: (value: number) => this.viewModel.setRandomLength(value),
      })

      GeneratorSliderRow({
        label: $r('app.string.minimum_digits_value'),
        description: $r('app.string.minimum_count_range'),
        value: this.viewModel.randomMinimumDigits,
        min: 0,
        max: 8,
        step: 1,
        onChange: (value: number) => this.viewModel.setRandomMinimumDigits(value),
      })

      GeneratorSliderRow({
        label: $r('app.string.minimum_symbols_value'),
        description: $r('app.string.minimum_count_range'),
        value: this.viewModel.randomMinimumSymbols,
        min: 0,
        max: 8,
        step: 1,
        onChange: (value: number) => this.viewModel.setRandomMinimumSymbols(value),
      })

      this.dividerBuilder()

      GeneratorToggleRow({
        label: $r('app.string.include_uppercase'),
        description: $r('app.string.charset_uppercase_desc'),
        value: this.viewModel.randomUppercase,
        onChange: (value: boolean) => this.viewModel.setRandomUppercase(value),
      })

      GeneratorToggleRow({
        label: $r('app.string.include_lowercase'),
        description: $r('app.string.charset_lowercase_desc'),
        value: this.viewModel.randomLowercase,
        onChange: (value: boolean) => this.viewModel.setRandomLowercase(value),
      })

      GeneratorToggleRow({
        label: $r('app.string.include_digits'),
        description: $r('app.string.charset_digits_desc'),
        value: this.viewModel.randomDigits,
        onChange: (value: boolean) => this.viewModel.setRandomDigits(value),
      })

      GeneratorToggleRow({
        label: $r('app.string.include_symbols'),
        description: $r('app.string.charset_symbols_desc'),
        value: this.viewModel.randomSymbols,
        onChange: (value: boolean) => this.viewModel.setRandomSymbols(value),
      })

      this.dividerBuilder()

      GeneratorToggleRow({
        label: $r('app.string.exclude_similar'),
        description: $r('app.string.exclude_similar_desc'),
        value: this.viewModel.randomExcludeSimilar,
        onChange: (value: boolean) => this.viewModel.setRandomExcludeSimilar(value),
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .translate({ x: this.tabOffsetX[0] })
  }

  @Builder
  private memorableOptions() {
    Column({ space: $r('app.float.ds_space_md') }) {
      GeneratorSliderRow({
        label: $r('app.string.word_count_value'),
        description: $r('app.string.word_count_range'),
        value: this.viewModel.memorableWordCount,
        min: 3,
        max: 8,
        step: 1,
        onChange: (value: number) => this.viewModel.setMemorableWordCount(value),
      })

      this.dividerBuilder()

      GeneratorSegmentRow({
        label: $r('app.string.separator'),
        items: this.separatorItems,
        selectedIndex: this.separatorIndex,
        onSelect: (index: number) => this.viewModel.setMemorableSeparator(GeneratorContent.SEPARATORS[index]),
      })

      this.dividerBuilder()

      GeneratorSegmentRow({
        label: $r('app.string.letter_case'),
        items: this.caseItems,
        selectedIndex: this.caseIndex,
        onSelect: (index: number) => this.viewModel.setMemorableCase(GeneratorContent.CASE_MODES[index]),
      })

      this.dividerBuilder()

      GeneratorToggleRow({
        label: $r('app.string.append_number'),
        description: $r('app.string.append_number_desc'),
        value: this.viewModel.memorableAppendNumber,
        onChange: (value: boolean) => this.viewModel.setMemorableAppendNumber(value),
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .translate({ x: this.tabOffsetX[1] })
  }

  @Builder
  private pinOptions() {
    Column({ space: $r('app.float.ds_space_md') }) {
      GeneratorSliderRow({
        label: $r('app.string.pin_length_value'),
        description: $r('app.string.pin_length_range'),
        value: this.viewModel.pinLength,
        min: 4,
        max: 12,
        step: 1,
        onChange: (value: number) => this.viewModel.setPinLength(value),
      })

      this.dividerBuilder()

      GeneratorToggleRow({
        label: $r('app.string.avoid_pin_patterns'),
        description: $r('app.string.avoid_pin_patterns_desc'),
        value: this.viewModel.pinAvoidPatterns,
        onChange: (value: boolean) => this.viewModel.setPinAvoidPatterns(value),
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .translate({ x: this.tabOffsetX[2] })
  }

  @Builder
  private passwordPreview() {
    Column({ space: $r('app.float.ds_space_10') }) {
      Row() {
        Text($r('app.string.generate_result'))
          .fontSize($r('app.float.ds_font_micro'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_text_tertiary'))
          .fontFamily(PASSWORD_FONT_FAMILY)
          .letterSpacing(1.2)

        if (this.onSheet) {
          DsButton({
            label: $r('app.string.copy'),
            buttonSize: DsButtonSize.Small,
            tone: DsButtonTone.Default,
            leadingIcon: $r('app.string.symbol_copy'),
            iconSizeOverride: $r('app.float.ds_icon_tiny'),
            onTap: () => this.copyPassword(),
          })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)

      if (this.hasValue) {
        Text(this.viewModel.value)
          .width('100%')
          .maxLines(2)
          .fontSize($r('app.float.ds_font_title_md'))
          .fontWeight(600)
          .fontColor($r('app.color.ds_text_primary'))
          .fontFamily(PASSWORD_FONT_FAMILY)
          .fontFeature("\"liga\" 0")
          .textAlign(TextAlign.Start)
      } else {
        Text($r('app.string.no_candidate'))
          .width('100%')
          .maxLines(2)
          .fontSize($r('app.float.ds_font_title_md'))
          .fontColor($r('app.color.ds_text_secondary'))
          .textAlign(TextAlign.Start)
      }

      Row({ space: $r('app.float.ds_space_md') }) {
        Row() {
          DsStrengthMeter({ password: this.viewModel.value })
        }
        .layoutWeight(1)

        Text(this.strengthText)
          .fontSize($r('app.float.ds_font_label_sm'))
          .fontWeight(600)
          .fontColor(this.strengthColor)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding($r('app.float.ds_space_md'))
    .backgroundColor($r('app.color.ds_surface_low'))
    .alignItems(HorizontalAlign.Start)
  }

  // 页签栏固定在顶部，宽度用于计算切换位移；参数区另起滚动容器。
  @Builder
  private parameterTabsBar() {
    Column() {
      DsTabs({
        items: this.tabItems,
        selectedIndex: this.viewModel.mode,
        tabSize: DsTabsSize.Medium,
        onSelect: (index: number) => this.selectMode(index),
      })
    }
    .width('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.tabsWidth = newValue.width as number
    })
  }

  @Builder
  private parameterTabsBody() {
    Column() {
      Tabs({
        barPosition: BarPosition.Start,
        controller: this.tabsController,
      }) {
        this.tabContent(GeneratorMode.Random)
        this.tabContent(GeneratorMode.Memorable)
        this.tabContent(GeneratorMode.Pin)
      }
      .height('auto')
      .width('100%')
      .scrollable(false)
      .barHeight(0)
      .divider(null)
      .customContentTransition((from: number, to: number) => this.tabContentTransition(from, to))
      .onAppear(() => {
        this.tabsController.preloadItems([0, 1, 2].filter((index: number) => index !== this.currentTabIndex))
          .catch((error: BusinessError) => {
            LogUtil.error(`预加载生成器页签失败，错误码=${error.code}，错误信息=${error.message}`)
          })
      })
      .onChange((index: number) => {
        this.currentTabIndex = index
      })
      .clip(true)
    }
    .width('100%')
    .padding({
      top: $r('app.float.ds_space_16'),
      bottom: $r('app.float.ds_space_16'),
      left: $r('app.float.ds_gutter'),
      right: $r('app.float.ds_gutter'),
    })
  }

  @Builder
  private tabContent(mode: GeneratorMode) {
    TabContent() {
      if (mode === GeneratorMode.Random) {
        this.randomOptions()
      } else if (mode === GeneratorMode.Memorable) {
        this.memorableOptions()
      } else {
        this.pinOptions()
      }
    }
    .align(Alignment.Top)
    .opacity(this.tabOpacity[mode])
    .zIndex(this.tabZIndex[mode])
    .clip(true)
  }

  build() {
    Column() {
      // 固定头部：灰色预览底上探标题栏；预览与页签不随参数区滚动，下拉回弹不再露出空白。
      Column() {
        if (this.topOffset > 0) {
          Column()
            .width('100%')
            .height(this.topOffset)
            .backgroundColor($r('app.color.ds_surface_low'))
        }
        this.passwordPreview()
        this.parameterTabsBar()
      }
      .width('100%')
      .backgroundColor($r('app.color.ds_surface_lowest'))

      Scroll(this.scroller) {
        this.parameterTabsBody()
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor($r('app.color.ds_surface_lowest'))
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
      .clip(true)
      .padding({ bottom: this.bottomOffset })
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.ds_surface_lowest'))
    .onTouch(() => this.onActivity())
  }
}
