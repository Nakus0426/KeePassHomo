import { cryptoFramework } from '@kit.CryptoArchitectureKit'

const UPPERCASE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
const LOWERCASE = 'abcdefghijklmnopqrstuvwxyz'
const DIGITS = '0123456789'
const SYMBOLS = '!@#$%^&*+-_=?.'
const SIMILAR_CHARACTERS = 'Iil1Lo0O'
const MEMORABLE_WORDS: string[] = [
  'amber', 'apple', 'april', 'arch', 'atlas', 'autumn', 'badge', 'bamboo',
  'beach', 'berry', 'birch', 'bloom', 'blue', 'boat', 'breeze', 'brook',
  'cabin', 'cactus', 'candle', 'cedar', 'charm', 'cherry', 'cloud', 'clover',
  'coast', 'comet', 'coral', 'crane', 'creek', 'dawn', 'delta', 'dove',
  'dream', 'drift', 'dune', 'eagle', 'earth', 'echo', 'ember', 'fern',
  'field', 'finch', 'flame', 'flora', 'forest', 'fox', 'frost', 'garden',
  'glade', 'globe', 'gold', 'grove', 'harbor', 'hazel', 'hill', 'honey',
  'island', 'jade', 'lake', 'leaf', 'lemon', 'light', 'lilac', 'lotus',
  'lunar', 'maple', 'marble', 'meadow', 'mint', 'moon', 'moss', 'mountain',
  'nova', 'oasis', 'ocean', 'olive', 'opal', 'orchid', 'palm', 'peach',
  'pearl', 'pine', 'plum', 'pond', 'quartz', 'rain', 'reef', 'river',
  'robin', 'rose', 'sage', 'sand', 'shadow', 'shore', 'silver', 'sky',
  'snow', 'solar', 'spark', 'spring', 'star', 'stone', 'storm', 'sun',
  'swift', 'thunder', 'tide', 'trail', 'tree', 'valley', 'violet', 'wave',
  'willow', 'wind', 'winter', 'wood', 'wren', 'acorn', 'alpine', 'aurora',
  'blossom', 'canopy', 'canyon', 'citrus', 'cosmos', 'crystal', 'falcon', 'feather',
]

export enum MemorableCase {
  Lower,
  Capitalized,
  Upper,
}

export interface RandomPasswordOptions {
  length: number
  uppercase: boolean
  lowercase: boolean
  digits: boolean
  symbols: boolean
  excludeSimilar: boolean
  minimumDigits: number
  minimumSymbols: number
}

export interface MemorablePasswordOptions {
  wordCount: number
  separator: string
  letterCase: MemorableCase
  appendNumber: boolean
}

export interface PinOptions {
  length: number
  avoidPatterns: boolean
}

export interface PasswordStrength {
  label: string
  estimatedBits: number
}

export class PasswordGenerator {
  generate(length: number = 20): string {
    return this.generateRandom({
      length: length,
      uppercase: true,
      lowercase: true,
      digits: true,
      symbols: true,
      excludeSimilar: true,
      minimumDigits: 1,
      minimumSymbols: 1,
    })
  }

  generateRandom(options: RandomPasswordOptions): string {
    this.validateRandomOptions(options)
    const groups: string[] = []
    const required: string[] = []
    const uppercase = this.filterSimilar(UPPERCASE, options.excludeSimilar)
    const lowercase = this.filterSimilar(LOWERCASE, options.excludeSimilar)
    const digits = this.filterSimilar(DIGITS, options.excludeSimilar)
    const symbols = SYMBOLS

    if (options.uppercase) {
      groups.push(uppercase)
      required.push(this.randomCharacter(uppercase))
    }
    if (options.lowercase) {
      groups.push(lowercase)
      required.push(this.randomCharacter(lowercase))
    }
    if (options.digits) {
      groups.push(digits)
      for (let index = required.filter((value: string) => digits.includes(value)).length;
        index < options.minimumDigits; index += 1) {
        required.push(this.randomCharacter(digits))
      }
    }
    if (options.symbols) {
      groups.push(symbols)
      for (let index = required.filter((value: string) => symbols.includes(value)).length;
        index < options.minimumSymbols; index += 1) {
        required.push(this.randomCharacter(symbols))
      }
    }
    const alphabet = groups.join('')
    while (required.length < options.length) {
      required.push(this.randomCharacter(alphabet))
    }
    this.shuffle(required)
    return required.join('')
  }

  generateMemorable(options: MemorablePasswordOptions): string {
    this.validateMemorableOptions(options)
    const words: string[] = []
    for (let index = 0; index < options.wordCount; index += 1) {
      words.push(this.formatWord(MEMORABLE_WORDS[this.randomIndex(MEMORABLE_WORDS.length)], options.letterCase))
    }
    let value = words.join(options.separator)
    if (options.appendNumber) {
      value += this.randomIndex(10).toString()
    }
    return value
  }

  generatePin(options: PinOptions): string {
    this.validatePinOptions(options)
    let value = this.randomDigits(options.length)
    while (options.avoidPatterns && this.hasPinPattern(value)) {
      value = this.randomDigits(options.length)
    }
    return value
  }

  estimateRandom(options: RandomPasswordOptions): PasswordStrength {
    this.validateRandomOptions(options)
    let alphabetSize = 0
    alphabetSize += options.uppercase ? this.filterSimilar(UPPERCASE, options.excludeSimilar).length : 0
    alphabetSize += options.lowercase ? this.filterSimilar(LOWERCASE, options.excludeSimilar).length : 0
    alphabetSize += options.digits ? this.filterSimilar(DIGITS, options.excludeSimilar).length : 0
    alphabetSize += options.symbols ? SYMBOLS.length : 0
    return this.strength(options.length * Math.log2(alphabetSize))
  }

  estimateMemorable(options: MemorablePasswordOptions): PasswordStrength {
    this.validateMemorableOptions(options)
    const numberBits = options.appendNumber ? Math.log2(10) : 0
    return this.strength(options.wordCount * Math.log2(MEMORABLE_WORDS.length) + numberBits)
  }

  estimatePin(options: PinOptions): PasswordStrength {
    this.validatePinOptions(options)
    return this.strength(options.length * Math.log2(10))
  }

  private validateRandomOptions(options: RandomPasswordOptions): void {
    if (!Number.isInteger(options.length) || options.length < 8 || options.length > 128) {
      throw new Error('随机密码长度必须为 8 到 128 位整数')
    }
    if (!Number.isInteger(options.minimumDigits) || options.minimumDigits < 0 ||
      !Number.isInteger(options.minimumSymbols) || options.minimumSymbols < 0) {
      throw new Error('最少数字和符号数量必须为非负整数')
    }
    if (!options.uppercase && !options.lowercase && !options.digits && !options.symbols) {
      throw new Error('请至少启用一种字符类型')
    }
    if (options.minimumDigits > 0 && !options.digits) {
      throw new Error('最少数字数量大于 0 时必须启用数字')
    }
    if (options.minimumSymbols > 0 && !options.symbols) {
      throw new Error('最少符号数量大于 0 时必须启用符号')
    }
    let required = options.uppercase ? 1 : 0
    required += options.lowercase ? 1 : 0
    required += options.digits ? Math.max(1, options.minimumDigits) : 0
    required += options.symbols ? Math.max(1, options.minimumSymbols) : 0
    if (required > options.length) {
      throw new Error('密码长度不足以满足当前规则')
    }
  }

  private validateMemorableOptions(options: MemorablePasswordOptions): void {
    if (!Number.isInteger(options.wordCount) || options.wordCount < 3 || options.wordCount > 8) {
      throw new Error('易记密码的单词数量必须为 3 到 8 个')
    }
  }

  private validatePinOptions(options: PinOptions): void {
    if (!Number.isInteger(options.length) || options.length < 4 || options.length > 12) {
      throw new Error('PIN 长度必须为 4 到 12 位整数')
    }
  }

  private strength(bits: number): PasswordStrength {
    const estimatedBits = Math.floor(bits)
    if (estimatedBits < 36) {
      return { label: '较弱', estimatedBits: estimatedBits }
    }
    if (estimatedBits < 60) {
      return { label: '一般', estimatedBits: estimatedBits }
    }
    if (estimatedBits < 80) {
      return { label: '较强', estimatedBits: estimatedBits }
    }
    return { label: '很强', estimatedBits: estimatedBits }
  }

  private randomDigits(length: number): string {
    const characters: string[] = []
    for (let index = 0; index < length; index += 1) {
      characters.push(this.randomCharacter(DIGITS))
    }
    return characters.join('')
  }

  private hasPinPattern(value: string): boolean {
    for (let index = 1; index < value.length; index += 1) {
      if (value[index] === value[index - 1]) {
        return true
      }
    }
    for (let index = 2; index < value.length; index += 1) {
      const first = Number(value[index - 2])
      const second = Number(value[index - 1])
      const third = Number(value[index])
      if ((second - first === 1 && third - second === 1) ||
        (second - first === -1 && third - second === -1)) {
        return true
      }
    }
    return false
  }

  private formatWord(word: string, letterCase: MemorableCase): string {
    if (letterCase === MemorableCase.Upper) {
      return word.toUpperCase()
    }
    if (letterCase === MemorableCase.Capitalized) {
      return word[0].toUpperCase() + word.slice(1)
    }
    return word
  }

  private filterSimilar(alphabet: string, excludeSimilar: boolean): string {
    if (!excludeSimilar) {
      return alphabet
    }
    return alphabet.split('').filter((value: string) => !SIMILAR_CHARACTERS.includes(value)).join('')
  }

  private randomCharacter(alphabet: string): string {
    return alphabet[this.randomIndex(alphabet.length)]
  }

  private shuffle(values: string[]): void {
    for (let index = values.length - 1; index > 0; index -= 1) {
      const target = this.randomIndex(index + 1)
      const value = values[index]
      values[index] = values[target]
      values[target] = value
    }
  }

  private randomIndex(limit: number): number {
    try {
      const maximum = Math.floor(256 / limit) * limit
      let value = cryptoFramework.createRandom().generateRandomSync(1).data[0]
      while (value >= maximum) {
        value = cryptoFramework.createRandom().generateRandomSync(1).data[0]
      }
      return value % limit
    } catch (error) {
      throw new Error(`安全随机数生成失败：${(error as Error).message}`)
    }
  }
}
