import {
  CapsuleSegmentButtonV2,
  SegmentButtonV2ItemOptions,
  SegmentButtonV2Items,
  TabSegmentButtonV2,
  uiMaterial,
  UIUtils,
} from '@kit.ArkUI'
import { BusinessError } from '@kit.BasicServicesKit'
import { AnimationTokens, MemorableCase } from '@ohos/common'
import { LogUtil } from '@pura/harmony-utils'
import { FormItem, LabelPlacement } from '../../components/FormItem'
import { PasswordStrengthIndicator } from '../../components/PasswordStrengthIndicator'
import { GeneratorMode, GeneratorViewModel } from '../../viewmodel/GeneratorViewModel'
import { appViewModel } from '../../viewmodel/AppViewModel'
import { PASSWORD_FONT_FAMILY } from '../../constants/FontConstants'

@ComponentV2
struct SliderFormItem {
  @Param label: ResourceStr | undefined = undefined
  @Param value: number | undefined = undefined
  @Param tips?: string | undefined = undefined
  @Param max?: number | undefined = undefined
  @Param min?: number | undefined = undefined
  @Param step?: number | undefined = undefined
  @Event onChange: (value: number) => void = () => {
  }

  @LocalBuilder
  contentBuilder() {
    Slider({
      value: this.value,
      min: this.min,
      max: this.max,
      step: this.step,
      style: SliderStyle.InSet,
    })
      .width($r('app.float.setting_control_width'))
      .showTips(true, this.tips)
      .showSteps(true)
      .onChange((value: number) => this.onChange(value))
  }

  build() {
    Row() {
      FormItem({ label: this.label, labelPlacement: LabelPlacement.Start, contentBuilder: this.contentBuilder })
    }
    .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level5') })
    .height($r('app.float.setting_row_height'))
  }
}

@ComponentV2
struct ToggleFormItem {
  @Param label: ResourceStr | undefined = undefined
  @Param value: boolean | undefined = undefined
  @Event onChange: (value: boolean) => void = () => {
  }

  @LocalBuilder
  contentBuilder() {
    Toggle({ type: ToggleType.Switch, isOn: this.value })
      .onChange((value: boolean) => this.onChange(value))
  }

  build() {
    Row() {
      FormItem({ label: this.label, labelPlacement: LabelPlacement.Start, contentBuilder: this.contentBuilder })
    }
    .height($r('app.float.setting_row_height'))
    .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })

  }
}

@ComponentV2
struct SegmentButtonFormItem {
  @Param label: ResourceStr | undefined = undefined
  @Param items: SegmentButtonV2Items = new SegmentButtonV2Items([] as SegmentButtonV2ItemOptions[])
  @Param selectedIndex: number = 0
  @Event onChange: (index: number) => void = () => {
  }
  private readonly backgroundMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial(
    {
      style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
      applyShadow: false,
      materialColor: $r('sys.color.progress_track_color'),
    })

  @LocalBuilder
  contentBuilder() {
    CapsuleSegmentButtonV2({
      items: this.items,
      selectedIndex: this.selectedIndex,
      backgroundSystemMaterial: this.backgroundMaterial,
      $selectedIndex: (index: number) => this.onChange(index),
    })
      .width($r('app.float.setting_control_width'))
  }

  build() {
    Row() {
      FormItem({ label: this.label, labelPlacement: LabelPlacement.Start, contentBuilder: this.contentBuilder })
    }
    .height($r('app.float.setting_row_height'))
    .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
  }
}

enum PasswordCharacterKind {
  Letter,
  Number,
  Symbol,
}

interface GeneratorContentOperations {
  copyPassword(): void

  getCurrentPassword(): string
}

interface PasswordTextSegment {
  text: string
  kind: PasswordCharacterKind
  start: number
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

@ComponentV2
export struct GeneratorContent {
  @Param viewModel: GeneratorViewModel = new GeneratorViewModel()
  @Param controller: GeneratorContentController = new GeneratorContentController()
  @Param topOffset: number = 0
  @Param bottomOffset: number = 0
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
    [MemorableCase.Lower, MemorableCase.Capitalized, MemorableCase.Upper]
  private static readonly SEPARATORS: string[] = ['-', '.', '_', '']
  private static readonly SYMBOL_PATTERN: RegExp = /[^\w]/
  private readonly tabItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: $r('app.string.random_password') },
    { text: $r('app.string.memorable_password') },
    { text: $r('app.string.pin_code') },
  ] as SegmentButtonV2ItemOptions[])
  private readonly separatorItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: '-' },
    { text: '.' },
    { text: '_' },
    { text: $r('app.string.no_separator') },
  ] as SegmentButtonV2ItemOptions[])
  private readonly caseItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: $r('app.string.lowercase') },
    { text: $r('app.string.capitalize') },
    { text: $r('app.string.uppercase') },
  ] as SegmentButtonV2ItemOptions[])
  private readonly tabsController: TabsController = new TabsController()
  private readonly optionPanelMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial(
    {
      style: uiMaterial.ImmersiveStyle.REGULAR,
      materialColor: $r('sys.color.comp_background_primary'),
      applyShadow: false,
    })
  private readonly passwordCardMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial(
    {
      style: uiMaterial.ImmersiveStyle.REGULAR,
      materialColor: $r('sys.color.comp_background_primary'),
      applyShadow: false,
      interactive: true,
    })
  private readonly tabBarMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial(
    {
      style: uiMaterial.ImmersiveStyle.REGULAR,
      materialColor: $r('sys.color.comp_background_tertiary'),
      applyShadow: false,
    })
  private readonly toastMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial(
    { style: uiMaterial.ImmersiveStyle.ULTRA_THICK })

  aboutToAppear(): void {
    this.controller.bind(this)
    if (this.viewModel.mode !== GeneratorMode.Random) {
      this.viewModel.setMode(GeneratorMode.Random)
    }
  }

  aboutToDisappear(): void {
    this.controller.unbind()
  }

  @Monitor('viewModel.status')
  onStatusChanged(): void {
    if (this.viewModel.status.length > 0) {
      this.showToast(this.viewModel.status)
    }
  }

  @Computed
  get hasValue(): boolean {
    return this.viewModel.value.length > 0
  }

  @Computed
  get passwordSegments(): PasswordTextSegment[] {
    const password: string = this.viewModel.value
    const segments: PasswordTextSegment[] = []
    let start: number = 0
    while (start < password.length) {
      const kind: PasswordCharacterKind = this.passwordCharacterKind(password[start])
      let end: number = start + 1
      while (end < password.length && this.passwordCharacterKind(password[end]) === kind) {
        end++
      }
      segments.push({ text: password.substring(start, end), kind: kind, start: start })
      start = end
    }
    return segments
  }

  copyPassword(): void {
    if (this.viewModel.value.length === 0) {
      return
    }
    appViewModel.copyValue(this.viewModel.value)
    this.showToast($r('app.string.copy_success'))
  }

  getCurrentPassword(): string {
    return this.viewModel.value
  }

  private showToast(message: ResourceStr): void {
    try {
      this.getUIContext().getPromptAction().showToast({
        message,
        systemMaterial: this.toastMaterial,
      })
    } catch (error) {
      const businessError: BusinessError = error as BusinessError
      LogUtil.error(`显示生成器提示失败，错误码=${businessError.code}，错误信息=${businessError.message}`)
    }
  }

  @Computed
  get separatorIndex(): number {
    return GeneratorContent.SEPARATORS.indexOf(this.viewModel.memorableSeparator)
  }

  private get tabTransitionOffset(): number {
    return this.tabsWidth * GeneratorContent.TAB_TRANSITION_OFFSET_RATIO
  }

  private passwordCharacterKind(character: string): PasswordCharacterKind {
    if (character >= '0' && character <= '9') {
      return PasswordCharacterKind.Number
    }
    if (GeneratorContent.SYMBOL_PATTERN.test(character)) {
      return PasswordCharacterKind.Symbol
    }
    return PasswordCharacterKind.Letter
  }

  private passwordCharacterColor(kind: PasswordCharacterKind): ResourceColor {
    if (kind === PasswordCharacterKind.Number) {
      return $r('sys.color.brand')
    }
    if (kind === PasswordCharacterKind.Symbol) {
      return $r('sys.color.alert')
    }
    return $r('sys.color.font_primary')
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
      timeout: AnimationTokens.STATE_TRANSITION_DURATION,
      transition: (proxy: TabContentTransitionProxy) => {
        UIUtils.applySync(() => {
          this.tabOpacity[from] = 1
          this.tabOffsetX[from] = 0
          this.tabOpacity[to] = 0
          this.tabOffsetX[to] = direction * offset
          this.tabZIndex[from] = 0
          this.tabZIndex[to] = 1
        })

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
      },
    }
  }

  @Builder
  private dividerBuilder() {
    Divider()
      .margin({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
  }

  @LocalBuilder
  private randomOptions() {
    Column() {
      SliderFormItem({
        label: $r('app.string.password_length_value'),
        value: this.viewModel.randomLength,
        tips: this.viewModel.randomLength.toString(),
        max: 20,
        min: 8,
        step: 1,
        onChange: (value: number) => this.viewModel.setRandomLength(value),
      })

      this.dividerBuilder()

      ToggleFormItem({
        label: $r('app.string.include_uppercase'),
        value: this.viewModel.randomUppercase,
        onChange: (value: boolean) => this.viewModel.setRandomUppercase(value),
      })

      this.dividerBuilder()

      ToggleFormItem({
        label: $r('app.string.include_lowercase'),
        value: this.viewModel.randomLowercase,
        onChange: (value: boolean) => this.viewModel.setRandomLowercase(value),
      })

      this.dividerBuilder()

      ToggleFormItem({
        label: $r('app.string.include_digits'),
        value: this.viewModel.randomDigits,
        onChange: (value: boolean) => this.viewModel.setRandomDigits(value),
      })

      this.dividerBuilder()

      ToggleFormItem({
        label: $r('app.string.include_symbols'),
        value: this.viewModel.randomSymbols,
        onChange: (value: boolean) => this.viewModel.setRandomSymbols(value),
      })

      this.dividerBuilder()

      ToggleFormItem({
        label: $r('app.string.exclude_similar'),
        value: this.viewModel.randomExcludeSimilar,
        onChange: (value: boolean) => this.viewModel.setRandomExcludeSimilar(value),
      })

      this.dividerBuilder()

      SliderFormItem({
        label: $r('app.string.minimum_digits_value'),
        value: this.viewModel.randomMinimumDigits,
        tips: this.viewModel.randomMinimumDigits.toString(),
        max: 8,
        min: 0,
        step: 1,
        onChange: (value: number) => this.viewModel.setRandomMinimumDigits(value),
      })

      this.dividerBuilder()

      SliderFormItem({
        label: $r('app.string.minimum_symbols_value'),
        value: this.viewModel.randomMinimumSymbols,
        tips: this.viewModel.randomMinimumSymbols.toString(),
        max: 8,
        min: 0,
        step: 1,
        onChange: (value: number) => this.viewModel.setRandomMinimumSymbols(value),
      })
    }
    .borderRadius($r('sys.float.corner_radius_level10'))
    .translate({ x: this.tabOffsetX[0] })
    .systemMaterial(this.optionPanelMaterial)
  }

  @LocalBuilder
  private memorableOptions() {
    Column() {
      SliderFormItem({
        label: $r('app.string.word_count_value'),
        value: this.viewModel.memorableWordCount,
        max: 8,
        min: 3,
        step: 1,
        onChange: (value: number) => this.viewModel.setMemorableWordCount(value),
      })

      this.dividerBuilder()

      SegmentButtonFormItem({
        label: $r('app.string.separator'),
        items: this.separatorItems,
        selectedIndex: this.separatorIndex,
        onChange: (index: number) => this.viewModel.setMemorableSeparator(GeneratorContent.SEPARATORS[index]),
      })

      this.dividerBuilder()

      SegmentButtonFormItem({
        label: $r('app.string.letter_case'),
        items: this.caseItems,
        selectedIndex: this.viewModel.memorableCase,
        onChange: (index: number) => this.viewModel.setMemorableCase(GeneratorContent.CASE_MODES[index]),
      })

      this.dividerBuilder()

      ToggleFormItem({
        label: $r('app.string.append_number'),
        value: this.viewModel.memorableAppendNumber,
        onChange: (value: boolean) => this.viewModel.setMemorableAppendNumber(value),
      })
    }
    .borderRadius($r('sys.float.corner_radius_level10'))
    .translate({ x: this.tabOffsetX[1] })
    .systemMaterial(this.optionPanelMaterial)
  }

  @LocalBuilder
  private pinOptions() {
    Column() {
      SliderFormItem({
        label: $r('app.string.pin_length_value'),
        value: this.viewModel.pinLength,
        max: 12,
        min: 4,
        step: 1,
        onChange: (value: number) => this.viewModel.setPinLength(value),
      })

      this.dividerBuilder()

      ToggleFormItem({
        label: $r('app.string.avoid_pin_patterns'),
        value: this.viewModel.pinAvoidPatterns,
        onChange: (value: boolean) => this.viewModel.setPinAvoidPatterns(value),
      })
    }
    .borderRadius($r('sys.float.corner_radius_level10'))
    .translate({ x: this.tabOffsetX[2] })
    .systemMaterial(this.optionPanelMaterial)
  }

  @LocalBuilder
  private passwordCard() {
    Button() {
      Column({ space: $r('sys.float.padding_level8') }) {
        Text() {
          if (this.hasValue) {
            ForEach(this.passwordSegments, (segment: PasswordTextSegment) => {
              Span(segment.text)
                .fontColor(this.passwordCharacterColor(segment.kind))
            }, (segment: PasswordTextSegment) => `${segment.start}:${segment.kind}`)
          } else {
            Span($r('app.string.no_candidate'))
              .fontColor($r('sys.color.font_secondary'))
          }
        }
          .width('100%')
          .minLines(2)
          .maxLines(2)
          .fontSize($r('app.float.text_heading'))
        .fontFamily(this.hasValue ? PASSWORD_FONT_FAMILY : 'HarmonyOS Sans')
          .textAlign(TextAlign.Center)
        .fontFeature("\"liga\" 0")

        PasswordStrengthIndicator({ password: this.viewModel.value })
      }
      .padding($r('sys.float.padding_level8'))
      .borderRadius($r('sys.float.corner_radius_level10'))
    }
    .enabled(this.hasValue)
    .onClick(() => this.viewModel.regenerate())
    .systemMaterial(this.passwordCardMaterial)
  }

  @LocalBuilder
  private parameterTabs() {
    TabSegmentButtonV2({
      items: this.tabItems,
      selectedIndex: this.viewModel.mode,
      backgroundSystemMaterial: this.tabBarMaterial,
      $selectedIndex: (index: number) => this.tabsController.changeIndex(index),
    })

    Column({ space: $r('sys.float.padding_level4') }) {
      Text($r('app.string.parameter_settings'))
        .margin({ left: $r('sys.float.padding_level8') })
        .fontWeight(FontWeight.Medium)

      Tabs({
        barPosition: BarPosition.Start,
        index: $$this.currentTabIndex,
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
      .onAnimationStart((index: number, targetIndex: number) => {
        if (targetIndex !== index) {
          this.viewModel.setMode(GeneratorContent.TAB_MODES[targetIndex])
        }
      })
      .onChange((index: number) => {
        this.currentTabIndex = index
      })
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.tabsWidth = newValue.width as number
      })
      .clip(false)
    }
    .width('100%')
    .margin({ top: $r('sys.float.padding_level6') })
    .alignItems(HorizontalAlign.Start)
  }

  @LocalBuilder
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
    .clip(false)
  }

  build() {
    Scroll() {
      Column({ space: $r('sys.float.padding_level6') }) {
        this.passwordCard()
        this.parameterTabs()
      }
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring)
    .scrollBar(BarState.Off)
    .padding(
      {
        top: this.topOffset,
        bottom: this.bottomOffset,
        left: $r('sys.float.padding_level8'),
        right: $r('sys.float.padding_level8'),
      })
    .align(Alignment.Top)
    .onTouch(() => this.onActivity())
  }
}
