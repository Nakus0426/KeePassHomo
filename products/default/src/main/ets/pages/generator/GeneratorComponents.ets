import {
  CapsuleSegmentButtonV2,
  promptAction,
  SegmentButtonV2ItemOptions,
  SegmentButtonV2Items,
  TabSegmentButtonV2,
  uiMaterial,
} from '@kit.ArkUI'
import { AnimationTokens, ColorUtil, MemorableCase } from '@ohos/common'
import { ResUtil } from '@pura/harmony-utils'
import { FormItem, LabelPlacement } from '../../components/FormItem'
import { PasswordStrengthIndicator } from '../../components/PasswordStrengthIndicator'
import { ColorModeState, colorModeState } from '../../state/ColorModeState'
import { appViewModel } from '../../viewmodel/AppViewModel'
import { GeneratorMode, GeneratorViewModel } from '../../viewmodel/GeneratorViewModel'

export enum PrimaryActionType {
  Fill,
  Copy
}

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
      .width(220)
      .showTips(true, this.tips)
      .showSteps(true)
      .onChange((value: number) => this.onChange(value))
  }

  build() {
    Row() {
      FormItem({ label: this.label, labelPlacement: LabelPlacement.Start, contentBuilder: this.contentBuilder })
    }
    .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level5') })
    .height(56)
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
    .height(56)
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

  @LocalBuilder
  contentBuilder() {
    CapsuleSegmentButtonV2({
      items: this.items,
      selectedIndex: this.selectedIndex,
      backgroundSystemMaterial: new uiMaterial.ImmersiveMaterial(
        {
          style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
          applyShadow: false,
          materialColor: $r('sys.color.progress_track_color'),
        }),
      $selectedIndex: (index: number) => this.onChange(index),
    })
      .width(220)
  }

  build() {
    Row() {
      FormItem({ label: this.label, labelPlacement: LabelPlacement.Start, contentBuilder: this.contentBuilder })
    }
    .height(56)
    .padding({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
  }
}

@ComponentV2
export struct GeneratorContent {
  private static readonly TAB_MODES: GeneratorMode[] =
    [GeneratorMode.Random, GeneratorMode.Memorable, GeneratorMode.Pin]
  private static readonly CASE_MODES: MemorableCase[] =
    [MemorableCase.Lower, MemorableCase.Capitalized, MemorableCase.Upper]
  private static readonly SEPARATORS: string[] = ['-', '.', '_', '']
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
  @Local private colorMode: ColorModeState = colorModeState
  @Param viewModel: GeneratorViewModel = new GeneratorViewModel()
  @Param clipboardSeconds: number = 0
  @Param primaryAction: PrimaryActionType = PrimaryActionType.Copy
  @Param bottomOffset: number = 0
  @Event onFillEditor: () => void = () => {
  }
  @Event onCopy: (value: string) => void = () => {
  }
  @Event onActivity: () => void = () => {
  }
  private readonly toastMaterial: uiMaterial.Material = new uiMaterial.ImmersiveMaterial(
    { style: uiMaterial.ImmersiveStyle.ULTRA_THICK })
  @Local private countdownVisible: boolean = false

  aboutToAppear(): void {
    this.countdownVisible = this.clipboardSeconds > 0
  }

  @Monitor('viewModel.status')
  onStatusChanged(): void {
    if (this.viewModel.status.length > 0) {
      promptAction.showToast({
        message: this.viewModel.status,
        systemMaterial: this.toastMaterial,
      })
    }
  }

  @Monitor('clipboardSeconds')
  onClipboardSecondsChanged(): void {
    const visible: boolean = this.clipboardSeconds > 0
    if (visible && !this.countdownVisible) {
      promptAction.showToast({
        message: $r('app.string.copy_success'),
        systemMaterial: this.toastMaterial,
      })
    }
    if (visible === this.countdownVisible) {
      return
    }
    this.getUIContext().animateTo({
      duration: AnimationTokens.STATE_TRANSITION_DURATION,
      curve: AnimationTokens.STATE_TRANSITION_CURVE,
    }, () => {
      this.countdownVisible = visible
    })
  }

  @Computed
  get topAvoidHeight() {
    const titlebarHeightPx = ResUtil.getNumber($r('sys.float.titlebar_default_height').id)
    const paddingHeightPx = ResUtil.getNumber($r('sys.float.padding_level12').id)
    return this.getUIContext().px2vp(titlebarHeightPx + paddingHeightPx)
  }

  @Computed
  get bottomAvoidHeight() {
    const buttonHeightPx = ResUtil.getNumber($r('app.float.control_height').id)
    const paddingHeightPx = ResUtil.getNumber($r('sys.float.padding_level8').id)
    return this.getUIContext().px2vp(buttonHeightPx + paddingHeightPx) + this.bottomOffset
  }

  @Computed
  get bottomGradientColors(): Array<[ResourceColor, number]> {
    this.colorMode.isDark
    const backgroundColor: ResourceColor = $r('sys.color.background_secondary')
    return [
      [ColorUtil.withAlphaHex(backgroundColor, 0), 0.0],
      [ColorUtil.withAlphaHex(backgroundColor, 1), 1.0],
    ]
  }

  @Computed
  get separatorIndex(): number {
    return GeneratorContent.SEPARATORS.indexOf(this.viewModel.memorableSeparator)
  }

  @Builder
  private dividerBuilder() {
    Divider()
      .margin({ left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8') })
  }

  @Builder
  private tabContentBuilder() {
    Column() {
      if (this.viewModel.mode === GeneratorMode.Random) {
        this.randomOptions()
      } else if (this.viewModel.mode === GeneratorMode.Memorable) {
        this.memorableOptions()
      } else {
        this.pinOptions()
      }
    }
  }

  @Builder
  private randomOptions() {
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

  @Builder
  private memorableOptions() {
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

  @Builder
  private pinOptions() {
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

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Scroll() {
        Column({ space: $r('sys.float.padding_level6') }) {
          Button() {
            Column({ space: $r('sys.float.padding_level8') }) {
              Text(this.viewModel.value.length > 0
                ? this.viewModel.value : $r('app.string.no_candidate'))
                .width('100%')
                .minLines(2)
                .maxLines(2)
                .fontSize($r('app.float.text_heading'))
                .fontWeight(FontWeight.Medium)
                .fontColor(this.viewModel.value.length > 0
                  ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
                .textAlign(TextAlign.Center)

              PasswordStrengthIndicator({ password: this.viewModel.value })

              if (this.countdownVisible) {
                Row({ space: $r('sys.float.padding_level4') }) {
                  SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                    .fontSize($r('sys.float.Body_L'))
                    .fontColor([$r('sys.color.confirm')])
                  Text($r('app.string.copied_countdown', this.clipboardSeconds))
                    .fontSize($r('sys.float.Body_M'))
                    .fontColor($r('sys.color.confirm'))
                }
                .padding({
                  top: $r('sys.float.padding_level4'),
                  bottom: $r('sys.float.padding_level4'),
                  left: $r('sys.float.padding_level8'),
                  right: $r('sys.float.padding_level8'),
                })
                .backgroundColor(ColorUtil.withAlpha($r('sys.color.confirm'), 0.2))
                .borderRadius($r('sys.float.corner_radius_level10'))
                .transition(TransitionEffect.OPACITY.animation({
                  duration: AnimationTokens.STATE_TRANSITION_DURATION,
                  curve: AnimationTokens.STATE_TRANSITION_CURVE,
                }))
              }
            }
            .padding($r('sys.float.padding_level8'))
            .borderRadius($r('sys.float.corner_radius_level10'))
          }
          .enabled(this.viewModel.value.length > 0)
          .onClick(() => appViewModel.copyValue(this.viewModel.value))
          .systemMaterial(new uiMaterial.ImmersiveMaterial(
            {
              style: uiMaterial.ImmersiveStyle.REGULAR,
              materialColor: $r('sys.color.comp_background_primary'),
              applyShadow: false,
              interactive: true,
            }))

          TabSegmentButtonV2({
            items: this.tabItems,
            selectedIndex: this.viewModel.mode,
            backgroundSystemMaterial: new uiMaterial.ImmersiveMaterial(
              {
                style: uiMaterial.ImmersiveStyle.REGULAR,
                materialColor: $r('sys.color.comp_background_tertiary'),
                applyShadow: false,
              }),
            $selectedIndex: (index: number) => this.viewModel.setMode(GeneratorContent.TAB_MODES[index]),
          })

          Column({ space: $r('sys.float.padding_level4') }) {
            Text($r('app.string.parameter_settings'))
              .margin({ left: $r('sys.float.padding_level8') })
              .fontWeight(FontWeight.Medium)

            Tabs({
              barPosition: BarPosition.Start,
              index: this.viewModel.mode,
            }) {
              TabContent() {
                this.tabContentBuilder()
              }
              .clip(false)

              TabContent() {
                this.tabContentBuilder()
              }
              .clip(false)

              TabContent() {
                this.tabContentBuilder()
              }
              .clip(false)
            }
            .height('auto')
            .width('100%')
            .scrollable(false)
            .barHeight(0)
            .divider(null)
            .borderRadius($r('sys.float.corner_radius_level10'))
            .clip(false)
            .systemMaterial(new uiMaterial.ImmersiveMaterial(
              {
                style: uiMaterial.ImmersiveStyle.REGULAR,
                materialColor: $r('sys.color.comp_background_primary'),
                applyShadow: false,
              }))
          }
          .width('100%')
          .margin({ top: $r('sys.float.padding_level6') })
          .alignItems(HorizontalAlign.Start)

        }
      }
      .width('100%')
      .height('100%')
      .edgeEffect(EdgeEffect.Spring)
      .scrollBar(BarState.Off)
      .padding(
        {
          top: this.topAvoidHeight,
          left: $r('sys.float.padding_level8'),
          right: $r('sys.float.padding_level8'),
          bottom: this.bottomAvoidHeight,
        })
      .align(Alignment.Top)

      Row({ space: $r('sys.float.padding_level6') }) {
        Button($r('app.string.regenerate'))
          .layoutWeight(1)
          .height($r('app.float.control_height'))
          .fontColor($r('sys.color.brand'))
          .systemMaterial(new uiMaterial.ImmersiveMaterial(
            {
              style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
              lightEffect: { color: Color.White },
              interactive: true,
            }))
          .onClick(() => this.viewModel.regenerate())
        Button(
          this.primaryAction === PrimaryActionType.Fill ? $r('app.string.fill_current_entry') : $r('app.string.copy'))
          .layoutWeight(1)
          .height($r('app.float.control_height'))
          .enabled(this.viewModel.value.length > 0)
          .systemMaterial(new uiMaterial.ImmersiveMaterial(
            {
              style: uiMaterial.ImmersiveStyle.ULTRA_THICK,
              materialColor: $r('sys.color.brand'),
              lightEffect: { color: $r('sys.color.brand') },
              interactive: true,
            }))
          .onClick(() => {
            if (this.primaryAction === PrimaryActionType.Fill) {
              this.onFillEditor()
            } else {
              this.onCopy(this.viewModel.value)
            }
          })
      }
      .width('100%')
      .padding(
        { left: $r('sys.float.padding_level8'), right: $r('sys.float.padding_level8'), bottom: this.bottomOffset })
      .linearGradient(
        {
          direction: GradientDirection.Bottom,
          colors: this.bottomGradientColors,
        })
    }
    .width('100%')
    .height('100%')
    .onTouch(() => this.onActivity())
  }
}
