import {
  AppErrorFactory,
  AppErrorModel,
  MemorableCase,
  MemorablePasswordOptions,
  PasswordGenerator,
  PasswordStrength,
  PinOptions,
  RandomPasswordOptions,
} from '@ohos/common'
import { LogUtil } from '@pura/harmony-utils'

export enum GeneratorMode {
  Random,
  Memorable,
  Pin,
}

@ObservedV2
export class GeneratorViewModel {
  @Trace mode: GeneratorMode = GeneratorMode.Random
  @Trace value: string = ''
  @Trace status: string = ''
  @Trace randomLength: number = 20
  @Trace randomUppercase: boolean = true
  @Trace randomLowercase: boolean = true
  @Trace randomDigits: boolean = true
  @Trace randomSymbols: boolean = true
  @Trace randomExcludeSimilar: boolean = true
  @Trace randomMinimumDigits: number = 1
  @Trace randomMinimumSymbols: number = 1
  @Trace memorableWordCount: number = 4
  @Trace memorableSeparator: string = '-'
  @Trace memorableCase: MemorableCase = MemorableCase.Lower
  @Trace memorableAppendNumber: boolean = true
  @Trace pinLength: number = 6
  @Trace pinAvoidPatterns: boolean = true
  private readonly generator: PasswordGenerator = new PasswordGenerator()


  setMode(mode: GeneratorMode): void {
    this.mode = mode
    this.regenerate()
  }

  setRandomLength(value: number): void {
    this.randomLength = value
    this.regenerate()
  }

  setRandomUppercase(value: boolean): void {
    this.randomUppercase = value
    this.regenerate()
  }

  setRandomLowercase(value: boolean): void {
    this.randomLowercase = value
    this.regenerate()
  }

  setRandomDigits(value: boolean): void {
    this.randomDigits = value
    this.regenerate()
  }

  setRandomSymbols(value: boolean): void {
    this.randomSymbols = value
    this.regenerate()
  }

  setRandomExcludeSimilar(value: boolean): void {
    this.randomExcludeSimilar = value
    this.regenerate()
  }

  setRandomMinimumDigits(value: number): void {
    this.randomMinimumDigits = value
    this.regenerate()
  }

  setRandomMinimumSymbols(value: number): void {
    this.randomMinimumSymbols = value
    this.regenerate()
  }

  setMemorableWordCount(value: number): void {
    this.memorableWordCount = value
    this.regenerate()
  }

  setMemorableSeparator(value: string): void {
    this.memorableSeparator = value
    this.regenerate()
  }

  setMemorableCase(value: MemorableCase): void {
    this.memorableCase = value
    this.regenerate()
  }

  setMemorableAppendNumber(value: boolean): void {
    this.memorableAppendNumber = value
    this.regenerate()
  }

  setPinLength(value: number): void {
    this.pinLength = value
    this.regenerate()
  }

  setPinAvoidPatterns(value: boolean): void {
    this.pinAvoidPatterns = value
    this.regenerate()
  }

  regenerate(): void {
    const ruleError: string = this.mode === GeneratorMode.Random ? this.randomRuleError() : ''
    if (ruleError.length > 0) {
      this.value = ''
      this.status = ruleError
      return
    }
    try {
      if (this.mode === GeneratorMode.Random) {
        this.value = this.generator.generateRandom(this.randomOptions())
      } else if (this.mode === GeneratorMode.Memorable) {
        this.value = this.generator.generateMemorable(this.memorableOptions())
      } else {
        this.value = this.generator.generatePin(this.pinOptions())
      }
      this.status = ''
    } catch (error) {
      this.value = ''
      const appError: AppErrorModel = AppErrorFactory.from(error, '生成密码失败，请重试')
      this.status = appError.message
      LogUtil.error(`生成密码失败，错误分类=${appError.category}，错误码=${appError.logCode}`)
    }
  }

  strength(): PasswordStrength {
    if (this.mode === GeneratorMode.Random) {
      if (this.randomRuleError().length > 0) {
        return { label: '规则无效', estimatedBits: 0 }
      }
      return this.generator.estimateRandom(this.randomOptions())
    }
    if (this.mode === GeneratorMode.Memorable) {
      return this.generator.estimateMemorable(this.memorableOptions())
    }
    return this.generator.estimatePin(this.pinOptions())
  }

  generateMasterPassword(): string {
    return this.generator.generate()
  }

  clearSensitiveState(): void {
    this.value = ''
    this.status = ''
  }

  private randomOptions(): RandomPasswordOptions {
    return {
      length: this.randomLength,
      uppercase: this.randomUppercase,
      lowercase: this.randomLowercase,
      digits: this.randomDigits,
      symbols: this.randomSymbols,
      excludeSimilar: this.randomExcludeSimilar,
      minimumDigits: this.randomMinimumDigits,
      minimumSymbols: this.randomMinimumSymbols,
    }
  }

  private memorableOptions(): MemorablePasswordOptions {
    return {
      wordCount: this.memorableWordCount,
      separator: this.memorableSeparator,
      letterCase: this.memorableCase,
      appendNumber: this.memorableAppendNumber,
    }
  }

  private pinOptions(): PinOptions {
    return {
      length: this.pinLength,
      avoidPatterns: this.pinAvoidPatterns,
    }
  }

  private randomRuleError(): string {
    if (!this.randomUppercase && !this.randomLowercase && !this.randomDigits && !this.randomSymbols) {
      return '请至少启用一种字符类型'
    }
    if (!this.randomDigits && this.randomMinimumDigits > 0) {
      return '最少数字数量大于 0 时必须启用数字'
    }
    if (!this.randomSymbols && this.randomMinimumSymbols > 0) {
      return '最少符号数量大于 0 时必须启用符号'
    }
    let required: number = this.randomUppercase ? 1 : 0
    required += this.randomLowercase ? 1 : 0
    required += this.randomDigits ? Math.max(1, this.randomMinimumDigits) : 0
    required += this.randomSymbols ? Math.max(1, this.randomMinimumSymbols) : 0
    return required > this.randomLength ? '密码长度不足以满足当前规则' : ''
  }
}
