import { uiMaterial } from '@kit.ArkUI'
import { HdsNavDestination } from '@kit.UIDesignKit'
import { MemorableCase } from '@ohos/common'
import { GeneratorMode, GeneratorViewModel } from '../../viewmodel/GeneratorViewModel'
import { PageTopBar } from '../../components/PageChrome'

@ComponentV2
struct GeneratorToggleRow {
  @Param title: Resource = $r('app.string.include_uppercase')
  @Param value: boolean = false
  @Event onChange: (value: boolean) => void = () => {
  }

  build() {
    Row() {
      Text(this.title)
        .layoutWeight(1)
        .fontColor($r('sys.color.font_primary'))
      Toggle({ type: ToggleType.Switch, isOn: this.value })
        .selectedColor($r('sys.color.brand'))
        .onChange((value: boolean) => this.onChange(value))
    }
    .width('100%')
    .height($r('app.float.control_height'))
  }
}

@ComponentV2
export struct GeneratorContent {
  @Param viewModel: GeneratorViewModel = new GeneratorViewModel()
  @Param clipboardSeconds: number = 0
  @Param showFillAction: boolean = false
  @Event onCopy: (value: string) => void = () => {
  }
  @Event onFillEditor: () => void = () => {
  }
  @Event onActivity: () => void = () => {
  }
  private readonly material: uiMaterial.Material = new uiMaterial.ImmersiveMaterial({
    style: uiMaterial.ImmersiveStyle.ULTRA_THIN,
    applyShadow: true,
  })

  @Builder
  private modeButton(title: Resource, mode: GeneratorMode) {
    Button(title)
      .layoutWeight(1)
      .backgroundColor(this.viewModel.mode === mode
        ? $r('sys.color.brand') : $r('sys.color.comp_background_primary'))
      .fontColor(this.viewModel.mode === mode
        ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
      .onClick(() => this.viewModel.setMode(mode))
  }

  @Builder
  private randomOptions() {
    Column({ space: 8 }) {
      Text($r('app.string.password_length_value', this.viewModel.randomLength))
        .width('100%')
        .fontColor($r('sys.color.font_primary'))
      Slider({
        value: this.viewModel.randomLength,
        min: 8,
        max: 64,
        step: 1,
      })
        .width('100%')
        .selectedColor($r('sys.color.brand'))
        .showTips(true)
        .onChange((value: number) => this.viewModel.setRandomLength(value))
      GeneratorToggleRow({
        title: $r('app.string.include_uppercase'),
        value: this.viewModel.randomUppercase,
        onChange: (value: boolean) => this.viewModel.setRandomUppercase(value),
      })
      GeneratorToggleRow({
        title: $r('app.string.include_lowercase'),
        value: this.viewModel.randomLowercase,
        onChange: (value: boolean) => this.viewModel.setRandomLowercase(value),
      })
      GeneratorToggleRow({
        title: $r('app.string.include_digits'),
        value: this.viewModel.randomDigits,
        onChange: (value: boolean) => this.viewModel.setRandomDigits(value),
      })
      GeneratorToggleRow({
        title: $r('app.string.include_symbols'),
        value: this.viewModel.randomSymbols,
        onChange: (value: boolean) => this.viewModel.setRandomSymbols(value),
      })
      GeneratorToggleRow({
        title: $r('app.string.exclude_similar'),
        value: this.viewModel.randomExcludeSimilar,
        onChange: (value: boolean) => this.viewModel.setRandomExcludeSimilar(value),
      })
      Text($r('app.string.minimum_digits_value', this.viewModel.randomMinimumDigits))
        .width('100%')
      Slider({
        value: this.viewModel.randomMinimumDigits,
        min: 0,
        max: 8,
        step: 1,
      })
        .width('100%')
        .selectedColor($r('sys.color.brand'))
        .showTips(true)
        .onChange((value: number) => this.viewModel.setRandomMinimumDigits(value))
      Text($r('app.string.minimum_symbols_value', this.viewModel.randomMinimumSymbols))
        .width('100%')
      Slider({
        value: this.viewModel.randomMinimumSymbols,
        min: 0,
        max: 8,
        step: 1,
      })
        .width('100%')
        .selectedColor($r('sys.color.brand'))
        .showTips(true)
        .onChange((value: number) => this.viewModel.setRandomMinimumSymbols(value))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private separatorButton(title: ResourceStr, separator: string) {
    Button(title)
      .layoutWeight(1)
      .backgroundColor(this.viewModel.memorableSeparator === separator
        ? $r('sys.color.brand') : $r('sys.color.comp_background_primary'))
      .fontColor(this.viewModel.memorableSeparator === separator
        ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
      .onClick(() => this.viewModel.setMemorableSeparator(separator))
  }

  @Builder
  private caseButton(title: Resource, letterCase: MemorableCase) {
    Button(title)
      .layoutWeight(1)
      .backgroundColor(this.viewModel.memorableCase === letterCase
        ? $r('sys.color.brand') : $r('sys.color.comp_background_primary'))
      .fontColor(this.viewModel.memorableCase === letterCase
        ? $r('sys.color.font_on_primary') : $r('sys.color.font_primary'))
      .onClick(() => this.viewModel.setMemorableCase(letterCase))
  }

  @Builder
  private memorableOptions() {
    Column({ space: 12 }) {
      Text($r('app.string.word_count_value', this.viewModel.memorableWordCount))
        .width('100%')
      Slider({
        value: this.viewModel.memorableWordCount,
        min: 3,
        max: 8,
        step: 1,
      })
        .width('100%')
        .selectedColor($r('sys.color.brand'))
        .showTips(true)
        .onChange((value: number) => this.viewModel.setMemorableWordCount(value))
      Text($r('app.string.separator'))
        .width('100%')
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: 8 }) {
        this.separatorButton('-', '-')
        this.separatorButton('.', '.')
        this.separatorButton('_', '_')
        this.separatorButton($r('app.string.no_separator'), '')
      }
      .width('100%')

      Text($r('app.string.letter_case'))
        .width('100%')
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: 8 }) {
        this.caseButton($r('app.string.lowercase'), MemorableCase.Lower)
        this.caseButton($r('app.string.capitalize'), MemorableCase.Capitalized)
        this.caseButton($r('app.string.uppercase'), MemorableCase.Upper)
      }
      .width('100%')

      GeneratorToggleRow({
        title: $r('app.string.append_number'),
        value: this.viewModel.memorableAppendNumber,
        onChange: (value: boolean) => this.viewModel.setMemorableAppendNumber(value),
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private pinOptions() {
    Column({ space: 12 }) {
      Text($r('app.string.pin_length_value', this.viewModel.pinLength))
        .width('100%')
      Slider({
        value: this.viewModel.pinLength,
        min: 4,
        max: 12,
        step: 1,
      })
        .width('100%')
        .selectedColor($r('sys.color.brand'))
        .showTips(true)
        .onChange((value: number) => this.viewModel.setPinLength(value))
      GeneratorToggleRow({
        title: $r('app.string.avoid_pin_patterns'),
        value: this.viewModel.pinAvoidPatterns,
        onChange: (value: boolean) => this.viewModel.setPinAvoidPatterns(value),
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        this.modeButton($r('app.string.random_password'), GeneratorMode.Random)
        this.modeButton($r('app.string.memorable_password'), GeneratorMode.Memorable)
        this.modeButton($r('app.string.pin_code'), GeneratorMode.Pin)
      }
      .width('100%')
      .padding(4)
      .borderRadius($r('sys.float.corner_radius_level12'))
      .systemMaterial(this.material)

      Column({ space: 8 }) {
        Text(this.viewModel.value.length > 0
          ? this.viewModel.value : $r('app.string.no_candidate'))
          .width('100%')
          .fontSize($r('app.float.text_heading'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.viewModel.value.length > 0
            ? $r('sys.color.font_primary') : $r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
        Text($r('app.string.generator_strength', this.viewModel.strength().label,
          this.viewModel.strength().estimatedBits))
          .width('100%')
          .fontSize($r('app.float.text_caption'))
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
        if (this.clipboardSeconds > 0) {
          Text($r('app.string.copied_countdown', this.clipboardSeconds))
            .width('100%')
            .fontColor($r('sys.color.confirm'))
            .textAlign(TextAlign.Center)
        }
      }
      .width('100%')
      .padding($r('sys.float.padding_level8'))
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius($r('sys.float.corner_radius_level4'))

      Scroll() {
        Column({ space: 12 }) {
          if (this.viewModel.mode === GeneratorMode.Random) {
            this.randomOptions()
          } else if (this.viewModel.mode === GeneratorMode.Memorable) {
            this.memorableOptions()
          } else {
            this.pinOptions()
          }
          if (this.viewModel.status.length > 0) {
            Text(this.viewModel.status)
              .width('100%')
              .fontColor($r('sys.color.warning'))
          }
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)

      Row({ space: 8 }) {
        Button($r('app.string.regenerate'))
          .layoutWeight(1)
          .height($r('app.float.control_height'))
          .backgroundColor($r('sys.color.comp_emphasize_secondary'))
          .fontColor($r('sys.color.brand'))
          .onClick(() => this.viewModel.regenerate())
        Button($r('app.string.copy'))
          .layoutWeight(1)
          .height($r('app.float.control_height'))
          .enabled(this.viewModel.value.length > 0)
          .backgroundColor($r('sys.color.brand'))
          .onClick(() => this.onCopy(this.viewModel.value))
      }
      .width('100%')
      .padding(8)
      .borderRadius($r('sys.float.corner_radius_level8'))
      .systemMaterial(this.material)

      if (this.showFillAction) {
        Button($r('app.string.fill_current_entry'))
          .width('100%')
          .height($r('app.float.control_height'))
          .enabled(this.viewModel.value.length > 0)
          .backgroundColor($r('sys.color.brand'))
          .onClick(() => this.onFillEditor())
      }
    }
    .width('100%')
    .height('100%')
    .onTouch(() => this.onActivity())
  }
}

@ComponentV2
export struct GeneratorPage {
  @Param viewModel: GeneratorViewModel = new GeneratorViewModel()
  @Param clipboardSeconds: number = 0
  @Event onLock: () => void = () => {
  }
  @Event onCopy: (value: string) => void = () => {
  }
  @Event onActivity: () => void = () => {
  }
  @Event onShown: () => void = () => {
  }
  @Event onRootBack: () => void = () => {
  }

  build() {
    HdsNavDestination() {
      Column({ space: 12 }) {
        PageTopBar({
          title: $r('app.string.password_generator'),
          showLock: true,
          onLock: () => this.onLock(),
        })
        GeneratorContent({
          viewModel: this.viewModel,
          clipboardSeconds: this.clipboardSeconds,
          onCopy: (value: string) => this.onCopy(value),
          onActivity: () => this.onActivity(),
        })
          .layoutWeight(1)
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
    }
    .hideTitleBar(true)
    .backgroundColor($r('sys.color.background_secondary'))
    .onShown(() => this.onShown())
    .onHidden(() => this.viewModel.clearSensitiveState())
    .onBackPressed(() => {
      this.onRootBack()
      return true
    })
  }
}
